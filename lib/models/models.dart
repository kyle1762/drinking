/// 账号三态
enum AccountState {
  /// 游客模式
  guest,

  /// 已登录未绑飞书
  loggedIn,

  /// 已登录+绑定飞书
  boundFeishu,
}

/// 提醒音效
/// 风铃音效已更换为 wind_chime.wav(更清脆悦耳)
/// 请将新的风铃音频文件放入 assets/sounds/wind_chime.wav
enum SoundType {
  flow('流水', 'flow.wav'),
  windChime('风铃', 'wind_chime.wav'),
  rainDrop('雨滴', 'rain.wav'),
  piano('轻钢琴', 'piano.wav');

  const SoundType(this.label, this.file);
  final String label;
  final String file;

  /// 从名称解析音效枚举(持久化反序列化用)
  static SoundType fromName(String? name) {
    return SoundType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SoundType.flow,
    );
  }
}

/// 重复周期
enum RepeatCycle { daily, weekday, weekend }

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

/// 用户资料 - 全局参数
class UserProfile {
  const UserProfile({
    this.nickname = '',
    this.defaultCup = 250,
    this.dailyGoal = 2000,
    this.wakeTime = '08:00',
    this.bedTime = '21:00',
  });

  final String nickname;
  final int defaultCup; // 默认水杯容量 ml
  final int dailyGoal; // 每日目标 ml
  final String wakeTime; // 作息-起床
  final String bedTime; // 作息-睡觉

  UserProfile copyWith({
    String? nickname,
    int? defaultCup,
    int? dailyGoal,
    String? wakeTime,
    String? bedTime,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      defaultCup: defaultCup ?? this.defaultCup,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      wakeTime: wakeTime ?? this.wakeTime,
      bedTime: bedTime ?? this.bedTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'defaultCup': defaultCup,
        'dailyGoal': dailyGoal,
        'wakeTime': wakeTime,
        'bedTime': bedTime,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      nickname: (json['nickname'] as String?) ?? '',
      defaultCup: (json['defaultCup'] as num?)?.toInt() ?? 250,
      dailyGoal: (json['dailyGoal'] as num?)?.toInt() ?? 2000,
      wakeTime: (json['wakeTime'] as String?) ?? '08:00',
      bedTime: (json['bedTime'] as String?) ?? '21:00',
    );
  }
}

/// AI 识别类型
enum AiRecognitionType { food, exercise }

/// AI 识别结果(由 AI 接口返回)
class AiRecognitionResult {
  final AiRecognitionType type;
  final String name;
  final double value; // 食物: kcal/100g; 运动: kcal/次
  final double confidence; // 0~1 信心度
  final String? imagePath; // 本地图片路径

  const AiRecognitionResult({
    required this.type,
    required this.name,
    required this.value,
    required this.confidence,
    this.imagePath,
  });
}

/// 饮食记录
class FoodRecord {
  final String id;
  final DateTime time;
  final String name;
  final int calories; // 总热量 kcal
  final int grams; // 克数
  final String? imagePath;

  FoodRecord({
    required this.id,
    required this.time,
    required this.name,
    required this.calories,
    required this.grams,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time.toIso8601String(),
        'name': name,
        'calories': calories,
        'grams': grams,
        'imagePath': imagePath,
      };

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    return FoodRecord(
      id: json['id'] as String,
      time: DateTime.parse(json['time'] as String),
      name: json['name'] as String,
      calories: (json['calories'] as num).toInt(),
      grams: (json['grams'] as num).toInt(),
      imagePath: json['imagePath'] as String?,
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
