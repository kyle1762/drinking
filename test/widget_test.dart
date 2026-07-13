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
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('App builds and shows three tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: HomePage()),
      ),
    );

    // 默认首页 Tab1 标题
    expect(find.text('提醒设置'), findsWidgets);
    // 底部三 Tab
    expect(find.text('喝水统计'), findsOneWidget);
    expect(find.text('账号&飞书'), findsOneWidget);
  });
}
