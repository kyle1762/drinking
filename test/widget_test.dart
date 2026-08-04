import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drinking/pages/home_page.dart';
import 'package:drinking/state/app_state.dart';
import 'package:drinking/services/storage_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 预置已询问过的标记,避免首启弹窗打断测试
    SharedPreferences.setMockInitialValues({
      'hasPromptedNotification': true,
      'hasPromptedNoonDnd': true,
    });
    await StorageService.init();
  });

  testWidgets('首页渲染三个 Tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();

    // 底部三 Tab
    expect(find.text('热量追踪'), findsOneWidget);
    expect(find.text('喝水提醒'), findsOneWidget);
    expect(find.text('ai&飞书'), findsOneWidget);

    // 卸载页面,取消 HomePage 的周期定时器
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
