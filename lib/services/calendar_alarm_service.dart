import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../models/models.dart';

/// 日历 & 闹钟批量服务
/// - 日历: 通过 device_calendar 批量创建/删除日历事件(支持每日重复)
/// - 闹钟: 通过 android_intent_plus ACTION_SET_ALARM 添加系统闹钟
/// - 一键清除: 日历事件可程序化删除; 闹钟需用户手动删除(打开时钟App引导)
class CalendarAlarmService {
  CalendarAlarmService._();

  static final _deviceCalendar = DeviceCalendarPlugin();

  // ============ 提醒时间生成 ============

  /// 根据作息时间和间隔,生成今日提醒时间列表
  /// [wakeTime] 起床时间 "HH:mm"
  /// [bedTime] 睡觉时间 "HH:mm"
  /// [intervalMinutes] 间隔分钟
  /// [skipPast] 是否跳过已过去的时间(默认 true,用于闹钟;日历设为 false 因为每日重复)
  /// 返回今日的 DateTime 列表
  static List<DateTime> generateReminderTimes({
    required String wakeTime,
    required String bedTime,
    required int intervalMinutes,
    bool skipPast = true,
  }) {
    final now = DateTime.now();
    final wake = _parseTime(now, wakeTime);
    var bed = _parseTime(now, bedTime);
    // 如果睡觉时间在起床时间之前(跨天),加一天
    if (!bed.isAfter(wake)) {
      bed = bed.add(const Duration(days: 1));
    }

    final times = <DateTime>[];
    var current = wake;
    while (current.isBefore(bed)) {
      // skipPast=true 时只添加今天还没过去的时间(用于闹钟)
      // skipPast=false 时添加所有时间点(用于日历,因为每日重复)
      if (!skipPast || current.isAfter(now)) {
        times.add(current);
      }
      current = current.add(Duration(minutes: intervalMinutes));
    }
    return times;
  }

  static DateTime _parseTime(DateTime base, String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return DateTime(base.year, base.month, base.day, 8);
    final h = int.tryParse(parts[0]) ?? 8;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateTime(base.year, base.month, base.day, h, m);
  }

  // ============ 日历操作 ============

  /// 检查日历权限
  static Future<bool> hasCalendarPermission() async {
    try {
      final result = await _deviceCalendar.hasPermissions();
      return result.isSuccess && result.data == true;
    } catch (e) {
      debugPrint('[CalendarAlarm] 检查日历权限失败: $e');
      return false;
    }
  }

  /// 请求日历权限
  static Future<bool> requestCalendarPermission() async {
    try {
      final result = await _deviceCalendar.requestPermissions();
      return result.isSuccess && result.data == true;
    } catch (e) {
      debugPrint('[CalendarAlarm] 请求日历权限失败: $e');
      return false;
    }
  }

  /// 批量添加日历事件
  /// 为每个时间点创建一个每日重复的日历事件,带 0 分钟提醒
  /// 返回创建成功的事件引用列表(供一键清除使用)
  static Future<List<CalendarEventRef>> batchAddCalendarEvents({
    required String title,
    required List<DateTime> times,
    String description = '该喝水啦~ 起身动动,接杯水喝一口吧',
  }) async {
    final refs = <CalendarEventRef>[];

    // 确保有权限
    if (!await hasCalendarPermission()) {
      final granted = await requestCalendarPermission();
      if (!granted) {
        debugPrint('[CalendarAlarm] 日历权限被拒绝');
        return refs;
      }
    }

    // 获取可写日历
    final calendarsResult = await _deviceCalendar.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data == null) {
      debugPrint('[CalendarAlarm] 获取日历列表失败');
      return refs;
    }

    final writableCalendars = calendarsResult.data!
        .where((c) =>
            c.isReadOnly != true &&
            c.id != null &&
            c.id!.isNotEmpty)
        .toList();
    if (writableCalendars.isEmpty) {
      debugPrint('[CalendarAlarm] 没有可写的日历');
      return refs;
    }

    // 使用第一个可写日历(通常是主账户的日历)
    final calendarId = writableCalendars.first.id!;

    // 批量创建事件
    for (final time in times) {
      try {
        final event = Event(calendarId);
        event.title = title;
        event.description = description;
        // 使用 UTC 时区创建 TZDateTime(绝对时间正确,日历App会自动转换为本地时间显示)
        event.start = TZDateTime.from(time, UTC);
        event.end = TZDateTime.from(
            time.add(const Duration(minutes: 15)), UTC);
        event.reminders = [Reminder(minutes: 0)]; // 事件开始时提醒
        // 设置每日重复
        event.recurrenceRule = RecurrenceRule(RecurrenceFrequency.Daily);

        final result = await _deviceCalendar.createOrUpdateEvent(event);
        if (result != null &&
            result.isSuccess &&
            result.data != null &&
            result.data!.isNotEmpty) {
          refs.add(CalendarEventRef(
            calendarId: calendarId,
            eventId: result.data!,
            title: title,
            startTime: time,
          ));
          debugPrint('[CalendarAlarm] 日历事件已创建: ${time.hour}:${time.minute} -> ${result.data}');
        } else {
          final errs = result?.errors ?? [];
          debugPrint('[CalendarAlarm] 日历事件创建失败: $errs');
        }
      } catch (e) {
        debugPrint('[CalendarAlarm] 创建日历事件异常: $e');
      }
    }

    return refs;
  }

  /// 批量删除日历事件(一键清除)
  /// 返回成功删除的数量
  static Future<int> clearCalendarEvents(List<CalendarEventRef> refs) async {
    if (refs.isEmpty) return 0;

    int deletedCount = 0;
    for (final ref in refs) {
      try {
        final result = await _deviceCalendar.deleteEvent(
            ref.calendarId, ref.eventId);
        if (result.isSuccess) {
          deletedCount++;
        } else {
          debugPrint('[CalendarAlarm] 删除日历事件失败: ${ref.eventId} -> ${result.errors}');
        }
      } catch (e) {
        debugPrint('[CalendarAlarm] 删除日历事件异常: $e');
      }
    }
    return deletedCount;
  }

  // ============ 闹钟操作 ============

  /// 添加单个系统闹钟(通过 ACTION_SET_ALARM intent)
  /// 注意:Android 不允许第三方App程序化删除其他App设置的闹钟
  /// 用户需要在时钟App中手动删除
  static Future<bool> setAlarm({
    required int hour,
    required int minute,
    String label = '喝水提醒',
  }) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: {
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          'android.intent.extra.alarm.MESSAGE': label,
          'android.intent.extra.alarm.SKIP_UI': false,
        },
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('[CalendarAlarm] 设置闹钟失败: $e');
      return false;
    }
  }

  /// 打开系统时钟App的闹钟列表(供用户手动删除闹钟)
  static Future<bool> openAlarmApp() async {
    try {
      const intent = AndroidIntent(
        action: 'android.intent.action.SHOW_ALARMS',
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('[CalendarAlarm] 打开时钟App失败: $e');
      // 退回:尝试打开时钟App主界面
      try {
        const intent = AndroidIntent(
          action: 'android.intent.action.SET_ALARM',
        );
        await intent.launch();
        return true;
      } catch (e2) {
        debugPrint('[CalendarAlarm] 打开时钟App(备用)失败: $e2');
        return false;
      }
    }
  }
}
