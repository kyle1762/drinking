import '../data/food_nutrition.dart';

/// 账号三态
enum AccountState {
  /// 游客模式
  guest,

  /// 已登录未绑飞书
  loggedIn,

  /// 已登录+绑定飞书
  boundFeishu,
}

/// 单次提醒任务
class SingleReminder {
  SingleReminder({
    required this.id,
    required this.time,
    this.label = '单次提醒',
  });

  final String id;
  final DateTime time;
  final String label;

  bool get isExpired => time.isBefore(DateTime.now());

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'label': label,
      };

  factory SingleReminder.fromJson(Map<String, dynamic> json) {
    return SingleReminder(
      id: json['id'] as String,
      time: DateTime.parse(json['time'] as String),
      label: (json['label'] as String?) ?? '单次提醒',
    );
  }
}

/// 喝水记录
class WaterRecord {
  WaterRecord({
    required this.id,
    required this.time,
    required this.amount,
  });

  final String id;
  final DateTime time;
  final int amount; // ml

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'amount': amount,
      };

  factory WaterRecord.fromJson(Map<String, dynamic> json) {
    return WaterRecord(
      id: json['id'] as String,
      time: DateTime.parse(json['time'] as String),
      amount: (json['amount'] as num).toInt(),
    );
  }
}

/// 性别
enum Gender { male, female, unspecified }

/// 用户目标(增肌/减脂/保持)
enum UserGoal {
  maintain, // 保持身材
  loseFat, // 减脂
  gainMuscle, // 增肌
}

/// 用户资料 - 全局参数
class UserProfile {
  const UserProfile({
    this.nickname = '',
    this.defaultCup = 250,
    this.dailyGoal = 2000,
    this.wakeTime = '08:00',
    this.bedTime = '21:00',
    this.gender = Gender.unspecified,
    this.age = 0,
    this.height = 0, // cm
    this.weight = 0, // kg
    this.muscle = 0, // 肌肉量 kg
    this.goal = UserGoal.maintain, // 用户目标
    this.targetWeight = 0, // 目标体重 kg
    this.dietMethodId = '', // 选择的减肥方法 id
    this.imagePath, // 个人形象图片路径(可选)
  });

  final String nickname;
  final int defaultCup; // 默认水杯容量 ml
  final int dailyGoal; // 每日目标 ml
  final String wakeTime; // 作息-起床
  final String bedTime; // 作息-睡觉
  final Gender gender;
  final int age;
  final int height;
  final int weight;
  final double muscle; // 肌肉量 kg
  final UserGoal goal; // 用户目标
  final int targetWeight; // 目标体重 kg
  final String dietMethodId; // 选择的减肥方法 id
  final String? imagePath; // 个人形象图片路径

  /// BMI = 体重(kg) / 身高(m)^2
  /// 身高/体重为 0 时返回 null
  double? get bmi {
    if (height <= 0 || weight <= 0) return null;
    final h = height / 100;
    return weight / (h * h);
  }

  /// 基础代谢量(BMR)
  /// 若填写了肌肉量,优先使用 Katch-McArdle 公式(更精准):
  ///   BMR = 370 + 21.6 * 瘦体重(kg)
  ///   瘦体重 = 体重 - 脂肪;此处用肌肉量近似瘦体重比例
  /// 否则使用 Mifflin-St Jeor 公式:
  ///   男性: 10*体重 + 6.25*身高 - 5*年龄 + 5
  ///   女性: 10*体重 + 6.25*身高 - 5*年龄 - 161
  /// 未填全信息时返回 null
  int? get bmr {
    // Katch-McArdle:若填写了肌肉量,用其近似瘦体重计算(更精准)
    if (weight > 0 && muscle > 0 && muscle < weight) {
      return (370 + 21.6 * muscle).round();
    }
    if (height <= 0 || weight <= 0 || age <= 0) return null;
    final base = 10 * weight + 6.25 * height - 5 * age;
    if (gender == Gender.male) return (base + 5).round();
    if (gender == Gender.female) return (base - 161).round();
    return null;
  }

  /// 最低摄入热量阈值(男性 1500 / 女性 1200 kcal)
  int get minIntake {
    if (gender == Gender.male) return 1500;
    if (gender == Gender.female) return 1200;
    return 1200; // 默认按较低值
  }

  /// 个人信息是否已填全(用于判断能否计算 BMR)
  bool get profileComplete =>
      gender != Gender.unspecified && age > 0 && height > 0 && weight > 0;

  UserProfile copyWith({
    String? nickname,
    int? defaultCup,
    int? dailyGoal,
    String? wakeTime,
    String? bedTime,
    Gender? gender,
    int? age,
    int? height,
    int? weight,
    double? muscle,
    UserGoal? goal,
    int? targetWeight,
    String? dietMethodId,
    Object? imagePath = _sentinel,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      defaultCup: defaultCup ?? this.defaultCup,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      wakeTime: wakeTime ?? this.wakeTime,
      bedTime: bedTime ?? this.bedTime,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      muscle: muscle ?? this.muscle,
      goal: goal ?? this.goal,
      targetWeight: targetWeight ?? this.targetWeight,
      dietMethodId: dietMethodId ?? this.dietMethodId,
      imagePath: identical(imagePath, _sentinel)
          ? this.imagePath
          : imagePath as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'defaultCup': defaultCup,
        'dailyGoal': dailyGoal,
        'wakeTime': wakeTime,
        'bedTime': bedTime,
        'gender': gender.index,
        'age': age,
        'height': height,
        'weight': weight,
        'muscle': muscle,
        'goal': goal.index,
        'targetWeight': targetWeight,
        'dietMethodId': dietMethodId,
        'imagePath': imagePath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      nickname: (json['nickname'] as String?) ?? '',
      defaultCup: (json['defaultCup'] as num?)?.toInt() ?? 250,
      dailyGoal: (json['dailyGoal'] as num?)?.toInt() ?? 2000,
      wakeTime: (json['wakeTime'] as String?) ?? '08:00',
      bedTime: (json['bedTime'] as String?) ?? '21:00',
      gender: Gender.values[((json['gender'] as num?)?.toInt() ?? 2)
          .clamp(0, Gender.values.length - 1)],
      age: (json['age'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
      muscle: (json['muscle'] as num?)?.toDouble() ?? 0,
      goal: UserGoal.values[((json['goal'] as num?)?.toInt() ?? 0)
          .clamp(0, UserGoal.values.length - 1)],
      targetWeight: (json['targetWeight'] as num?)?.toInt() ?? 0,
      dietMethodId: (json['dietMethodId'] as String?) ?? '',
      imagePath: json['imagePath'] as String?,
    );
  }
}

/// 哨兵值,用于区分 copyWith 中 imagePath 显式传 null 与未传
const Object _sentinel = Object();

/// AI 识别类型
enum AiRecognitionType { food, exercise }

/// AI 识别菜品中的单个食材(名称 + 占比%)
class FoodIngredient {
  final String name;
  final double ratio; // 0~1 占比

  const FoodIngredient({required this.name, required this.ratio});

  Map<String, dynamic> toJson() => {'name': name, 'ratio': ratio};

  factory FoodIngredient.fromJson(Map<String, dynamic> json) {
    return FoodIngredient(
      name: json['name'] as String? ?? '',
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// AI 识别结果(由 AI 接口返回)
/// 食物: ingredients 为识别出的菜品食材列表; value 统一为估算的总 kcal/100g(供展示)
///       若 fromLabel=true,表示来自预包装食品的营养成分表,labelNutrition 携带表上完整营养数据
/// 运动: value 为 kcal/次
class AiRecognitionResult {
  final AiRecognitionType type;
  final String name;
  final double value;
  final double confidence;
  final String? imagePath;
  final List<FoodIngredient> ingredients; // 仅食物类型使用
  final bool fromLabel; // 是否来自营养成分表(预包装食品)
  final FoodNutrition? labelNutrition; // 来自营养成分表时的完整营养数据
  final double estimatedWeight; // 食物:AI 结合餐具估算的重量(g),0 表示未估算

  const AiRecognitionResult({
    required this.type,
    required this.name,
    required this.value,
    required this.confidence,
    this.imagePath,
    this.ingredients = const [],
    this.fromLabel = false,
    this.labelNutrition,
    this.estimatedWeight = 0,
  });
}

/// 饮食记录
/// 扩展:记录蛋白质/脂肪/碳水/膳食纤维(基于营养表计算)
class FoodRecord {
  final String id;
  final DateTime time;
  final String name;
  final int calories; // 总热量 kcal
  final int grams; // 克数
  final String? imagePath;
  final double protein; // g
  final double fat; // g
  final double carbs; // g
  final double fiber; // g
  final double forbiddenGrams; // 本次记录中「避免吃」食材的克数(用于红色摄入过多提醒)

  FoodRecord({
    required this.id,
    required this.time,
    required this.name,
    required this.calories,
    required this.grams,
    this.imagePath,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
    this.fiber = 0,
    this.forbiddenGrams = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'name': name,
        'calories': calories,
        'grams': grams,
        'imagePath': imagePath,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'fiber': fiber,
        'forbiddenGrams': forbiddenGrams,
      };

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    return FoodRecord(
      id: json['id'] as String,
      time: DateTime.parse(json['time'] as String),
      name: json['name'] as String,
      calories: (json['calories'] as num).toInt(),
      grams: (json['grams'] as num).toInt(),
      imagePath: json['imagePath'] as String?,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      forbiddenGrams: (json['forbiddenGrams'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 周记录(每周末记录一次 BMI 和本周消耗热量)
class WeeklyRecord {
  final String id;
  final DateTime date; // 记录日期(周末)
  final double? bmi; // 当日 BMI
  final int weeklyBurnCalories; // 本周累计消耗热量 kcal

  WeeklyRecord({
    required this.id,
    required this.date,
    required this.bmi,
    required this.weeklyBurnCalories,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'bmi': bmi,
        'weeklyBurnCalories': weeklyBurnCalories,
      };

  factory WeeklyRecord.fromJson(Map<String, dynamic> json) {
    return WeeklyRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      bmi: (json['bmi'] as num?)?.toDouble(),
      weeklyBurnCalories: (json['weeklyBurnCalories'] as num).toInt(),
    );
  }
}

/// 运动记录
class ExerciseRecord {
  final String id;
  final DateTime time;
  final String name;
  final int calories; // 总消耗 kcal
  final int reps; // 次数
  final String? imagePath;

  ExerciseRecord({
    required this.id,
    required this.time,
    required this.name,
    required this.calories,
    required this.reps,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'name': name,
        'calories': calories,
        'reps': reps,
        'imagePath': imagePath,
      };

  factory ExerciseRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseRecord(
      id: json['id'] as String,
      time: DateTime.parse(json['time'] as String),
      name: json['name'] as String,
      calories: (json['calories'] as num).toInt(),
      // 兼容旧数据:优先读 reps,无则回退到 minutes
      reps: (json['reps'] as num?)?.toInt() ??
          (json['minutes'] as num?)?.toInt() ??
          0,
      imagePath: json['imagePath'] as String?,
    );
  }
}

/// 日历事件引用(批量添加日历事件后,记录 calendarId + eventId 供一键清除)
class CalendarEventRef {
  final String calendarId;
  final String eventId;
  final String title;
  final DateTime startTime;

  const CalendarEventRef({
    required this.calendarId,
    required this.eventId,
    required this.title,
    required this.startTime,
  });

  Map<String, dynamic> toJson() => {
        'calendarId': calendarId,
        'eventId': eventId,
        'title': title,
        'startTime': startTime.toIso8601String(),
      };

  factory CalendarEventRef.fromJson(Map<String, dynamic> json) {
    return CalendarEventRef(
      calendarId: json['calendarId'] as String? ?? '',
      eventId: json['eventId'] as String? ?? '',
      title: json['title'] as String? ?? '动一动',
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : DateTime.now(),
    );
  }
}

/// 闹钟时间记录(批量添加闹钟后,记录时间供一键清除时提示用户)
class AlarmTimeRecord {
  final int hour;
  final int minute;
  final String label;

  const AlarmTimeRecord({
    required this.hour,
    required this.minute,
    this.label = '动一动',
  });

  String get timeStr =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'minute': minute,
        'label': label,
      };

  factory AlarmTimeRecord.fromJson(Map<String, dynamic> json) {
    return AlarmTimeRecord(
      hour: (json['hour'] as num?)?.toInt() ?? 0,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      label: (json['label'] as String?) ?? '动一动',
    );
  }
}

/// 每日饮食摘要(每日清空食物记录前保存,用于 AI 分析近期饮食结构)
class DailyDietSummary {
  final DateTime date;
  final int calories; // 当日摄入热量
  final int exerciseCalories; // 当日运动消耗热量
  final double protein;
  final double fat;
  final double carbs;
  final double fiber;
  final List<String> foodNames; // 当日吃过的食物名列表

  const DailyDietSummary({
    required this.date,
    required this.calories,
    required this.exerciseCalories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.fiber,
    required this.foodNames,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'calories': calories,
        'exerciseCalories': exerciseCalories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'fiber': fiber,
        'foodNames': foodNames,
      };

  factory DailyDietSummary.fromJson(Map<String, dynamic> json) {
    return DailyDietSummary(
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      exerciseCalories: (json['exerciseCalories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      foodNames: (json['foodNames'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// AI 饮食建议(基于近期饮食结构 + 用户目标生成)
/// 包含:多吃/少吃食物种类建议 + 每日建议摄入量(可被动态调整)
class DietAdvice {
  final DateTime createdAt;
  final UserGoal goal;
  final List<String> eatMore; // 建议多吃的食物种类
  final List<String> eatLess; // 建议少吃的食物种类
  final String summary; // 总结说明
  final int suggestedCalories;
  final double suggestedProtein;
  final double suggestedFat;
  final double suggestedCarbs;
  final double suggestedFiber;
  final DateTime validUntil; // 建议有效期(通常未来三天)

  const DietAdvice({
    required this.createdAt,
    required this.goal,
    required this.eatMore,
    required this.eatLess,
    required this.summary,
    required this.suggestedCalories,
    required this.suggestedProtein,
    required this.suggestedFat,
    required this.suggestedCarbs,
    required this.suggestedFiber,
    required this.validUntil,
  });

  /// 建议是否仍然有效
  bool get isValid => DateTime.now().isBefore(validUntil);

  Map<String, dynamic> toJson() => {
        'createdAt': createdAt.toIso8601String(),
        'goal': goal.index,
        'eatMore': eatMore,
        'eatLess': eatLess,
        'summary': summary,
        'suggestedCalories': suggestedCalories,
        'suggestedProtein': suggestedProtein,
        'suggestedFat': suggestedFat,
        'suggestedCarbs': suggestedCarbs,
        'suggestedFiber': suggestedFiber,
        'validUntil': validUntil.toIso8601String(),
      };

  factory DietAdvice.fromJson(Map<String, dynamic> json) {
    return DietAdvice(
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      goal: UserGoal.values[((json['goal'] as num?)?.toInt() ?? 0)
          .clamp(0, UserGoal.values.length - 1)],
      eatMore: (json['eatMore'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      eatLess: (json['eatLess'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      summary: (json['summary'] as String?) ?? '',
      suggestedCalories: (json['suggestedCalories'] as num?)?.toInt() ?? 0,
      suggestedProtein:
          (json['suggestedProtein'] as num?)?.toDouble() ?? 0,
      suggestedFat: (json['suggestedFat'] as num?)?.toDouble() ?? 0,
      suggestedCarbs: (json['suggestedCarbs'] as num?)?.toDouble() ?? 0,
      suggestedFiber: (json['suggestedFiber'] as num?)?.toDouble() ?? 0,
      validUntil: json['validUntil'] != null
          ? DateTime.parse(json['validUntil'] as String)
          : DateTime.now().add(const Duration(days: 3)),
    );
  }
}
