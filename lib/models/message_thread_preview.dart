class MessageThreadPreview {
  const MessageThreadPreview({
    required this.name,
    required this.lastMessage,
    required this.timeLabel,
    required this.initial,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isNewMatch = false,
  });

  final String name;
  final String lastMessage;
  final String timeLabel;
  final String initial;
  final int unreadCount;
  final bool isOnline;
  final bool isNewMatch;
}
