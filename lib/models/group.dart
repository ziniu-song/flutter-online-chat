class ChatGroup {
  const ChatGroup({
    required this.id,
    required this.name,
    this.avatar,
    required this.createdBy,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String? avatar;
  final int createdBy;
  final DateTime createdAt;

  factory ChatGroup.fromJson(Map<String, dynamic> json) {
    return ChatGroup(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '群聊',
      avatar: json['avatar']?.toString(),
      createdBy: json['created_by'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
