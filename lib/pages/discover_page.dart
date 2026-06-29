import 'dart:math';

import 'package:flutter/material.dart';

import '../core/storage.dart';
import '../services/chat_service.dart';
import '../widgets/match_dialog.dart';
import '../widgets/user_card.dart';
import 'chat_room_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  bool _loading = true;
  int _index = 0;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    ChatService.friendsVersion.addListener(_loadRecommendations);
    _loadRecommendations();
  }

  @override
  void dispose() {
    ChatService.friendsVersion.removeListener(_loadRecommendations);
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    try {
      final users = await ChatService.getRecommendations();
      if (!mounted) return;

      setState(() {
        _users = users;
        _index = 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _likeCurrentUser() async {
    if (_users.isEmpty) return;

    final user = _users[_index];

    await ChatService.addFriend(user['id']);

    final myAvatar = await AppStorage.getAvatar();
    final percent = 82 + Random().nextInt(16);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => MatchDialog(
        myAvatar: myAvatar,
        peerAvatar: user['avatar'],
        peerName: user['nickname'] ?? user['username'],
        matchPercent: percent,
        onMessage: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatRoomPage(
                peerId: user['id'],
                peerName: user['nickname'] ?? user['username'],
                peerAvatar: user['avatar'],
              ),
            ),
          );
        },
      ),
    );

    _removeCurrentUser();
  }

  void _skipCurrentUser() {
    _nextUser();
  }

  void _removeCurrentUser() {
    if (_users.isEmpty) return;

    setState(() {
      _users.removeAt(_index);
      if (_users.isEmpty) {
        _index = 0;
      } else if (_index >= _users.length) {
        _index = 0;
      }
    });
  }

  void _nextUser() {
    if (_users.isEmpty) return;

    setState(() {
      _index = (_index + 1) % _users.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _users.isEmpty ? null : _users[_index];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : user == null
                ? const Center(child: Text('暂无推荐用户'))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                    child: Column(
                      children: [
                        _buildTitle(),
                        const SizedBox(height: 18),
                        Expanded(child: _buildUserCard(user)),
                        const SizedBox(height: 20),
                        _buildActions(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildTitle() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '发现',
            style: TextStyle(
              color: Color(0xFF2D1B25),
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withValues(alpha: 0.08),
                blurRadius: 14,
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.tune, color: Colors.pink),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(dynamic user) {
    final name = user['nickname'] ?? user['username'] ?? '未知用户';
    final bio = user['bio'] ?? '很高兴在这里遇见你。';
    final avatar = user['avatar'];
    final interests = user['interests'] as List<dynamic>? ?? ['旅行', '音乐'];

    return UserCard(
      name: name,
      bio: bio,
      avatar: avatar,
      interests: interests,
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundActionButton(
          icon: Icons.sync_alt_rounded,
          color: Colors.grey.shade700,
          background: Colors.white,
          onTap: _skipCurrentUser,
        ),
        const SizedBox(width: 28),
        _roundActionButton(
          icon: Icons.favorite,
          color: Colors.white,
          background: Colors.pink,
          size: 72,
          iconSize: 34,
          onTap: _likeCurrentUser,
        ),
      ],
    );
  }

  Widget _roundActionButton({
    required IconData icon,
    required Color color,
    required Color background,
    required VoidCallback onTap,
    double size = 62,
    double iconSize = 28,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
    );
  }
}