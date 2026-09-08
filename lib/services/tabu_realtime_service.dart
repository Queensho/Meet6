import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_service.dart';
import 'session_service.dart';

class TabuRealtimeEvent {
  const TabuRealtimeEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}

class TabuRealtimeService {
  const TabuRealtimeService._();

  static io.Socket? _socket;
  static String? _token;
  static Completer<void>? _connecting;
  static final _events = StreamController<TabuRealtimeEvent>.broadcast();

  static Stream<TabuRealtimeEvent> get events => _events.stream;

  static Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  static void _register(io.Socket socket) {
    const names = [
      'tabu:ready',
      'tabu:error',
      'tabu:round_started',
      'tabu:speaker_message',
      'tabu:guess_submitted',
      'tabu:forbidden_used',
      'tabu:correct_guess',
      'tabu:word_skipped',
      'tabu:speaker_turn_ended',
      'tabu:game_finished',
    ];
    for (final name in names) {
      socket.on(name, (raw) => _events.add(TabuRealtimeEvent(name, _map(raw))));
    }
    socket.onConnect((_) {
      if (!(_connecting?.isCompleted ?? true)) _connecting?.complete();
      _events.add(const TabuRealtimeEvent('connection:connected', {}));
    });
    socket.onDisconnect((reason) {
      _events.add(TabuRealtimeEvent('connection:disconnected', {'reason': '$reason'}));
    });
    socket.onConnectError((error) {
      if (!(_connecting?.isCompleted ?? true)) {
        _connecting?.completeError(const ApiException('Tabu canlı bağlantısı kurulamadı.'));
      }
      _events.add(TabuRealtimeEvent('connection:error', {'message': '$error'}));
    });
  }

  static Future<void> connect() async {
    final token = await SessionService.loadAuthSessionId();
    if (token == null || token.isEmpty) throw const ApiException('Oturum bulunamadı.');
    if (_socket != null && _token == token) {
      if (_socket!.connected) return;
      _connecting = Completer<void>();
      _socket!.connect();
      return _connecting!.future.timeout(const Duration(seconds: 12));
    }
    _socket?.dispose();
    _token = token;
    _connecting = Completer<void>();
    final socket = io.io(
      '${ApiService.baseUrl}/tabu',
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 1000000,
        'reconnectionDelay': 500,
        'reconnectionDelayMax': 4000,
        'timeout': 10000,
        'auth': {'token': token},
      },
    );
    _socket = socket;
    _register(socket);
    socket.connect();
    return _connecting!.future.timeout(const Duration(seconds: 12));
  }

  static Future<Map<String, dynamic>> _ack(String event, Map<String, dynamic> data) async {
    await connect();
    final socket = _socket;
    if (socket == null || !socket.connected) throw const ApiException('Tabu canlı bağlantısı yok.');
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(event, data, ack: (raw) {
      if (completer.isCompleted) return;
      final result = _map(raw);
      if (result['ok'] == false) {
        completer.completeError(ApiException(result['error']?.toString() ?? 'Tabu işlemi başarısız.'));
      } else {
        completer.complete(result);
      }
    });
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw const ApiException('Tabu sunucusundan yanıt alınamadı.'),
    );
  }

  static Future<Map<String, dynamic>> join(String roomId) =>
      _ack('tabu:join', {'roomId': roomId});

  static Future<Map<String, dynamic>> speakerMessage(String roomId, String text) =>
      _ack('tabu:speaker_message', {'roomId': roomId, 'text': text});

  static Future<Map<String, dynamic>> guess(String roomId, String guess) =>
      _ack('tabu:guess_submitted', {'roomId': roomId, 'guess': guess});

  static Future<Map<String, dynamic>> skip(String roomId) =>
      _ack('tabu:word_skipped', {'roomId': roomId});

  static void disconnect() {
    _socket?.dispose();
    _socket = null;
    _token = null;
    _connecting = null;
  }
}
