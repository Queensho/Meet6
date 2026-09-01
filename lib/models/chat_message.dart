class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    required this.time,
    this.isMine = false,
    this.isSystem = false,
    this.avatarLabel = '',
  });

  final String sender;
  final String text;
  final String time;
  final bool isMine;
  final bool isSystem;
  final String avatarLabel;
}
