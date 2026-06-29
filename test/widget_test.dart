import 'package:flutter_test/flutter_test.dart';

import 'package:onlinechat/app.dart';

void main() {
  testWidgets('未登录时显示登录页', (tester) async {
    await tester.pumpWidget(const OnlineChatApp());
    await tester.pumpAndSettle();

    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
