import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'audio_service.dart';
import 'feishu_service.dart';

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

  // SharedPreferences key 常量(与 StorageService 保持一致)
  static const _kNightDnd = 'nightDnd';
  static const _kNoonDnd = 'noonDnd';
  static const _kRangeStart = 'rangeStart';
  static const _kRangeEnd = 'rangeEnd';
  static const _kRepeat = 'repeat';
  static const _kSound = 'sound';
  static const _kEarphoneEnabled = 'earphoneEnabled';
  static const _kEarphoneVolume = 'earphoneVolume';

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
  /// 检查免打扰/提醒时段/重复周期,不满足条件时静默跳过
  @pragma('vm:entry-point')
  static Future<void> onAlarmFired(int id) async {
    debugPrint('[AlarmFired] 闹钟触发, id=$id, time=${DateTime.now()}');
    try {
      WidgetsFlutterBinding.ensureInitialized();
    } catch (_) {
      // 已初始化,忽略
    }
    await init();

    // 读取 SharedPreferences 检查是否应该提醒
    final prefs = await SharedPreferences.getInstance();

    // 免打扰检查
    if (_isInDndPeriod(prefs)) {
      debugPrint('[AlarmFired] 处于免打扰时段,跳过提醒');
      return;
    }

    // 提醒时段检查
    if (!_isInRangeTime(prefs)) {
      debugPrint('[AlarmFired] 不在提醒时段内,跳过提醒');
      return;
    }

    // 重复周期检查
    if (!_isRepeatDay(prefs)) {
      debugPrint('[AlarmFired] 今天不在重复周期内,跳过提醒');
      return;
    }

    debugPrint('[AlarmFired] 通过所有检查,执行提醒');
    await showReminder(id: id);

    // 播放治愈音效(从 SharedPreferences 读取用户配置的音效类型与音量)
    // 使用 playFromBackground 在后台 isolate 中独立播放,配置了混合模式
    if (prefs.getBool(_kEarphoneEnabled) ?? true) {
      final soundName = prefs.getString(_kSound);
      final sound = SoundType.fromName(soundName);
      final volume = prefs.getDouble(_kEarphoneVolume) ?? 0.6;
      debugPrint('[AlarmFired] 播放音效: ${sound.file}, 音量: $volume');
      await AudioService.playFromBackground(sound, volume: volume);
    }

    // 同时发送飞书推送(后台 isolate 中直接读 SharedPreferences)
    debugPrint('[AlarmFired] 发送飞书推送');
    await FeishuService.pushReminderFromBackground();
    debugPrint('[AlarmFired] 提醒流程完成');
  }

  /// 检查当前是否处于免打扰时段
  static bool _isInDndPeriod(SharedPreferences prefs) {
    final nightDnd = prefs.getBool(_kNightDnd) ?? true;
    final noonDnd = prefs.getBool(_kNoonDnd) ?? true;

    final now = DateTime.now();
    final hm = now.hour * 60 + now.minute;

    if (nightDnd && (hm >= 22 * 60 || hm < 7 * 60)) return true;
    if (noonDnd && hm >= 12 * 60 + 30 && hm < 13 * 60 + 30) return true;

    return false;
  }

  /// 检查当前是否在提醒生效时段内
  static bool _isInRangeTime(SharedPreferences prefs) {
    final start = prefs.getString(_kRangeStart) ?? '08:00';
    final end = prefs.getString(_kRangeEnd) ?? '21:00';

    final startParts = start.split(':');
    final endParts = end.split(':');
    if (startParts.length != 2 || endParts.length != 2) return true;

    final startH = int.tryParse(startParts[0]);
    final startM = int.tryParse(startParts[1]);
    final endH = int.tryParse(endParts[0]);
    final endM = int.tryParse(endParts[1]);
    if (startH == null || startM == null || endH == null || endM == null) {
      return true; // 解析失败时不拦截,默认允许提醒
    }

    final startMin = startH * 60 + startM;
    final endMin = endH * 60 + endM;

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    return nowMin >= startMin && nowMin <= endMin;
  }

  /// 检查今天是否属于重复周期
  static bool _isRepeatDay(SharedPreferences prefs) {
    final repeatIndex = prefs.getInt(_kRepeat) ?? 0;
    final weekday = DateTime.now().weekday;

    switch (repeatIndex) {
      case 0:
        return true; // 每天
      case 1:
        return weekday <= 5; // 工作日
      case 2:
        return weekday >= 6; // 周末
      default:
        return true;
    }
  }
}
