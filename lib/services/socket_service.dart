import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../core/constants.dart';
import '../core/storage.dart';
import '../models/message.dart';

class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  Completer<void>? _connectCompleter;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    final token = await AppStorage.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('未找到登录凭证，请重新登录');
    }

    if (_socket != null && _socket!.connected) {
      return;
    }

    if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
      return _connectCompleter!.future;
    }

    _connectCompleter = Completer<void>();

    _socket = io.io(
      AppConstants.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.complete();
      }
      _socket!.emit('client_ready', {'token': token});
    });

    _socket!.on('connected', (data) {
      // 服务端鉴权通过后返回 connected 事件。
    });

    _socket!.on('new_message', (data) {
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      _messageController.add(message);
    });

    _socket!.onConnectError((data) {
      final message = data?.toString() ?? '实时连接失败';
      _errorController.add(message);
      if (_connectCompleter != null && !_connectCompleter!.isCompleted) {
        _connectCompleter!.completeError(Exception(message));
      }
    });

    _socket!.onError((data) {
      _errorController.add(data?.toString() ?? '实时连接异常');
    });

    _socket!.on('error', (data) {
      if (data is Map && data['message'] != null) {
        _errorController.add(data['message'].toString());
      } else {
        _errorController.add('实时连接异常');
      }
    });

    _socket!.onDisconnect((_) {});

    _socket!.connect();
    return _connectCompleter!.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw Exception('连接聊天服务器超时');
      },
    );
  }

  Future<void> sendPrivateMessage({
    required int receiverId,
    required String content,
  }) async {
    await connect();
    final token = await AppStorage.getToken();

    _socket?.emit('send_message', {
      'token': token,
      'receiver_id': receiverId,
      'content': content,
      'message_type': 'text',
    });
  }

  Future<void> sendGroupMessage({
    required int groupId,
    required String content,
  }) async {
    await connect();
    final token = await AppStorage.getToken();

    _socket?.emit('send_message', {
      'token': token,
      'group_id': groupId,
      'content': content,
      'message_type': 'text',
    });
  }

  Future<void> joinGroup(int groupId) async {
    await connect();
    final token = await AppStorage.getToken();

    _socket?.emit('join_group', {
      'token': token,
      'group_id': groupId,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectCompleter = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _errorController.close();
  }
}