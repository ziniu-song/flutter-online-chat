import 'dart:async';

import 'package:flutter/material.dart';

import '../core/storage.dart';
import '../local/local_message_db.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../widgets/message_bubble.dart';
import 'peer_profile_page.dart';

class ChatRoomPage extends StatefulWidget {
  const ChatRoomPage({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
    this.groupId,
  });

  final int peerId;
  final String peerName;
  final String? peerAvatar;
  final int? groupId;

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<ChatMessage>? _messageSub;
  StreamSubscription<String>? _errorSub;

  int? _currentUserId;
  bool _loading = true;
  bool _sending = false;
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    _currentUserId = await AppStorage.getUserId();

    try {
      await SocketService.instance.connect();
    } catch (_) {
      // 网络未就绪时仍然可以查看本地缓存的历史消息。
    }

    if (widget.groupId != null) {
      await SocketService.instance.joinGroup(widget.groupId!);
    }

    List<ChatMessage> history;
    try {
      history = widget.groupId == null
          ? await ChatService.getPrivateHistory(widget.peerId)
          : await ChatService.getGroupHistory(widget.groupId!);
      await LocalMessageDb.instance.upsertMessages(history);
    } catch (_) {
      history = await _loadCachedMessages();
    }

    _messageSub = SocketService.instance.messageStream.listen((message) {
      if (!mounted) return;

      final isCurrentPrivateChat = widget.groupId == null &&
          ((message.senderId == widget.peerId &&
                  message.receiverId == _currentUserId) ||
              (message.senderId == _currentUserId &&
                  message.receiverId == widget.peerId));

      final isCurrentGroupChat =
          widget.groupId != null && message.groupId == widget.groupId;

      if (isCurrentPrivateChat || isCurrentGroupChat) {
        LocalMessageDb.instance.upsertMessage(message);
        setState(() {
          _appendMessage(message);
        });
        _scrollToBottom();
      }
    });

    _errorSub = SocketService.instance.errorStream.listen((message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });

    if (!mounted) return;

    setState(() {
      _messages = _sortedMessages(history);
      _loading = false;
    });

    _scrollToBottom();
  }

  List<ChatMessage> _sortedMessages(List<ChatMessage> messages) {
    final sorted = List<ChatMessage>.from(messages);
    sorted.sort((a, b) {
      final timeCompare = a.createdAt.compareTo(b.createdAt);
      if (timeCompare != 0) return timeCompare;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  void _appendMessage(ChatMessage message) {
    if (_messages.any((item) => item.id == message.id && message.id != 0)) {
      return;
    }
    _messages.add(message);
    _messages = _sortedMessages(_messages);
  }

  Future<List<ChatMessage>> _loadCachedMessages() async {
    final currentUserId = _currentUserId;
    if (widget.groupId != null) {
      return LocalMessageDb.instance.getGroupMessages(widget.groupId!);
    }

    if (currentUserId == null) return [];

    return LocalMessageDb.instance.getPrivateMessages(
      currentUserId: currentUserId,
      peerId: widget.peerId,
    );
  }

  Future<void> _send() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _sending) return;

    _inputController.clear();
    setState(() => _sending = true);

    try {
      if (widget.groupId == null) {
        await SocketService.instance.sendPrivateMessage(
          receiverId: widget.peerId,
          content: content,
        );
      } else {
        await SocketService.instance.sendGroupMessage(
          groupId: widget.groupId!,
          content: content,
        );
      }
    } catch (error) {
      _inputController.text = content;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _errorSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFFF7FA),
        foregroundColor: const Color(0xFF2D1B25),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.pink.shade100,
              backgroundImage:
                  widget.peerAvatar != null ? NetworkImage(widget.peerAvatar!) : null,
              child: widget.peerAvatar == null
                  ? Text(widget.peerName.substring(0, 1).toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.peerName,
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: widget.groupId == null
            ? [
                IconButton(
                  tooltip: '查看资料',
                  icon: const Icon(Icons.info_outline),
                  onPressed: () async {
                    final deleted = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PeerProfilePage(
                          peerId: widget.peerId,
                          peerName: widget.peerName,
                          peerAvatar: widget.peerAvatar,
                        ),
                      ),
                    );

                    if (!context.mounted) return;
                    if (deleted == true) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return MessageBubble(
                        message: message,
                        isMe: message.senderId == _currentUserId,
                      );
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '输入想说的话...',
                  filled: true,
                  fillColor: const Color(0xFFFFF2F7),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(26),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                color: Colors.pink,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                color: Colors.white,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                onPressed: _sending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}