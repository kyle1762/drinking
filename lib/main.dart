import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'theme/app_theme.dart';
import 'state/app_state.dart';
import 'pages/home_page.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/ai_service.dart';

/// 全局 ScaffoldMessenger key,用于在非 Widget 上下文中弹 SnackBar
/// (如 AiService 每次调用后上报 token 用量)
final GlobalKey<ScaffoldMessengerState> globalScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化持久化存储(必须在 AppState 创建前完成)
  await StorageService.init();
  // 加载用户自定义食物营养表(食材未匹配时由 AI 补全并持久化的数据)
  StorageService.loadCustomFoodNutrition();
  // 初始化时区数据(device_calendar v4 需要 TZDateTime)
  tz_data.initializeTimeZones();
  // 初始化通知渠道
  await NotificationService.init();
  // 初始化闹钟服务
  await AlarmService.init();
  // 每次 AI API 调用后,通过全局 SnackBar 告知用户本次消耗的 token 值
  AiService.onUsageReported = (message) {
    globalScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  };
  runApp(const DrinkingApp());
}

class DrinkingApp extends StatelessWidget {
  const DrinkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: '喝水小精灵',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: globalScaffoldMessengerKey,
        theme: AppTheme.light,
        home: const HomePage(),
      ),
    );
  }
}
