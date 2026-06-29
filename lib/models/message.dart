class ChatMessage {
  final int id;
  final int senderId;
  final int? receiverId;
  final int? groupId;
  final String content;
  final String messageType;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.receiverId,
    this.groupId,
    required this.content,
    required this.messageType,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: _asInt(json['id']) ?? 0,
      senderId: _asInt(json['sender_id']) ?? 0,
      receiverId: _asInt(json['receiver_id']),
      groupId: _asInt(json['group_id']),
      content: json['content'] ?? '',
      messageType: json['message_type'] ?? 'text',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      senderName: json['sender_name']?.toString(),
      senderAvatar: json['sender_avatar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'group_id': groupId,
      'content': content,
      'message_type': messageType,
      'created_at': createdAt.toIso8601String(),
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
    };
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}