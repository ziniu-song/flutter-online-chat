class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.name,
    this.avatar,
    this.preview,
    this.unreadCount = 0,
    this.updatedAt,
    this.isGroup = false,
  });

  final int id;
  final String name;
  final String? avatar;
  final String? preview;
  final int unreadCount;
  final DateTime? updatedAt;
  final bool isGroup;
}
