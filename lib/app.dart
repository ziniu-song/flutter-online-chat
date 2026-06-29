import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'pages/login_page.dart';
import 'pages/main_tab_page.dart';
import 'services/auth_service.dart';

class OnlineChatApp extends StatelessWidget {
  const OnlineChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '粉恋聊天',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data == true ? const MainTabPage() : const LoginPage();
      },
    );
  }
}
