import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// 本地持久化服务 - 基于 SharedPreferences
/// 保存账号状态、用户配置、喝水记录、提醒任务等,App 重启不丢失
class StorageService {
  static SharedPreferences? _prefs;

  /// 在 main() 中调用,初始化 SharedPreferences 实例
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    if (_prefs == null) {
      throw StateError('StorageService 未初始化,请先调用 StorageService.init()');
    }
    return _prefs!;
  }

  // ============ Key 常量 ============
  static const _kAccountState = 'accountState';
  static const _kPhone = 'phone';
  static const _kFeishuName = 'feishuName';
  static const _kFeishuAppId = 'feishuAppId';
  static const _kFeishuAppSecret = 'feishuAppSecret';
  static const _kFeishuOpenId = 'feishuOpenId';
  static const _kProfile = 'profile';
  static const _kNotificationGranted = 'notificationGranted';
  static const _kReminderEnabled = 'reminderEnabled';
  static const _kIsLoopTab = 'isLoopTab';
  static const _kLoopInterval = 'loopInterval';
  static const _kSingleReminders = 'singleReminders';
  static const _kRangeStart = 'rangeStart';
  static const _kRangeEnd = 'rangeEnd';
  static const _kRepeat = 'repeat';
  static const _kEarphoneEnabled = 'earphoneEnabled';
  static const _kSound = 'sound';
  static const _kEarphoneVolume = 'earphoneVolume';
  static const _kFeishuPushEnabled = 'feishuPushEnabled';
  static const _kFeishuPushText = 'feishuPushText';
  static const _kFeishuPushOnReminder = 'feishuPushOnReminder';
  static const _kFeishuPushOnPunch = 'feishuPushOnPunch';
  static const _kNightDnd = 'nightDnd';
  static const _kNoonDnd = 'noonDnd';
  static const _kRememberSyncFeishu = 'rememberSyncFeishu';
  static const _kRecords = 'records';
  static const _kAiApiKey = 'aiApiKey';
  static const _kFoodRecords = 'foodRecords';
  static const _kExerciseRecords = 'exerciseRecords';
  // 扬声器提醒开关(新增,默认 true;兼容旧版 earphoneEnabled)
  static const _kSpeakerEnabled = 'speakerEnabled';
  static const _kLegacyEarphoneEnabled = 'earphoneEnabled';
  // 午休免打扰首启询问标记
  static const _kHasPromptedNoonDnd = 'hasPromptedNoonDnd';

  // ============ 加载全部 ============
  /// 从磁盘读取全部状态,返回一个 Map,供 AppState.bootstrap 使用
  static StoredData loadAll() {
    final p = _p;
    // 扬声器开关:优先读新 key,无则回退到旧 earphoneEnabled,默认 true
    final speaker = p.getBool(_kSpeakerEnabled) ??
        p.getBool(_kLegacyEarphoneEnabled) ??
        true;
    return StoredData(
      accountStateIndex: p.getInt(_kAccountState) ?? 0,
      phone: p.getString(_kPhone) ?? '',
      feishuName: p.getString(_kFeishuName) ?? '',
      feishuAppId: p.getString(_kFeishuAppId) ?? '',
      feishuAppSecret: p.getString(_kFeishuAppSecret) ?? '',
      feishuOpenId: p.getString(_kFeishuOpenId) ?? '',
      profile: _loadProfile(),
      notificationGranted: p.getBool(_kNotificationGranted) ?? false,
      reminderEnabled: p.getBool(_kReminderEnabled) ?? true,
      isLoopTab: p.getBool(_kIsLoopTab) ?? true,
      loopInterval: p.getInt(_kLoopInterval) ?? 60,
      singleReminders: _loadSingleReminders(),
      rangeStart: p.getString(_kRangeStart) ?? '08:00',
      rangeEnd: p.getString(_kRangeEnd) ?? '21:00',
      repeatIndex: p.getInt(_kRepeat) ?? 0,
      earphoneEnabled: p.getBool(_kEarphoneEnabled) ?? true,
      sound: SoundType.fromName(p.getString(_kSound)),
      earphoneVolume: p.getDouble(_kEarphoneVolume) ?? 0.6,
      feishuPushEnabled: p.getBool(_kFeishuPushEnabled) ?? false,
      feishuPushText: p.getString(_kFeishuPushText) ?? '到时间啦~ 起身动动,接杯水喝一口吧',
      feishuPushOnReminder: p.getBool(_kFeishuPushOnReminder) ?? true,
      feishuPushOnPunch: p.getBool(_kFeishuPushOnPunch) ?? false,
      nightDnd: p.getBool(_kNightDnd) ?? true,
      // 午休免打扰默认关闭,首启时主动询问用户
      noonDnd: p.getBool(_kNoonDnd) ?? false,
      hasPromptedNoonDnd: p.getBool(_kHasPromptedNoonDnd) ?? false,
      rememberSyncFeishu: p.getBool(_kRememberSyncFeishu) ?? true,
      records: _loadRecords(),
      aiApiKey: p.getString(_kAiApiKey) ?? '',
      foodRecords: _loadFoodRecords(),
      exerciseRecords: _loadExerciseRecords(),
      speakerEnabled: speaker,
    );
  }

  static UserProfile _loadProfile() {
    final s = _p.getString(_kProfile);
    if (s == null) return const UserProfile();
    try {
      return UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const UserProfile();
    }
  }

  static List<SingleReminder> _loadSingleReminders() {
    final s = _p.getString(_kSingleReminders);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => SingleReminder.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<WaterRecord> _loadRecords() {
    final s = _p.getString(_kRecords);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => WaterRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<FoodRecord> _loadFoodRecords() {
    final s = _p.getString(_kFoodRecords);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => FoodRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<ExerciseRecord> _loadExerciseRecords() {
    final s = _p.getString(_kExerciseRecords);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => ExerciseRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ============ 保存单项 ============
  static Future<void> saveAccountState(int index) =>
      _p.setInt(_kAccountState, index);
  static Future<void> savePhone(String v) => _p.setString(_kPhone, v);
  static Future<void> saveFeishuName(String v) => _p.setString(_kFeishuName, v);
  static Future<void> saveFeishuAppId(String v) =>
      _p.setString(_kFeishuAppId, v);
  static Future<void> saveFeishuAppSecret(String v) =>
      _p.setString(_kFeishuAppSecret, v);
  static Future<void> saveFeishuOpenId(String v) =>
      _p.setString(_kFeishuOpenId, v);
  static Future<void> saveProfile(UserProfile p) =>
      _p.setString(_kProfile, jsonEncode(p.toJson()));
  static Future<void> saveNotificationGranted(bool v) =>
      _p.setBool(_kNotificationGranted, v);
  static Future<void> saveReminderEnabled(bool v) =>
      _p.setBool(_kReminderEnabled, v);
  static Future<void> saveIsLoopTab(bool v) => _p.setBool(_kIsLoopTab, v);
  static Future<void> saveLoopInterval(int v) => _p.setInt(_kLoopInterval, v);
  static Future<void> saveSingleReminders(List<SingleReminder> list) =>
      _p.setString(
          _kSingleReminders, jsonEncode(list.map((e) => e.toJson()).toList()));
  static Future<void> saveRange(String start, String end) {
    _p.setString(_kRangeStart, start);
    return _p.setString(_kRangeEnd, end);
  }

  static Future<void> saveRepeat(int index) => _p.setInt(_kRepeat, index);
  static Future<void> saveEarphoneEnabled(bool v) =>
      _p.setBool(_kEarphoneEnabled, v);
  static Future<void> saveSound(String name) => _p.setString(_kSound, name);
  static Future<void> saveEarphoneVolume(double v) =>
      _p.setDouble(_kEarphoneVolume, v);
  static Future<void> saveFeishuPushEnabled(bool v) =>
      _p.setBool(_kFeishuPushEnabled, v);
  static Future<void> saveFeishuPushText(String v) =>
      _p.setString(_kFeishuPushText, v);
  static Future<void> saveFeishuPushFlags({bool? reminder, bool? punch}) {
    if (reminder != null) _p.setBool(_kFeishuPushOnReminder, reminder);
    if (punch != null) _p.setBool(_kFeishuPushOnPunch, punch);
    return Future.value();
  }

  static Future<void> saveNightDnd(bool v) => _p.setBool(_kNightDnd, v);
  static Future<void> saveNoonDnd(bool v) => _p.setBool(_kNoonDnd, v);
  static Future<void> saveHasPromptedNoonDnd(bool v) =>
      _p.setBool(_kHasPromptedNoonDnd, v);
  static Future<void> saveSpeakerEnabled(bool v) =>
      _p.setBool(_kSpeakerEnabled, v);
  static Future<void> saveRememberSyncFeishu(bool v) =>
      _p.setBool(_kRememberSyncFeishu, v);
  static Future<void> saveRecords(List<WaterRecord> list) =>
      _p.setString(_kRecords, jsonEncode(list.map((e) => e.toJson()).toList()));

  static Future<void> saveAiApiKey(String v) => _p.setString(_kAiApiKey, v);
  static Future<void> saveFoodRecords(List<FoodRecord> list) => _p.setString(
      _kFoodRecords, jsonEncode(list.map((e) => e.toJson()).toList()));
  static Future<void> saveExerciseRecords(List<ExerciseRecord> list) =>
      _p.setString(
          _kExerciseRecords, jsonEncode(list.map((e) => e.toJson()).toList()));

  /// 清空所有持久化数据(退出登录且不保留本地数据时调用)
  static Future<void> clearAll() async {
    final keys = [
      _kAccountState,
      _kPhone,
      _kFeishuName,
      _kFeishuAppId,
      _kFeishuAppSecret,
      _kFeishuOpenId,
      _kProfile,
      _kNotificationGranted,
      _kReminderEnabled,
      _kIsLoopTab,
      _kLoopInterval,
      _kSingleReminders,
      _kRangeStart,
      _kRangeEnd,
      _kRepeat,
      _kEarphoneEnabled,
      _kSound,
      _kEarphoneVolume,
      _kFeishuPushEnabled,
      _kFeishuPushText,
      _kFeishuPushOnReminder,
      _kFeishuPushOnPunch,
      _kNightDnd,
      _kNoonDnd,
      _kHasPromptedNoonDnd,
      _kRememberSyncFeishu,
      _kRecords,
      _kAiApiKey,
      _kFoodRecords,
      _kExerciseRecords,
      _kSpeakerEnabled,
      _kLegacyEarphoneEnabled,
    ];
    for (final k in keys) {
      await _p.remove(k);
    }
  }
}

/// 一次性加载出的全部持久化数据
class StoredData {
  final int accountStateIndex;
  final String phone;
  final String feishuName;
  final String feishuAppId;
  final String feishuAppSecret;
  final String feishuOpenId;
  final UserProfile profile;
  final bool notificationGranted;
  final bool reminderEnabled;
  final bool isLoopTab;
  final int loopInterval;
  final List<SingleReminder> singleReminders;
  final String rangeStart;
  final String rangeEnd;
  final int repeatIndex;
  final bool earphoneEnabled;
  final SoundType sound;
  final double earphoneVolume;
  final bool feishuPushEnabled;
  final String feishuPushText;
  final bool feishuPushOnReminder;
  final bool feishuPushOnPunch;
  final bool nightDnd;
  final bool noonDnd;
  final bool hasPromptedNoonDnd;
  final bool rememberSyncFeishu;
  final List<WaterRecord> records;
  final String aiApiKey;
  final List<FoodRecord> foodRecords;
  final List<ExerciseRecord> exerciseRecords;
  final bool speakerEnabled;

  const StoredData({
    required this.accountStateIndex,
    required this.phone,
    required this.feishuName,
    required this.feishuAppId,
    required this.feishuAppSecret,
    required this.feishuOpenId,
    required this.profile,
    required this.notificationGranted,
    required this.reminderEnabled,
    required this.isLoopTab,
    required this.loopInterval,
    required this.singleReminders,
    required this.rangeStart,
    required this.rangeEnd,
    required this.repeatIndex,
    required this.earphoneEnabled,
    required this.sound,
    required this.earphoneVolume,
    required this.feishuPushEnabled,
    required this.feishuPushText,
    required this.feishuPushOnReminder,
    required this.feishuPushOnPunch,
    required this.nightDnd,
    required this.noonDnd,
    required this.hasPromptedNoonDnd,
    required this.rememberSyncFeishu,
    required this.records,
    required this.aiApiKey,
    required this.foodRecords,
    required this.exerciseRecords,
    required this.speakerEnabled,
  });
}
