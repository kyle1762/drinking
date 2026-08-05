import 'package:flutter_test/flutter_test.dart';
import 'package:drinking/services/calendar_alarm_service.dart';

void main() {
  group('generateReminderTimes 0:00 对齐计时', () {
    test('60 分钟间隔、无免打扰 → 全天 24 个整点提醒', () {
      final times = CalendarAlarmService.generateReminderTimes(
        intervalMinutes: 60,
        noonDnd: false,
        nightDnd: false,
        skipPast: false,
      );
      expect(times.length, 24);
      expect(times.first.hour, 0);
      expect(times.first.minute, 0);
      expect(times.last.hour, 23);
      expect(times.last.minute, 0);
      for (var i = 0; i < times.length; i++) {
        expect(times[i].minute, 0, reason: '第 $i 个时间应为整点');
      }
    });

    test('90 分钟间隔从 0:00 起算,与开始编辑时刻无关', () {
      final times = CalendarAlarmService.generateReminderTimes(
        intervalMinutes: 90,
        noonDnd: false,
        nightDnd: false,
        skipPast: false,
      );
      expect(times.length, 16);
      expect(times.first, DateTime(times.first.year, times.first.month, times.first.day));
      final minutes = times.map((t) => t.hour * 60 + t.minute).toList();
      expect(minutes, [0, 90, 180, 270, 360, 450, 540, 630, 720, 810, 900, 990, 1080, 1170, 1260, 1350]);
    });

    test('间隔设为 30 分钟 → 48 个提醒', () {
      final times = CalendarAlarmService.generateReminderTimes(
        intervalMinutes: 30,
        noonDnd: false,
        nightDnd: false,
        skipPast: false,
      );
      expect(times.length, 48);
    });
  });

  group('generateReminderTimes 免打扰跳过', () {
    test('午休免打扰 12:30~14:30 跳过 13:00、14:00', () {
      final times = CalendarAlarmService.generateReminderTimes(
        intervalMinutes: 60,
        noonDnd: true,
        noonDndStart: '12:30',
        noonDndEnd: '14:30',
        nightDnd: false,
        skipPast: false,
      );
      expect(times.any((t) => t.hour == 13), isFalse);
      expect(times.any((t) => t.hour == 14), isFalse);
      expect(times.any((t) => t.hour == 12), isTrue);
      expect(times.any((t) => t.hour == 15), isTrue);
    });

    test('夜间免打扰 22:00~08:00 跨天跳过夜间时段', () {
      final times = CalendarAlarmService.generateReminderTimes(
        intervalMinutes: 60,
        noonDnd: false,
        nightDnd: true,
        nightDndStart: '22:00',
        nightDndEnd: '08:00',
        skipPast: false,
      );
      for (var h = 22; h <= 23; h++) {
        expect(times.any((t) => t.hour == h), isFalse, reason: '$h 点应在夜间免打扰内');
      }
      for (var h = 0; h <= 7; h++) {
        expect(times.any((t) => t.hour == h), isFalse, reason: '$h 点应在夜间免打扰内');
      }
      expect(times.any((t) => t.hour == 21), isTrue);
      expect(times.any((t) => t.hour == 8), isTrue);
    });

    test('午休+夜间均关闭 → 覆盖全天 0:00-24:00', () {
      final times = CalendarAlarmService.generateReminderTimes(
        intervalMinutes: 60,
        noonDnd: false,
        nightDnd: false,
        skipPast: false,
      );
      expect(times.length, 24);
    });
  });
}
