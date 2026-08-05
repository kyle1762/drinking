import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drinking/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  group('免打扰时段持久化', () {
    test('默认值:午休 12:30-14:30,夜间 22:00-08:00,自动同步关闭', () {
      final data = StorageService.loadAll();
      expect(data.noonDndStart, '12:30');
      expect(data.noonDndEnd, '14:30');
      expect(data.nightDndStart, '22:00');
      expect(data.nightDndEnd, '08:00');
      expect(data.calendarAutoSync, isFalse);
    });

    test('保存午休/夜间时段后 loadAll 读回一致', () async {
      await StorageService.saveNoonDndTime(start: '13:00', end: '15:00');
      await StorageService.saveNightDndTime(start: '21:30', end: '09:30');
      final data = StorageService.loadAll();
      expect(data.noonDndStart, '13:00');
      expect(data.noonDndEnd, '15:00');
      expect(data.nightDndStart, '21:30');
      expect(data.nightDndEnd, '09:30');
    });

    test('部分更新(只改开始时间)不覆盖结束时间', () async {
      await StorageService.saveNoonDndTime(start: '11:00');
      final data = StorageService.loadAll();
      expect(data.noonDndStart, '11:00');
      expect(data.noonDndEnd, '14:30');
    });

    test('日历自动同步开关持久化', () async {
      await StorageService.saveCalendarAutoSync(true);
      expect(StorageService.loadAll().calendarAutoSync, isTrue);
      await StorageService.saveCalendarAutoSync(false);
      expect(StorageService.loadAll().calendarAutoSync, isFalse);
    });
  });
}
