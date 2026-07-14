import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// 闹钟服务 - 基于 android_alarm_manager_plus
/// 使用 oneShot + 回调中重新注册的方式实现可靠循环
/// (Android 的 setRepeating 会被系统转为 inexact,无法保证精确触发)
class AlarmService {
  /// 循环提醒的固定闹钟 ID(0 保留给循环)
  static const int loopAlarmId = 0;

  /// 单次提醒 ID 的起始基数(避免与循环 ID 冲突)
  static const int singleAlarmBase = 1000;

  /// SharedPreferences 中存储循环间隔的 key
  static const String kLoopInterval = 'loopInterval';

  static bool _initialized = false;

  /// 初始化闹钟服务(主 isolate 中调用一次)
  static Future<void> init() async {
    if (_initialized) return;
    await AndroidAlarmManager.initialize();
    _initialized = true;
  }

  /// 注册循环提醒(用 oneShot 实现,回调中自动重新注册下一次)
  /// [intervalMinutes] 间隔分钟数
  static Future<void> scheduleLoop(int intervalMinutes) async {
    await cancelLoop();
    if (intervalMinutes <= 0) return;
    // 保存间隔到 SharedPreferences,供回调中重新注册时读取
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kLoopInterval, intervalMinutes);
    await _scheduleNextLoop(intervalMinutes);
  }

  /// 注册下一次循环闹钟
  static Future<void> _scheduleNextLoop(int intervalMinutes) async {
    await AndroidAlarmManager.oneShot(
      Duration(minutes: intervalMinutes),
      loopAlarmId,
      loopAlarmCallback,
      rescheduleOnReboot: true,
      wakeup: true,
      exact: true,
      allowWhileIdle: true,
    );
  }

  /// 从 SharedPreferences 读取间隔并重新注册下一次循环闹钟
  /// 供回调函数在执行完提醒后调用,确保循环不中断
  static Future<void> rescheduleLoop() async {
    final prefs = await SharedPreferences.getInstance();
    final interval = prefs.getInt(kLoopInterval) ?? 0;
    if (interval > 0) {
      await _scheduleNextLoop(interval);
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

  /// 测试提醒:5秒后触发一次闹钟,用于验证闹钟机制是否正常
  static Future<void> scheduleTest() async {
    await AndroidAlarmManager.oneShot(
      const Duration(seconds: 5),
      999,
      testAlarmCallback,
      wakeup: true,
      exact: true,
      allowWhileIdle: true,
    );
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
  // 执行提醒逻辑(通知+音效+飞书)
  await NotificationService.onAlarmFired(id);
  // 无论是否执行提醒(可能被免打扰拦截),都重新注册下一次,确保循环不中断
  await AlarmService.rescheduleLoop();
}

/// 单次提醒的顶层回调函数
@pragma('vm:entry-point')
void singleAlarmCallback(int id, Map<String, dynamic>? params) async {
  await NotificationService.onAlarmFired(id);
}

/// 测试提醒的顶层回调函数(跳过时段/免打扰检查,直接执行提醒)
@pragma('vm:entry-point')
void testAlarmCallback(int id, Map<String, dynamic>? params) async {
  await NotificationService.onTestAlarmFired();
}
