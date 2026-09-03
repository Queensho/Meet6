import 'dart:async';
import 'dart:math';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';
import 'session_service.dart';

class RealtimeEvent {
  const RealtimeEvent(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;
}

class RealtimeService {
  const RealtimeService._();

  static io.Socket? _socket;
  static String? _token;
  static Completer<void>? _connecting;
  static final _events = StreamController<RealtimeEvent>.broadcast();
  static final Random _random = Random.secure();

  static Stream<RealtimeEvent> get events => _events.stream;
  static bool get connected => _socket?.connected == true;

  static Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String _newClientMessageId() {
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final randomA = _random.nextInt(1 << 31).toRadixString(36);
    final randomB = _random.nextInt(1 << 31).toRadixString(36);
    return '$micros-$randomA-$randomB';
  }

  static void _push(String type, dynamic raw) {
    final data = _map(raw);
    _events.add(RealtimeEvent(type, data));

    // HTTP kullanan test/yardımcı istemci altıncı kişiyi ekleyip odayı
    // oluşturursa backend room:update yayınlar. Arama ekranı bunu da gerçek
    // queue:matched olayı gibi ele alır; böylece polling'e geri dönmeyiz.
    if (type == 'room:update') {
      final rawRoom = data['room'];
      if (rawRoom is Map) {
        final room = Map<String, dynamic>.from(rawRoom);
        final members = room['members'];
        if (room['status'] == 'active' && members is List && members.length == 6) {
          _events.add(RealtimeEvent('queue:matched', {'state': 'room', 'room': room}));
        }
      }
    }

    // user:message yalnızca mesajın alıcısının kullanıcı kanalına yayınlanır.
    // Uygulama olayı aldığı anda teslim ACK'i göndererek "Teslim edildi"
    // durumunu sohbet ekranı açık olmasa da gerçek cihaz teslimine bağlarız.
    if (type == 'user:message') {
      final matchId = data['matchId']?.toString() ?? '';
      final rawMessage = data['message'];
      if (matchId.isNotEmpty && rawMessage is Map) {
        final message = Map<String, dynamic>.from(rawMessage);
        final messageId = message['id']?.toString() ?? '';
        if (messageId.isNotEmpty) {
          unawaited(
            markMatchDelivered(matchId, messageId)
                .catchError((_) => <String, dynamic>{}),
          );
        }
      }
    }
  }

  static void _register(io.Socket socket) {
    const forwarded = [
      'server:ready',
      'auth:error',
      'queue:status',
      'queue:matched',
      'room:update',
      'room:message',
      'room:sync-messages',
      'room:selection-status',
      'room:closed-by-admin',
      'room:removed',
      'matches:update',
      'match:created',
      'match:message',
      'user:message',
      'match:delivered',
      'match:read',
      'match:typing',
      'match:message-deleted',
      'presence:update',
    ];

    for (final name in forwarded) {
      socket.on(name, (data) => _push(name, data));
    }

    socket.onConnect((_) {
      _events.add(const RealtimeEvent('connection:connected', {}));
      if (!(_connecting?.isCompleted ?? true)) _connecting?.complete();
    });
    socket.onDisconnect((reason) {
      _events.add(RealtimeEvent('connection:disconnected', {'reason': '$reason'}));
    });
    socket.onConnectError((error) {
      _events.add(RealtimeEvent('connection:error', {'message': '$error'}));
      if (!(_connecting?.isCompleted ?? true)) {
        _connecting?.completeError(const ApiException('Gerçek zamanlı bağlantı kurulamadı.'));
      }
    });
    socket.onError((error) {
      _events.add(RealtimeEvent('connection:error', {'message': '$error'}));
    });
  }

  static Future<void> connect() async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) {
      throw const ApiException('Oturum bulunamadı.');
    }

    if (_socket != null && _token == token) {
      if (_socket!.connected) return;
      if (_connecting != null && !(_connecting!.isCompleted)) {
        return _connecting!.future.timeout(const Duration(seconds: 12));
      }
      _connecting = Completer<void>();
      _socket!.connect();
      return _connecting!.future.timeout(const Duration(seconds: 12));
    }

    _socket?.dispose();
    _token = token;
    _connecting = Completer<void>();
    final socket = io.io(
      '${ApiService.baseUrl}/rooms',
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 1000000,
        'reconnectionDelay': 500,
        'reconnectionDelayMax': 4000,
        'randomizationFactor': 0.35,
        'timeout': 10000,
        'auth': {'token': token},
      },
    );
    _socket = socket;
    _register(socket);
    socket.connect();
    return _connecting!.future.timeout(const Duration(seconds: 12));
  }

  static Future<Map<String, dynamic>> _ack(
    String event, [
    Map<String, dynamic> data = const {},
  ]) async {
    await connect();
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw const ApiException('Gerçek zamanlı bağlantı yok.');
    }

    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      event,
      data,
      ack: (raw) {
        if (completer.isCompleted) return;
        final result = _map(raw);
        if (result['ok'] == false) {
          completer.completeError(
            ApiException(result['error']?.toString() ?? 'İşlem başarısız oldu.'),
          );
          return;
        }
        completer.complete(result);
      },
    );
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw const ApiException('Sunucudan gerçek zamanlı yanıt alınamadı.'),
    );
  }

  static Future<Map<String, dynamic>> _ackWithReconnectRetry(
    String event,
    Map<String, dynamic> data, {
    int attempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await _ack(event, data);
      } catch (error) {
        lastError = error;
        if (attempt + 1 >= attempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
        try {
          await connect();
        } catch (_) {
          // Sonraki deneme Socket.IO reconnect döngüsünü tekrar kullanır.
        }
      }
    }
    throw lastError ?? const ApiException('Gerçek zamanlı işlem başarısız oldu.');
  }

  static Future<Map<String, dynamic>> joinQueue() => _ack('queue:join');
  static Future<Map<String, dynamic>> queueStatus() => _ack('queue:status');
  static Future<Map<String, dynamic>> cancelQueue() => _ack('queue:cancel');

  static Future<Map<String, dynamic>> joinRoom(String roomId) =>
      _ack('room:join', {'roomId': roomId});

  static Future<List<Map<String, dynamic>>> roomMessages(
    String roomId, {
    int after = 0,
  }) async {
    final result = await _ack('room:messages', {
      'roomId': roomId,
      'after': after,
    });
    return _listOfMaps(result['messages']);
  }

  static Future<void> leaveRoom(String roomId) async {
    try {
      await _ack('room:leave', {'roomId': roomId});
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> sendRoomMessage(String roomId, String body) {
    final clientMessageId = _newClientMessageId();
    return _ackWithReconnectRetry(
      'room:send',
      {
        'roomId': roomId,
        'body': body,
        'clientMessageId': clientMessageId,
      },
      attempts: 4,
    );
  }

  static Future<Map<String, dynamic>> voteRoomExtension(String roomId, bool vote) =>
      _ack('room:extension', {'roomId': roomId, 'vote': vote});

  static Future<Map<String, dynamic>> submitRoomSelection(
    String roomId,
    String selectedUserId,
  ) =>
      _ack(
        'room:selection',
        {'roomId': roomId, 'selectedUserId': int.parse(selectedUserId)},
      );

  static Future<Map<String, dynamic>> listMatches() => _ack('matches:list');

  static Future<Map<String, dynamic>> joinMatch(String matchId) =>
      _ack('match:join', {'matchId': matchId});

  static Future<List<Map<String, dynamic>>> privateMessages(
    String matchId, {
    int after = 0,
  }) async {
    final result = await _ack('match:messages', {
      'matchId': matchId,
      'after': after,
    });
    return _listOfMaps(result['messages']);
  }

  static Future<void> leaveMatch(String matchId) async {
    try {
      await _ack('match:leave', {'matchId': matchId});
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> sendPrivateMessage(String matchId, String body) =>
      _ack('match:send', {'matchId': matchId, 'body': body});

  static Future<Map<String, dynamic>> markMatchDelivered(
    String matchId,
    String messageId,
  ) =>
      _ack('match:delivered', {'matchId': matchId, 'messageId': messageId});

  static Future<Map<String, dynamic>> markMatchRead(String matchId) =>
      _ack('match:read', {'matchId': matchId});

  static Future<Map<String, dynamic>> deletePrivateMessage(
    String matchId,
    String messageId,
  ) =>
      _ack('match:delete', {'matchId': matchId, 'messageId': messageId});

  static void setTyping(String matchId, bool typing) {
    final socket = _socket;
    if (socket?.connected != true) return;
    socket!.emit('match:typing', {'matchId': matchId, 'typing': typing});
  }

  static void disconnect() {
    _socket?.dispose();
    _socket = null;
    _token = null;
    _connecting = null;
  }
}
