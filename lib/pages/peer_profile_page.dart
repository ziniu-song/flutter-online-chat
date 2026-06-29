import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../widgets/user_card.dart';

class PeerProfilePage extends StatefulWidget {
  const PeerProfilePage({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });

  final int peerId;
  final String peerName;
  final String? peerAvatar;

  @override
  State<PeerProfilePage> createState() => _PeerProfilePageState();
}

class _PeerProfilePageState extends State<PeerProfilePage> {
  bool _loading = true;
  bool _deleting = false;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await ChatService.getUser(widget.peerId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除「${widget.peerName}」吗？删除后对方会重新出现在发现页。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _deleting = true);

    try {
      await ChatService.removeFriend(widget.peerId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final name = user?['nickname'] ?? user?['username'] ?? widget.peerName;
    final username = user?['username']?.toString() ?? '';
    final bio = user?['bio']?.toString() ?? '暂无自我介绍';
    final avatar = user?['avatar']?.toString() ?? widget.peerAvatar;
    final interests = user?['interests'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),
      appBar: AppBar(
        title: const Text('好友资料'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 360,
                    child: UserCard(
                      name: name,
                      bio: bio,
                      avatar: avatar,
                      interests: interests.isEmpty ? ['暂无标签'] : interests,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _InfoTile(
                    icon: Icons.alternate_email,
                    label: '用户名',
                    value: username.isEmpty ? '未设置' : username,
                  ),
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: '昵称',
                    value: name,
                  ),
                  _InfoTile(
                    icon: Icons.notes_outlined,
                    label: '自我介绍',
                    value: bio,
                  ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: _deleting ? null : _confirmDelete,
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_remove_outlined),
                    label: Text(_deleting ? '正在删除...' : '删除好友'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.pink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF2D1B25),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
