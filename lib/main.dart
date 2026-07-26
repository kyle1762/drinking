import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'theme/app_theme.dart';
import 'state/app_state.dart';
import 'pages/home_page.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/audio_service.dart';

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
  // 初始化音频服务(配置混合模式 AudioContext)
  await AudioService.init();
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
        theme: AppTheme.light,
        home: const HomePage(),
      ),
    );
  }
}
