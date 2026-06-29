import '../core/storage.dart';
import 'api_service.dart';

class AuthService {
  static Future<void> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    final result = await ApiService.post(
      '/register',
      {
        'username': username,
        'password': password,
        'nickname': nickname,
      },
      auth: false,
    );

    await _saveLoginResult(result);
  }

  static Future<void> login({
    required String username,
    required String password,
  }) async {
    final result = await ApiService.post(
      '/login',
      {
        'username': username,
        'password': password,
      },
      auth: false,
    );

    await _saveLoginResult(result);
  }

  static Future<void> _saveLoginResult(Map<String, dynamic> result) async {
    final user = result['user'] as Map<String, dynamic>;

    await AppStorage.saveAuth(
      token: result['token'],
      userId: user['id'],
      username: user['username'],
      nickname: user['nickname'],
      avatar: user['avatar'],
      bio: user['bio'],
      interests: List<String>.from(user['interests'] ?? const []),
    );
  }

  static Future<Map<String, dynamic>> getMe() async {
    final result = await ApiService.get('/me');
    final user = Map<String, dynamic>.from(result['user']);
    await _saveProfileResult(user);
    return user;
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? nickname,
    String? avatar,
    String? bio,
    List<String>? interests,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (nickname != null) body['nickname'] = nickname;
    if (avatar != null) body['avatar'] = avatar;
    if (bio != null) body['bio'] = bio;
    if (interests != null) body['interests'] = interests;

    final result = await ApiService.put('/me', body);

    final user = Map<String, dynamic>.from(result['user']);
    await _saveProfileResult(user);
    return user;
  }

  static Future<void> _saveProfileResult(Map<String, dynamic> user) async {
    await AppStorage.saveProfile(
      username: user['username'],
      nickname: user['nickname'],
      avatar: user['avatar'],
      bio: user['bio'],
      interests: List<String>.from(user['interests'] ?? const []),
    );
  }

  static Future<bool> isLoggedIn() async {
    final token = await AppStorage.getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    await AppStorage.clear();
  }
}