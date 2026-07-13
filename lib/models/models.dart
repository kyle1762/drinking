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
