import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// 通知服务 - 基于 flutter_local_notifications
/// 负责通知渠道创建、权限请求、通知弹出
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 通知渠道 ID
  static const String channelId = 'drinking_reminder';
  static const String channelName = '喝水提醒';
  static const String channelDesc = '温柔的喝水提醒通知';

  /// 初始化插件与通知渠道
  static Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// 请求 POST_NOTIFICATIONS 权限(Android 13+)
  /// 返回 true 表示已授权
  static Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 立即弹出一条喝水提醒通知
  static Future<void> showReminder({
    String title = '该喝水啦~',
    String body = '记得补充水分,保持身体水润',
    int? id,
  }) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  /// 取消所有已显示的通知
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 闹钟触发时的回调入口(后台 isolate 也能调用)
  /// 由 AlarmService 的顶层 callback 调用
  @pragma('vm:entry-point')
  static Future<void> onAlarmFired(int id) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
    } catch (_) {
      // 已初始化,忽略
    }
    await init();
    await showReminder(id: id);
  }
}
