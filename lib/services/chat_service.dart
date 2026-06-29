import 'package:flutter/foundation.dart';

import '../models/message.dart';
import 'api_service.dart';

class ChatService {
  static final ValueNotifier<int> friendsVersion = ValueNotifier<int>(0);

  static Future<List<dynamic>> getFriends() async {
    final result = await ApiService.get('/friends');
    return result['friends'] ?? [];
  }

  static Future<void> addFriend(int friendId) async {
    await ApiService.post('/friends', {
      'friend_id': friendId,
    });
    friendsVersion.value++;
  }

  static Future<void> removeFriend(int friendId) async {
    await ApiService.delete('/friends/$friendId');
    friendsVersion.value++;
  }

  static Future<Map<String, dynamic>> getUser(int userId) async {
    final result = await ApiService.get('/users/$userId');
    return Map<String, dynamic>.from(result['user']);
  }

  static Future<List<dynamic>> getRecommendations() async {
    final result = await ApiService.get('/users/recommendations');
    return result['users'] ?? [];
  }

  static Future<List<ChatMessage>> getPrivateHistory(int friendId) async {
    final result = await ApiService.get('/messages/private/$friendId');
    final list = result['messages'] as List<dynamic>? ?? [];

    return list
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<List<ChatMessage>> getGroupHistory(int groupId) async {
    final result = await ApiService.get('/messages/group/$groupId');
    final list = result['messages'] as List<dynamic>? ?? [];

    return list
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}