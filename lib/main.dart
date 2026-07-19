import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
