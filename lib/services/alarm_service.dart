import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// 闹钟服务 - 基于 android_alarm_manager_plus
/// 使用 oneShotAt(绝对时间) + 回调中重新注册的方式实现可靠循环
class AlarmService {
  /// 循环提醒的固定闹钟 ID(0 保留给循环)
  static const int loopAlarmId = 0;

  /// 单次提醒 ID 的起始基数(避免与循环 ID 冲突)
  static const int singleAlarmBase = 1000;

  /// SharedPreferences 中存储循环间隔的 key
  static const String kLoopInterval = 'loopInterval';
  static const String kNextAlarmTime = 'nextAlarmTime';

  static bool _initialized = false;

  /// 初始化闹钟服务(主 isolate 中调用一次)
  static Future<void> init() async {
    if (_initialized) return;
    debugPrint('[AlarmService] 初始化 AndroidAlarmManager...');
    try {
      await AndroidAlarmManager.initialize();
      _initialized = true;
      debugPrint('[AlarmService] 初始化成功');
    } catch (e) {
      debugPrint('[AlarmService] 初始化失败: $e');
    }
  }

  /// 注册循环提醒(用 oneShotAt 实现,回调中自动重新注册下一次)
  /// [intervalMinutes] 间隔分钟数
  static Future<bool> scheduleLoop(int intervalMinutes) async {
    await cancelLoop();
    if (intervalMinutes <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kLoopInterval, intervalMinutes);
    // 计算下次提醒的绝对时间
    final nextTime = DateTime.now().add(Duration(minutes: intervalMinutes));
    await prefs.setString(kNextAlarmTime, nextTime.toIso8601String());
    return _scheduleNextLoopAt(nextTime);
  }

  /// 在指定绝对时间注册下一次循环闹钟(更可靠,不受 Duration 计算偏差影响)
  static Future<bool> _scheduleNextLoopAt(DateTime time) async {
    debugPrint('[AlarmService] 注册循环闹钟: $time');
    try {
      final ok = await AndroidAlarmManager.oneShotAt(
        time,
        loopAlarmId,
        loopAlarmCallback,
        rescheduleOnReboot: true,
        wakeup: true,
        exact: true,
        allowWhileIdle: true,
      );
      debugPrint('[AlarmService] 循环闹钟注册结果: $ok');
      return ok;
    } catch (e) {
      debugPrint('[AlarmService] 循环闹钟注册异常: $e');
      return false;
    }
  }

  /// 从 SharedPreferences 读取间隔并重新注册下一次循环闹钟
  /// 供回调函数在执行完提醒后调用,确保循环不中断
  static Future<void> rescheduleLoop() async {
    final prefs = await SharedPreferences.getInstance();
    final interval = prefs.getInt(kLoopInterval) ?? 0;
    if (interval > 0) {
      final nextTime = DateTime.now().add(Duration(minutes: interval));
      await prefs.setString(kNextAlarmTime, nextTime.toIso8601String());
      await _scheduleNextLoopAt(nextTime);
    }
  }

  /// App 回前台时检查闹钟是否漏触发
  /// 如果下次提醒时间已过但闹钟没响,补发提醒并重新注册
  /// 返回 true 表示补发了提醒
  static Future<bool> checkAndFireMissedAlarm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final interval = prefs.getInt(kLoopInterval) ?? 0;
      if (interval <= 0) return false;

      // 检查是否启用了提醒
      final enabled = prefs.getBool('reminderEnabled') ?? true;
      final paused = prefs.getBool('reminderPaused') ?? false;
      if (!enabled || paused) return false;

      final nextStr = prefs.getString(kNextAlarmTime);
      if (nextStr == null) {
        // 没有记录下次提醒时间,重新注册
        debugPrint('[AlarmService] 无下次提醒时间记录,重新注册');
        await rescheduleLoop();
        return false;
      }

      final nextTime = DateTime.tryParse(nextStr);
      if (nextTime == null) {
        await rescheduleLoop();
        return false;
      }

      final now = DateTime.now();
      if (now.isAfter(nextTime)) {
        // 闹钟时间已过,说明漏触发了
        debugPrint('[AlarmService] 检测到漏触发提醒: 应于 $nextTime 触发,当前 $now');
        // 补发提醒
        await NotificationService.onAlarmFired(loopAlarmId);
        // 重新注册下一次
        await rescheduleLoop();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AlarmService] 检查漏触发异常: $e');
      return false;
    }
  }

  /// 取消循环提醒
  static Future<void> cancelLoop() async {
    await AndroidAlarmManager.cancel(loopAlarmId);
  }

  /// 注册单次提醒
  static Future<void> scheduleSingle(int alarmId, DateTime time) async {
    await AndroidAlarmManager.cancel(alarmId);
    await AndroidAlarmManager.oneShotAt(
      time,
      alarmId,
      singleAlarmCallback,
      rescheduleOnReboot: true,
      wakeup: true,
    );
  }

  /// 取消单个单次提醒
  static Future<void> cancelSingle(int alarmId) async {
    await AndroidAlarmManager.cancel(alarmId);
  }

  /// 测试提醒:5秒后触发一次闹钟,用于验证闘钟机制是否正常
  /// 返回 true 表示注册成功
  static Future<bool> scheduleTest() async {
    debugPrint('[AlarmService] 注册测试闹钟: 5秒后触发');
    try {
      final ok = await AndroidAlarmManager.oneShot(
        const Duration(seconds: 5),
        999,
        testAlarmCallback,
        wakeup: true,
        exact: true,
        allowWhileIdle: true,
      );
      debugPrint('[AlarmService] 测试闹钟注册结果: $ok');
      return ok;
    } catch (e) {
      debugPrint('[AlarmService] 测试闹钟注册异常: $e');
      return false;
    }
  }

  /// 取消所有提醒
  static Future<void> cancelAll(List<int> singleIds) async {
    await cancelLoop();
    for (final id in singleIds) {
      await AndroidAlarmManager.cancel(id);
    }
  }
}

/// 循环提醒的顶层回调函数(必须为 public 顶层函数,带 vm:entry-point 注解)
@pragma('vm:entry-point')
void loopAlarmCallback(int id, Map<String, dynamic>? params) async {
  debugPrint('[AlarmCallback] 循环闹钟回调触发, id=$id, time=${DateTime.now()}');
  // 执行提醒逻辑(通知+音效+飞书),用 try-finally 确保无论是否异常都重新注册下一次
  try {
    await NotificationService.onAlarmFired(id);
  } catch (e) {
    debugPrint('[AlarmCallback] onAlarmFired 异常: $e');
  } finally {
    // 无论是否执行提醒(可能被免打扰拦截或异常),都重新注册下一次,确保循环不中断
    await AlarmService.rescheduleLoop();
    debugPrint('[AlarmCallback] 已重新注册下一次闹钟');
  }
}

/// 单次提醒的顶层回调函数
@pragma('vm:entry-point')
void singleAlarmCallback(int id, Map<String, dynamic>? params) async {
  debugPrint('[AlarmCallback] 单次闹钟回调触发, id=$id');
  await NotificationService.onAlarmFired(id);
}

/// 测试提醒的顶层回调函数(跳过时段/免打扰检查,直接执行提醒)
@pragma('vm:entry-point')
void testAlarmCallback(int id, Map<String, dynamic>? params) async {
  debugPrint('[AlarmCallback] 测试闹钟回调触发, id=$id');
  await NotificationService.onTestAlarmFired();
}
