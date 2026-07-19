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
  /// 注意: Android 8+ 渠道一旦创建 importance 不可通过代码修改
  /// 如需提升 importance 必须更换新的渠道 ID
  /// v3: 启用 fullScreenIntent 强制横幅显示 + 应用更名
  static const String channelId = 'drinking_reminder_v3';
  static const String channelName = '喝水小精灵提醒';
  static const String channelDesc = '温柔的喝水小精灵提醒通知';

  // SharedPreferences key 常量(与 StorageService 保持一致)
  static const _kNightDnd = 'nightDnd';
  static const _kNoonDnd = 'noonDnd';
  static const _kRangeStart = 'rangeStart';
  static const _kRangeEnd = 'rangeEnd';
  static const _kRepeat = 'repeat';
  static const _kSound = 'sound';
  // 扬声器提醒开关(新增,兼容旧 earphoneEnabled)
  static const _kSpeakerEnabled = 'speakerEnabled';
  static const _kLegacyEarphoneEnabled = 'earphoneEnabled';
  static const _kEarphoneVolume = 'earphoneVolume';

  // 今日提醒次数持久化 key
  static const _kTodayReminderCount = 'todayReminderCount';
  static const _kTodayReminderDate = 'todayReminderDate';
  static const _kLastReminderTime = 'lastReminderTime';

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
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 删除旧版渠道 v2(若存在),避免遗留配置干扰新渠道
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel('drinking_reminder_v2');

    _initialized = true;
  }

  /// 请求 POST_NOTIFICATIONS 权限(Android 13+)
  /// 返回 true 表示已授权
  static Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 立即弹出一条喝水提醒通知
  /// 启用 fullScreenIntent + reminder category + ticker,让系统默认显示横幅
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
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: true,
      ticker: '喝水小精灵提醒',
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
  /// 检查免打扰/提醒时段/重复周期,不满足条件时弹静默提示通知(让用户感知闹钟已触发)
  ///
  /// 执行顺序优化(解决「循环闹钟通知成功但飞书推送失败」问题):
  /// 1. 弹出通知(最快,优先级最高)
  /// 2. 并行启动飞书推送 + 音效播放
  /// 3. 只 await 飞书推送(关键任务),音效播放 fire-and-forget
  ///
  /// 原因:音效播放内部有 8 秒强制等待,串行会导致飞书推送延迟 8 秒才开始
  /// 后台 isolate 在等待期间可能被系统杀死,导致飞书推送代码无法执行
  /// 并行执行可确保飞书推送立即开始,不被音效阻塞
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

    // 免打扰检查
    if (_isInDndPeriod(prefs)) {
      debugPrint('[AlarmFired] 处于免打扰时段,跳过提醒(弹静默提示)');
      await _showSkippedNotification('当前处于免打扰时段,已静音提醒');
      return;
    }

    // 提醒时段检查
    if (!_isInRangeTime(prefs)) {
      debugPrint('[AlarmFired] 不在提醒时段内,跳过提醒(弹静默提示)');
      await _showSkippedNotification('当前不在提醒时段内,已静音提醒');
      return;
    }

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

    // 2. 并行启动飞书推送(关键任务)和音效播放(非关键)
    // 只 await 飞书推送,音效播放 fire-and-forget
    // 避免音效的 8 秒等待阻塞飞书推送,导致 isolate 被杀推送失败
    debugPrint('[AlarmFired] 启动飞书推送(并行)');
    final pushFuture = FeishuService.pushReminderFromBackground();

    // 音效播放(fire-and-forget,不 await,让它在后台继续播放)
    final speakerOn = prefs.getBool(_kSpeakerEnabled) ??
        prefs.getBool(_kLegacyEarphoneEnabled) ??
        true;
    if (speakerOn) {
      final soundName = prefs.getString(_kSound);
      final sound = SoundType.fromName(soundName);
      final volume = prefs.getDouble(_kEarphoneVolume) ?? 0.6;
      debugPrint('[AlarmFired] 启动音效播放(并行): ${sound.file}, 音量: $volume');
      // 故意不 await:音效播放不阻塞 onAlarmFired 退出
      // 即使 isolate 在音效播放期间被杀,飞书推送也已并行完成
      AudioService.playFromBackground(sound, volume: volume);
    } else {
      debugPrint('[AlarmFired] 扬声器提醒已关闭,仅显示通知');
    }

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

  /// 静默提示通知 - 闹钟已触发但被免打扰/时段拦截时使用
  /// 不带声音/振动,仅通知栏可见,让用户感知闹钟机制正常工作
  static Future<void> _showSkippedNotification(String reason) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '提醒已静音',
        '$reason(闹钟已正常触发)',
        details,
      );
    } catch (e) {
      debugPrint('[AlarmFired] 静默提示通知失败: $e');
    }
  }

  /// 测试提醒:跳过所有条件检查,直接执行通知+音效+飞书推送
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
    final speakerOn = prefs.getBool(_kSpeakerEnabled) ??
        prefs.getBool(_kLegacyEarphoneEnabled) ??
        true;
    if (speakerOn) {
      final soundName = prefs.getString(_kSound);
      final sound = SoundType.fromName(soundName);
      final volume = prefs.getDouble(_kEarphoneVolume) ?? 0.6;
      await AudioService.playFromBackground(sound, volume: volume);
    }
    await FeishuService.pushReminderFromBackground();
    await _recordReminderFired(prefs);
    debugPrint('[TestAlarm] 测试提醒流程完成');
  }

  /// 记录提醒已触发(持久化今日提醒次数 + 上次提醒时间)
  /// App 回前台时由 AppState.syncReminderCount() 读取
  static Future<void> _recordReminderFired(SharedPreferences prefs) async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final savedDate = prefs.getString(_kTodayReminderDate);
    int count = prefs.getInt(_kTodayReminderCount) ?? 0;
    // 日期变更则重置计数
    if (savedDate != todayStr) {
      count = 0;
    }
    count++;
    await prefs.setInt(_kTodayReminderCount, count);
    await prefs.setString(_kTodayReminderDate, todayStr);
    await prefs.setString(_kLastReminderTime, today.toIso8601String());
  }

  /// 检查当前是否处于免打扰时段
  static bool _isInDndPeriod(SharedPreferences prefs) {
    final nightDnd = prefs.getBool(_kNightDnd) ?? true;
    final noonDnd = prefs.getBool(_kNoonDnd) ?? false;

    final now = DateTime.now();
    final hm = now.hour * 60 + now.minute;

    if (nightDnd && (hm >= 22 * 60 || hm < 7 * 60)) return true;
    // 午休免打扰:12:30 ~ 14:30
    if (noonDnd && hm >= 12 * 60 + 30 && hm < 14 * 60 + 30) return true;

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
