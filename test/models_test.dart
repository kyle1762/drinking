import 'package:flutter_test/flutter_test.dart';
import 'package:drinking/models/models.dart';
import 'package:drinking/data/diet_methods.dart';

void main() {
  group('UserProfile BMI', () {
    test('正确计算 BMI(kg/m^2)', () {
      const p = UserProfile(
          gender: Gender.male, age: 30, height: 175, weight: 70);
      expect(p.bmi, closeTo(70 / (1.75 * 1.75), 0.0001));
      expect(p.bmi, closeTo(22.8571, 0.001));
    });

    test('身高或体重为 0 时 BMI 返回 null', () {
      const p = UserProfile(height: 0, weight: 70);
      const q = UserProfile(height: 175, weight: 0);
      expect(p.bmi, isNull);
      expect(q.bmi, isNull);
    });
  });

  group('UserProfile BMR', () {
    test('男性 Mifflin-St Jeor 公式', () {
      const p = UserProfile(
          gender: Gender.male, age: 30, height: 175, weight: 70);
      // 700 + 6.25*175 - 5*30 + 5 = 1648.75 -> 1649
      expect(p.bmr, 1649);
    });

    test('女性 Mifflin-St Jeor 公式', () {
      const p = UserProfile(
          gender: Gender.female, age: 30, height: 175, weight: 70);
      // 700 + 1093.75 - 150 - 161 = 1482.75 -> 1483
      expect(p.bmr, 1483);
    });

    test('性别未指定时 BMR 返回 null', () {
      const p = UserProfile(height: 175, weight: 70, age: 30);
      expect(p.bmr, isNull);
    });

    test('信息不全时 BMR 返回 null', () {
      const p = UserProfile(gender: Gender.male, age: 30, weight: 70);
      expect(p.bmr, isNull);
    });

    test('填写肌肉量时优先使用 Katch-McArdle 公式', () {
      const p = UserProfile(muscle: 60, weight: 70);
      // 370 + 21.6 * 60 = 1666
      expect(p.bmr, 1666);
    });
  });

  group('UserProfile 其他派生属性', () {
    test('minIntake 按性别区分', () {
      expect(const UserProfile(gender: Gender.male).minIntake, 1500);
      expect(const UserProfile(gender: Gender.female).minIntake, 1200);
      expect(const UserProfile().minIntake, 1200);
    });

    test('profileComplete 需性别+年龄+身高+体重齐全', () {
      const full = UserProfile(
          gender: Gender.female, age: 25, height: 160, weight: 55);
      expect(full.profileComplete, isTrue);
      expect(const UserProfile(gender: Gender.female, age: 25, height: 160)
          .profileComplete, isFalse);
      expect(const UserProfile().profileComplete, isFalse);
    });
  });

  group('UserProfile 序列化', () {
    test('toJson/fromJson 往返一致', () {
      const original = UserProfile(
        nickname: '小水',
        defaultCup: 300,
        dailyGoal: 2500,
        wakeTime: '07:30',
        bedTime: '23:00',
        gender: Gender.female,
        age: 28,
        height: 165,
        weight: 52,
        muscle: 40,
        goal: UserGoal.loseFat,
        targetWeight: 48,
        dietMethodId: 'keto',
        imagePath: '/tmp/a.png',
      );
      final restored = UserProfile.fromJson(original.toJson());
      expect(restored.nickname, original.nickname);
      expect(restored.gender, original.gender);
      expect(restored.goal, original.goal);
      expect(restored.muscle, original.muscle);
      expect(restored.targetWeight, original.targetWeight);
      expect(restored.dietMethodId, original.dietMethodId);
      expect(restored.imagePath, original.imagePath);
    });

    test('缺省字段回退到默认值且越界枚举被 clamp', () {
      final p = UserProfile.fromJson(<String, dynamic>{
        'gender': 99, // 越界 -> clamp 到最后一个枚举(unspecified)
        'goal': -5, // 越界 -> clamp 到 maintain
      });
      expect(p.gender, Gender.unspecified);
      expect(p.goal, UserGoal.maintain);
      expect(p.nickname, '');
      expect(p.defaultCup, 250);
      expect(p.dailyGoal, 2000);
    });
  });

  group('模型 JSON 往返', () {
    test('WaterRecord 往返', () {
      final r = WaterRecord(
          id: 'w1', time: DateTime(2026, 8, 3, 10, 30), amount: 250);
      final back = WaterRecord.fromJson(r.toJson());
      expect(back.id, r.id);
      expect(back.amount, r.amount);
      expect(back.time, r.time);
    });

    test('FoodRecord 往返含营养字段', () {
      final r = FoodRecord(
          id: 'f1',
          time: DateTime(2026, 8, 3),
          name: '番茄炒蛋',
          calories: 320,
          grams: 200,
          protein: 12.5,
          fat: 18,
          carbs: 8,
          fiber: 2.1);
      final back = FoodRecord.fromJson(r.toJson());
      expect(back.name, r.name);
      expect(back.protein, r.protein);
      expect(back.fiber, r.fiber);
      expect(back.calories, r.calories);
    });

    test('ExerciseRecord 往返并兼容旧 minutes 字段', () {
      final r = ExerciseRecord(
          id: 'e1', time: DateTime(2026, 8, 3), name: '跑步', calories: 200, reps: 1);
      final back = ExerciseRecord.fromJson(r.toJson());
      expect(back.name, r.name);
      expect(back.reps, 1);

      final legacy = ExerciseRecord.fromJson(<String, dynamic>{
        'id': 'e2',
        'time': r.time.toIso8601String(),
        'name': '瑜伽',
        'calories': 120,
        'minutes': 30,
      });
      expect(legacy.reps, 30);
    });

    test('WeeklyRecord 往返', () {
      final r = WeeklyRecord(
          id: 'wk1', date: DateTime(2026, 8, 2), bmi: 22.5, weeklyBurnCalories: 3500);
      final back = WeeklyRecord.fromJson(r.toJson());
      expect(back.bmi, r.bmi);
      expect(back.weeklyBurnCalories, r.weeklyBurnCalories);
    });

    test('SingleReminder 往返与过期判断', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(minutes: 1));
      final future = now.add(const Duration(minutes: 1));
      final r = SingleReminder(id: 's1', time: future, label: '喝水');
      final back = SingleReminder.fromJson(r.toJson());
      expect(back.id, 's1');
      expect(back.label, '喝水');
      expect(SingleReminder(id: 'x', time: past).isExpired, isTrue);
      expect(r.isExpired, isFalse);
    });

    test('CalendarEventRef 与 AlarmTimeRecord 往返', () {
      final c = CalendarEventRef(
          calendarId: 'cal1',
          eventId: 'evt1',
          title: '动一动',
          startTime: DateTime(2026, 8, 3, 9));
      final cBack = CalendarEventRef.fromJson(c.toJson());
      expect(cBack.eventId, 'evt1');

      const a = AlarmTimeRecord(hour: 9, minute: 30, label: '早上');
      final aBack = AlarmTimeRecord.fromJson(a.toJson());
      expect(aBack.timeStr, '09:30');
    });

    test('DailyDietSummary 往返', () {
      final s = DailyDietSummary(
          date: DateTime(2026, 8, 3),
          calories: 1800,
          exerciseCalories: 300,
          protein: 90,
          fat: 60,
          carbs: 180,
          fiber: 25,
          foodNames: ['米饭', '鸡胸肉']);
      final back = DailyDietSummary.fromJson(s.toJson());
      expect(back.foodNames, ['米饭', '鸡胸肉']);
      expect(back.calories, 1800);
    });
  });

  group('DietAdvice', () {
    DietAdvice make(DateTime validUntil) => DietAdvice(
          createdAt: DateTime(2026, 8, 3),
          goal: UserGoal.loseFat,
          eatMore: const ['蔬菜'],
          eatLess: const ['甜食'],
          summary: '多摄入纤维',
          suggestedCalories: 1500,
          suggestedProtein: 90,
          suggestedFat: 50,
          suggestedCarbs: 150,
          suggestedFiber: 30,
          validUntil: validUntil,
        );

    test('isValid 与有效期相关', () {
      final now = DateTime.now();
      expect(make(now.add(const Duration(days: 1))).isValid, isTrue);
      expect(make(now.subtract(const Duration(days: 1))).isValid, isFalse);
    });

    test('toJson/fromJson 往返', () {
      final a = make(DateTime(2026, 8, 6));
      final back = DietAdvice.fromJson(a.toJson());
      expect(back.goal, UserGoal.loseFat);
      expect(back.suggestedFiber, 30);
      expect(back.validUntil, a.validUntil);
    });
  });

  group('DietMethods', () {
    test('findById 命中预设并返回 null', () {
      expect(DietMethods.findById('keto')!.name, '生酮饮食');
      expect(DietMethods.findById('mediterranean'), isNotNull);
      expect(DietMethods.findById('not_exist'), isNull);
    });

    test('预设 id 唯一', () {
      final ids = DietMethods.all.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('增肌方案:目标为增肌时返回增肌方案', () {
      expect(DietMethods.allFor(UserGoal.gainMuscle).length, greaterThan(0));
      expect(DietMethods.allFor(UserGoal.gainMuscle).first.id,
          startsWith('gain_'));
      // 非增肌目标返回减肥方法
      expect(DietMethods.allFor(UserGoal.loseFat).first.id, 'keto');
      expect(DietMethods.findByIdFor(UserGoal.gainMuscle, 'keto'), isNull);
      expect(
          DietMethods.findByIdFor(UserGoal.gainMuscle, 'gain_high_protein'),
          isNotNull);
      // 增肌方案 id 不与减肥方法冲突
      final allIds = {...DietMethods.all.map((m) => m.id).toSet()};
      allIds.addAll(DietMethods.muscleGain.map((m) => m.id));
      expect(allIds.length,
          DietMethods.all.length + DietMethods.muscleGain.length);
    });

    test('classify 按推荐/避免/其余返回状态', () {
      final keto = DietMethods.findById('keto')!;
      // 避免吃:米饭(糖类/薯类不适用,但"含糖饮料""糕点"等)
      expect(DietMethods.classify('白米饭', keto), DietFoodStatus.forbidden);
      expect(DietMethods.classify('可乐', keto), DietFoodStatus.forbidden);
      expect(DietMethods.classify('蛋挞', keto), DietFoodStatus.forbidden);
      // 推荐吃:蛋类/肉类/鱼类/坚果/牛油果
      expect(DietMethods.classify('鸡蛋', keto), DietFoodStatus.allowed);
      expect(DietMethods.classify('鸡胸肉', keto), DietFoodStatus.allowed);
      expect(DietMethods.classify('牛油果', keto), DietFoodStatus.allowed);
      expect(DietMethods.classify('腰果', keto), DietFoodStatus.allowed);
      // 无方案 -> 中性
      expect(DietMethods.classify('鸡蛋', null), DietFoodStatus.neutral);
      // 无关食材 -> 中性
      expect(DietMethods.classify('海带', keto), DietFoodStatus.neutral);
    });

    test('classify 支持类别词模糊匹配且避免误伤', () {
      final med = DietMethods.findById('mediterranean')!;
      // 红肉:牛肉/猪肉被避免;牛油果不被误判为红肉
      expect(DietMethods.classify('牛肉', med), DietFoodStatus.forbidden);
      expect(DietMethods.classify('牛油果', med), DietFoodStatus.allowed);
      // 加工食品:火腿被避免
      expect(DietMethods.classify('火腿', med), DietFoodStatus.forbidden);
      // 全谷物:糙米不被误判为精制米面(低碳水方案)
      final lowCarb = DietMethods.findById('low_carb')!;
      expect(
          DietMethods.classify('糙米饭', lowCarb), DietFoodStatus.allowed);
      expect(DietMethods.classify('白米饭', lowCarb), DietFoodStatus.forbidden);
    });
  });
}