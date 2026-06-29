import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/chat_service.dart';
import 'chat_room_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  List<dynamic> _friends = [];

  @override
  void initState() {
    super.initState();
    ChatService.friendsVersion.addListener(_loadFriends);
    _loadFriends();
  }

  @override
  void dispose() {
    ChatService.friendsVersion.removeListener(_loadFriends);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await ChatService.getFriends();
      if (!mounted) return;

      setState(() {
        _friends = friends;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchController.text.trim().toLowerCase();

    final visibleFriends = _friends.where((friend) {
      final name = '${friend['nickname'] ?? friend['username'] ?? ''}';
      return name.toLowerCase().contains(keyword);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBox(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visibleFriends.isEmpty
                      ? const _EmptyChats()
                      : RefreshIndicator(
                      color: Colors.pink,
                      onRefresh: _loadFriends,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: visibleFriends.length,
                        itemBuilder: (context, index) {
                          final friend = visibleFriends[index];
                          return _ChatTile(
                            friend: friend,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomPage(
                                    peerId: friend['id'],
                                    peerName: friend['nickname'] ?? friend['username'],
                                    peerAvatar: friend['avatar'],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '聊天',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D1B25),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.pink.shade50,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.pink),
              onPressed: _loadFriends,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: '搜索好友',
          prefixIcon: const Icon(Icons.search, color: Colors.pink),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, color: Colors.pink.shade200, size: 56),
            const SizedBox(height: 14),
            const Text(
              '暂无好友',
              style: TextStyle(
                color: Color(0xFF2D1B25),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '去发现页点击爱心，添加你的心动好友。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.friend,
    required this.onTap,
  });

  final dynamic friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = friend['nickname'] ?? friend['username'] ?? '未知用户';
    final avatar = friend['avatar'];
    final preview = friend['bio'] ?? '打个招呼，开启一段甜甜的聊天';
    final timeText = DateFormat('HH:mm').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.pink.shade100,
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? Text(
                      name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D1B25),
          ),
        ),
        subtitle: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: Text(
          timeText,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}