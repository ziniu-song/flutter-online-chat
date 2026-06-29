class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.nickname,
    this.avatar,
    this.bio,
    this.interests = const [],
  });

  final int id;
  final String username;
  final String nickname;
  final String? avatar;
  final String? bio;
  final List<String> interests;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawInterests = json['interests'];

    return AppUser(
      id: json['id'] as int,
      username: json['username']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? json['username']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      bio: json['bio']?.toString(),
      interests: rawInterests is List
          ? rawInterests.map((item) => item.toString()).toList()
          : rawInterests is String && rawInterests.isNotEmpty
              ? rawInterests.split(',').map((item) => item.trim()).toList()
              : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatar': avatar,
      'bio': bio,
      'interests': interests,
    };
  }
}
