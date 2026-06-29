import 'package:flutter/material.dart';

import '../core/storage.dart';
import '../local/local_message_db.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _username;
  String? _nickname;
  String? _avatar;
  String? _bio;
  List<String> _interests = [];
  bool _saving = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final username = await AppStorage.getUsername();
    final nickname = await AppStorage.getNickname();
    final avatar = await AppStorage.getAvatar();
    final bio = await AppStorage.getBio();
    final interests = await AppStorage.getInterests();

    if (!mounted) return;
    setState(() {
      _username = username;
      _nickname = nickname;
      _avatar = avatar;
      _bio = bio;
      _interests = interests;
    });

    try {
      final user = await AuthService.getMe();
      _applyUser(user);
    } catch (_) {
      // 本地缓存已经足够展示资料；网络失败时不打断页面。
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);

    SocketService.instance.disconnect();

    try {
      await LocalMessageDb.instance.clear();
    } catch (_) {
      // 清理本地缓存失败不应影响账号退出，尤其是 Web 调试环境不支持 sqflite。
    }

    await AuthService.logout();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _applyUser(Map<String, dynamic> user) {
    if (!mounted) return;
    setState(() {
      _username = user['username']?.toString();
      _nickname = user['nickname']?.toString();
      _avatar = user['avatar']?.toString();
      _bio = user['bio']?.toString();
      _interests = List<String>.from(user['interests'] ?? const []);
    });
  }

  Future<void> _updateProfile({
    String? username,
    String? nickname,
    String? avatar,
    String? bio,
    List<String>? interests,
  }) async {
    setState(() => _saving = true);

    try {
      final user = await AuthService.updateProfile(
        username: username ?? _username,
        nickname: nickname ?? _nickname,
        avatar: avatar ?? _avatar,
        bio: bio ?? _bio,
        interests: interests ?? _interests,
      );
      _applyUser(user);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('资料已更新')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editText({
    required String title,
    required String label,
    required String initialValue,
    required ValueChanged<String> onSubmit,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null || result.isEmpty) return;
    onSubmit(result);
  }

  Future<void> _editInterests() async {
    final controller = TextEditingController(text: _interests.join('，'));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改兴趣标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '兴趣标签',
            hintText: '例如：旅行，音乐，电影',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result == null) return;
    final interests = result
        .split(RegExp(r'[,，]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    await _updateProfile(interests: interests);
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _nickname ?? '粉恋用户';
    final username = _username ?? '未设置用户名';
    final bio = _bio?.isNotEmpty == true ? _bio! : '准备好开启一段有趣的聊天';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '我的',
                  style: TextStyle(
                    color: Color(0xFF2D1B25),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: Colors.pink.shade100,
                      backgroundImage:
                          _avatar != null ? NetworkImage(_avatar!) : null,
                      child: _avatar == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 54,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      nickname,
                      style: const TextStyle(
                        color: Color(0xFF2D1B25),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@$username',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    if (_interests.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _interests
                            .map(
                              (item) => Chip(
                                label: Text(item),
                                backgroundColor: Colors.pink.shade50,
                                labelStyle:
                                    const TextStyle(color: Colors.pink),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _ProfileActionTile(
                icon: Icons.image_outlined,
                title: '修改头像',
                subtitle: '填写网络图片地址',
                enabled: !_saving,
                onTap: () => _editText(
                  title: '修改头像',
                  label: '头像 URL',
                  initialValue: _avatar ?? '',
                  onSubmit: (value) => _updateProfile(avatar: value),
                ),
              ),
              _ProfileActionTile(
                icon: Icons.badge_outlined,
                title: '修改昵称',
                subtitle: nickname,
                enabled: !_saving,
                onTap: () => _editText(
                  title: '修改昵称',
                  label: '昵称',
                  initialValue: nickname,
                  onSubmit: (value) => _updateProfile(nickname: value),
                ),
              ),
              _ProfileActionTile(
                icon: Icons.alternate_email,
                title: '修改用户名',
                subtitle: username,
                enabled: !_saving,
                onTap: () => _editText(
                  title: '修改用户名',
                  label: '用户名',
                  initialValue: _username ?? '',
                  onSubmit: (value) => _updateProfile(username: value),
                ),
              ),
              _ProfileActionTile(
                icon: Icons.edit_note_outlined,
                title: '修改自我介绍',
                subtitle: bio,
                enabled: !_saving,
                onTap: () => _editText(
                  title: '修改自我介绍',
                  label: '自我介绍',
                  initialValue: _bio ?? '',
                  maxLines: 3,
                  onSubmit: (value) => _updateProfile(bio: value),
                ),
              ),
              _ProfileActionTile(
                icon: Icons.local_offer_outlined,
                title: '修改兴趣标签',
                subtitle: _interests.isEmpty ? '暂未设置' : _interests.join('、'),
                enabled: !_saving,
                onTap: _editInterests,
              ),
              _ProfileActionTile(
                icon: Icons.refresh,
                title: '刷新资料',
                subtitle: '从服务器同步最新资料',
                enabled: !_saving,
                onTap: _loadProfile,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loggingOut ? null : _logout,
                  icon: const Icon(Icons.logout),
                  label: Text(_loggingOut ? '正在退出...' : '退出登录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.pink,
                    side: const BorderSide(color: Colors.pink),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        enabled: enabled,
        leading: CircleAvatar(
          backgroundColor: Colors.pink.shade50,
          child: Icon(icon, color: Colors.pink),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
