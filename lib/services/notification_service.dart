import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'feishu_service.dart';
import 'storage_service.dart';

/// 通知服务 - 基于 flutter_local_notifications
/// 负责通知渠道创建、权限请求、通知弹出
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 通知渠道 ID
  /// 注意: Android 8+ 渠道一旦创建 importance/声音 不可通过代码修改
  /// 如需调整必须更换新的渠道 ID
  /// v4: 取消通知音效(静默提醒) + 「动一动」改名
  static const String channelId = 'drinking_reminder_v4';
  static const String channelName = '动一动提醒';
  static const String channelDesc = '温柔的动一动小精灵提醒通知';

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
      importance: Importance.max,
      showBadge: true,
      enableVibration: true,
      playSound: false,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 删除旧版渠道 v2/v3(若存在),避免遗留配置干扰新渠道
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel('drinking_reminder_v2');
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel('drinking_reminder_v3');

    _initialized = true;
  }

  /// 请求 POST_NOTIFICATIONS 权限(Android 13+)
  /// 返回 true 表示已授权
  static Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 立即弹出一条「动一动」提醒通知(静默,无声音)
  /// 启用 fullScreenIntent + reminder category + ticker,让系统默认显示横幅
  static Future<void> showReminder({
    String title = '该动一动啦~',
    String body = '起来伸展一下,活动活动身体吧',
    int? id,
  }) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
      ticker: '动一动提醒',
      enableLights: true,
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
  /// 检查免打扰/重复周期:免打扰时段内完全不提醒、不弹通知

  /// 执行顺序(优化解决「循环闹钟通知成功但飞书推送失败」问题):
  /// 1. 弹出通知(最快,优先级最高)
  /// 2. 启动飞书推送并 await(关键任务)
  ///
  /// 原因:后台 isolate 在等待期间可能被系统杀死,先弹通知可确保用户感知,
  /// 再并行等待飞书推送,不被其它任务阻塞
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
    // reload() 确保后台 isolate 读到主 isolate 最新写入的配置(音效/音量等)
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // 免打扰检查:免打扰时段内完全不提醒、不弹任何通知
    if (_isInDndPeriod(prefs)) {
      debugPrint('[AlarmFired] 处于免打扰时段,跳过提醒(不弹通知)');
      return;
    }

    // 提醒生效时段界面已移除,不再检查时段范围
    // (保留重复周期检查)

    // 重复周期检查
    if (!_isRepeatDay(prefs)) {
      debugPrint('[AlarmFired] 今天不在重复周期内,跳过提醒');
      return;
    }

    debugPrint('[AlarmFired] 通过所有检查,执行提醒');

    // 1. 立即弹出通知(最优先,确保用户能感知到提醒)
    try {
      await showReminder(id: id);
    } catch (e) {
      debugPrint('[AlarmFired] showReminder 异常: $e');
    }

    // 2. 启动飞书推送(关键任务)
    debugPrint('[AlarmFired] 启动飞书推送');
    final pushFuture = FeishuService.pushReminderFromBackground();

    // 3. 等待飞书推送完成(关键任务,必须等待)
    try {
      await pushFuture;
      debugPrint('[AlarmFired] 飞书推送流程完成');
    } catch (e) {
      debugPrint('[AlarmFired] 飞书推送异常: $e');
    }

    // 4. 记录今日提醒次数(持久化,App 回前台时读取)
    try {
      await _recordReminderFired(prefs);
    } catch (e) {
      debugPrint('[AlarmFired] 记录提醒次数异常: $e');
    }

    debugPrint('[AlarmFired] 提醒流程全部完成');
  }

  /// 测试提醒:跳过所有条件检查,直接执行通知+飞书推送
  /// 用于验证闹钟机制是否正常工作
  @pragma('vm:entry-point')
  static Future<void> onTestAlarmFired() async {
    debugPrint('[TestAlarm] 测试闹钟触发, time=${DateTime.now()}');
    try {
      WidgetsFlutterBinding.ensureInitialized();
    } catch (_) {}
    await init();
    await showReminder(
      title: '测试提醒',
      body: '闹钟机制正常工作! ${DateTime.now().toString().substring(11, 19)}',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await FeishuService.pushReminderFromBackground();
    await _recordReminderFired(prefs);
    debugPrint('[TestAlarm] 测试提醒流程完成');
  }

  /// 记录提醒已触发(持久化今日提醒次数 + 上次提醒时间)
  /// App 回前台时由 AppState.syncReminderCount() 读取
  static Future<void> _recordReminderFired(SharedPreferences prefs) async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final savedDate = prefs.getString(StorageService.kTodayReminderDate);
    int count = prefs.getInt(StorageService.kTodayReminderCount) ?? 0;
    // 日期变更则重置计数
    if (savedDate != todayStr) {
      count = 0;
    }
    count++;
    await prefs.setInt(StorageService.kTodayReminderCount, count);
    await prefs.setString(StorageService.kTodayReminderDate, todayStr);
    await prefs.setString(StorageService.kLastReminderTime, today.toIso8601String());
  }

  /// 检查当前是否处于免打扰时段
  static bool _isInDndPeriod(SharedPreferences prefs) {
    final nightDnd = prefs.getBool(StorageService.kNightDnd) ?? true;
    final noonDnd = prefs.getBool(StorageService.kNoonDnd) ?? false;
    final noonStart = prefs.getString(StorageService.kNoonDndStart) ?? '12:30';
    final noonEnd = prefs.getString(StorageService.kNoonDndEnd) ?? '14:30';
    final nightStart = prefs.getString(StorageService.kNightDndStart) ?? '22:00';
    final nightEnd = prefs.getString(StorageService.kNightDndEnd) ?? '08:00';

    final now = DateTime.now();
    final hm = now.hour * 60 + now.minute;

    if (nightDnd && _inWindow(hm, nightStart, nightEnd)) return true;
    if (noonDnd && _inWindow(hm, noonStart, noonEnd)) return true;
    return false;
  }

  /// 判断 [minuteOfDay] 是否落在 "HH:mm" 区间内(支持跨天:结束 < 开始)
  static bool _inWindow(int minuteOfDay, String start, String end) {
    final s = _toMinute(start);
    final e = _toMinute(end);
    if (e > s) {
      return minuteOfDay >= s && minuteOfDay < e;
    }
    return minuteOfDay >= s || minuteOfDay < e;
  }

  static int _toMinute(String t) {
    final parts = t.split(':');
    final h = int.tryParse(parts.isEmpty ? '' : parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return h.clamp(0, 23) * 60 + m.clamp(0, 59);
  }

  /// 检查今天是否属于重复周期
  static bool _isRepeatDay(SharedPreferences prefs) {
    final repeatIndex = prefs.getInt(StorageService.kRepeat) ?? 0;
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
