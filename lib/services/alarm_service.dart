import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'notification_service.dart';

/// 闹钟服务 - 基于 android_alarm_manager_plus
/// 负责注册循环提醒与单次提醒,支持息屏、重启后恢复
class AlarmService {
  /// 循环提醒的固定闹钟 ID(0 保留给循环)
  static const int loopAlarmId = 0;

  /// 单次提醒 ID 的起始基数(避免与循环 ID 冲突)
  static const int singleAlarmBase = 1000;

  static bool _initialized = false;

  /// 初始化闹钟服务(主 isolate 中调用一次)
  static Future<void> init() async {
    if (_initialized) return;
    await AndroidAlarmManager.initialize();
    _initialized = true;
  }

  /// 注册循环提醒
  /// [intervalMinutes] 间隔分钟数
  /// 内部会先取消旧的循环闹钟再注册新的
  /// 使用 exact + allowWhileIdle 确保息屏/低电量时也能准时触发
  static Future<void> scheduleLoop(int intervalMinutes) async {
    await cancelLoop();
    if (intervalMinutes <= 0) return;
    await AndroidAlarmManager.periodic(
      Duration(minutes: intervalMinutes),
      loopAlarmId,
      _loopAlarmCallback,
      rescheduleOnReboot: true,
      wakeup: true,
      exact: true,
      allowWhileIdle: true,
    );
  }

  /// 取消循环提醒
  static Future<void> cancelLoop() async {
    await AndroidAlarmManager.cancel(loopAlarmId);
  }

  /// 注册单次提醒
  /// [alarmId] 闹钟 ID(用于后续取消)
  /// [time] 触发时间
  static Future<void> scheduleSingle(int alarmId, DateTime time) async {
    await AndroidAlarmManager.cancel(alarmId);
    await AndroidAlarmManager.oneShotAt(
      time,
      alarmId,
      _singleAlarmCallback,
      rescheduleOnReboot: true,
      wakeup: true,
    );
  }

  /// 取消单个单次提醒
  static Future<void> cancelSingle(int alarmId) async {
    await AndroidAlarmManager.cancel(alarmId);
  }

  /// 取消所有提醒(循环 + 指定的单次 ID 列表)
  static Future<void> cancelAll(List<int> singleIds) async {
    await cancelLoop();
    for (final id in singleIds) {
      await AndroidAlarmManager.cancel(id);
    }
  }
}

/// 循环提醒的顶层回调函数(必须为顶层,带 vm:entry-point 注解)
/// 必须等待 onAlarmFired 完成(含飞书 HTTP 请求),否则后台 isolate 会提前结束导致飞书推送丢失
@pragma('vm:entry-point')
void _loopAlarmCallback(int id, Map<String, dynamic>? params) async {
  await NotificationService.onAlarmFired(id);
}

/// 单次提醒的顶层回调函数
@pragma('vm:entry-point')
void _singleAlarmCallback(int id, Map<String, dynamic>? params) async {
  await NotificationService.onAlarmFired(id);
}
