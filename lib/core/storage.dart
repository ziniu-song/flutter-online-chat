import 'package:shared_preferences/shared_preferences.dart';

class AppStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _nicknameKey = 'nickname';
  static const String _avatarKey = 'avatar';
  static const String _bioKey = 'bio';
  static const String _interestsKey = 'interests';

  static Future<void> saveAuth({
    required String token,
    required int userId,
    required String username,
    required String nickname,
    String? avatar,
    String? bio,
    List<String> interests = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_nicknameKey, nickname);
    await prefs.setString(_bioKey, bio ?? '');
    await prefs.setStringList(_interestsKey, interests);

    if (avatar != null) {
      await prefs.setString(_avatarKey, avatar);
    }
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<String?> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nicknameKey);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String?> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarKey);
  }

  static Future<String?> getBio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bioKey);
  }

  static Future<List<String>> getInterests() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_interestsKey) ?? [];
  }

  static Future<void> saveProfile({
    required String username,
    required String nickname,
    String? avatar,
    String? bio,
    List<String> interests = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_nicknameKey, nickname);
    await prefs.setString(_bioKey, bio ?? '');
    await prefs.setStringList(_interestsKey, interests);

    if (avatar == null || avatar.isEmpty) {
      await prefs.remove(_avatarKey);
    } else {
      await prefs.setString(_avatarKey, avatar);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}