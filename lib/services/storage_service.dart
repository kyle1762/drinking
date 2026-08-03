import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../data/food_nutrition.dart';

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
  static const _kWeeklyRecords = 'weeklyRecords';
  static const _kLastFoodClearDate = 'lastFoodClearDate';
  static const _kCustomFoodNutrition = 'customFoodNutrition';
  // 扬声器提醒开关(新增,默认 true;兼容旧版 earphoneEnabled)
  static const _kSpeakerEnabled = 'speakerEnabled';
  static const _kLegacyEarphoneEnabled = 'earphoneEnabled';
  // 午休免打扰首启询问标记
  static const _kHasPromptedNoonDnd = 'hasPromptedNoonDnd';
  // 上次提醒更新个人信息的日期(每日首次进入热量追踪页提醒)
  static const _kLastProfileRemindDate = 'lastProfileRemindDate';
  // 日历事件追踪(批量添加后记录 eventId,供一键清除使用)
  static const _kCalendarEventIds = 'calendarEventIds';
  // 闹钟时间追踪(批量添加后记录时间,供一键清除提示)
  static const _kAlarmTimes = 'alarmTimes';
  // 每日饮食摘要历史(每日清空食物记录前保存,供 AI 分析近期饮食)
  static const _kDailyDietSummaries = 'dailyDietSummaries';
  // 当前 AI 饮食建议(含建议摄入量,可被动态调整)
  static const _kDietAdvice = 'dietAdvice';
  // 用户保存的菜品配方(菜名 -> 食材及占比列表,永久记录供下次直接使用)
  static const _kDishRecipes = 'dishRecipes';

  // ============ 菜品配方(永久保存的食材占比) ============

  /// 保存单个菜品配方(菜名 -> 食材列表),覆盖同名旧配方
  static Future<void> saveDishRecipe(String dishName, List<FoodIngredient> ingredients) async {
    final all = loadAllDishRecipes();
    all[dishName] = ingredients;
    await _p.setString(_kDishRecipes,
        jsonEncode(all.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()))));
  }

  /// 加载全部菜品配方
  static Map<String, List<FoodIngredient>> loadAllDishRecipes() {
    final s = _p.getString(_kDishRecipes);
    if (s == null) return {};
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
          k, (v as List).map((e) => FoodIngredient.fromJson(e as Map<String, dynamic>)).toList()));
    } catch (_) {
      return {};
    }
  }

  /// 查找指定菜名的配方(模糊匹配菜名),找不到返回 null
  static List<FoodIngredient>? lookupDishRecipe(String dishName) {
    final all = loadAllDishRecipes();
    // 精确匹配优先
    if (all.containsKey(dishName)) return all[dishName];
    // 去空格后匹配
    final trimmed = dishName.trim();
    if (all.containsKey(trimmed)) return all[trimmed];
    return null;
  }

  // 用户保存的运动单次热量(运动名 -> kcal/次,永久记录供下次直接使用)
  static const _kExerciseCalories = 'exerciseCalories';

  /// 保存单个运动的单次热量(运动名 -> kcal/次),覆盖同名旧记录
  static Future<void> saveExerciseCalorie(String name, double kcalPerRep) async {
    final all = loadAllExerciseCalories();
    all[name] = kcalPerRep;
    await _p.setString(_kExerciseCalories, jsonEncode(all));
  }

  /// 加载全部运动单次热量
  static Map<String, double> loadAllExerciseCalories() {
    final s = _p.getString(_kExerciseCalories);
    if (s == null) return {};
    try {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  /// 查找指定运动的单次热量,找不到返回 null
  static double? lookupExerciseCalorie(String name) {
    final all = loadAllExerciseCalories();
    if (all.containsKey(name)) return all[name];
    final trimmed = name.trim();
    if (all.containsKey(trimmed)) return all[trimmed];
    return null;
  }

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
      weeklyRecords: _loadWeeklyRecords(),
      lastFoodClearDate: p.getString(_kLastFoodClearDate) ?? '',
      speakerEnabled: speaker,
      dailyDietSummaries: loadDailyDietSummaries(),
      dietAdvice: loadDietAdvice(),
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

  static List<WeeklyRecord> _loadWeeklyRecords() {
    final s = _p.getString(_kWeeklyRecords);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => WeeklyRecord.fromJson(e as Map<String, dynamic>))
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

  /// 读取上次提醒更新个人信息的日期(yyyy-MM-dd)
  static String getLastProfileRemindDate() =>
      _p.getString(_kLastProfileRemindDate) ?? '';
  static Future<void> saveLastProfileRemindDate(String date) =>
      _p.setString(_kLastProfileRemindDate, date);

  /// 日历事件追踪记录读写(批量添加日历事件后,记录 eventId 供一键清除)
  static List<CalendarEventRef> loadCalendarEventIds() {
    final s = _p.getString(_kCalendarEventIds);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => CalendarEventRef.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCalendarEventIds(List<CalendarEventRef> list) =>
      _p.setString(_kCalendarEventIds,
          jsonEncode(list.map((e) => e.toJson()).toList()));

  /// 闹钟时间追踪记录读写(批量添加闹钟后,记录时间供一键清除提示)
  static List<AlarmTimeRecord> loadAlarmTimes() {
    final s = _p.getString(_kAlarmTimes);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => AlarmTimeRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAlarmTimes(List<AlarmTimeRecord> list) =>
      _p.setString(
          _kAlarmTimes, jsonEncode(list.map((e) => e.toJson()).toList()));

  /// 每日饮食摘要历史读写
  static List<DailyDietSummary> loadDailyDietSummaries() {
    final s = _p.getString(_kDailyDietSummaries);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => DailyDietSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveDailyDietSummaries(List<DailyDietSummary> list) =>
      _p.setString(_kDailyDietSummaries,
          jsonEncode(list.map((e) => e.toJson()).toList()));

  /// 当前 AI 饮食建议读写
  static DietAdvice? loadDietAdvice() {
    final s = _p.getString(_kDietAdvice);
    if (s == null) return null;
    try {
      return DietAdvice.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveDietAdvice(DietAdvice? advice) {
    if (advice == null) {
      return _p.remove(_kDietAdvice);
    }
    return _p.setString(_kDietAdvice, jsonEncode(advice.toJson()));
  }
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
  static Future<void> saveWeeklyRecords(List<WeeklyRecord> list) =>
      _p.setString(
          _kWeeklyRecords, jsonEncode(list.map((e) => e.toJson()).toList()));
  static Future<void> saveLastFoodClearDate(String date) =>
      _p.setString(_kLastFoodClearDate, date);

  /// 保存用户自定义食物营养表到本地
  static Future<void> saveCustomFoodNutrition() =>
      _p.setString(_kCustomFoodNutrition,
          jsonEncode(FoodNutritionDB.customToJsonList()));

  /// 加载用户自定义食物营养表(启动时调用)
  static void loadCustomFoodNutrition() {
    final s = _p.getString(_kCustomFoodNutrition);
    if (s == null) return;
    try {
      final list = jsonDecode(s) as List;
      FoodNutritionDB.loadCustomFromJson(list);
    } catch (_) {}
  }

  /// 导出食物营养数据库为 JSON 字符串(内置+自定义,自定义覆盖内置同名项)
  static String exportFoodNutritionJson() {
    return jsonEncode(FoodNutritionDB.exportAllToJson());
  }

  /// 导出食物营养数据库为 CSV 字符串
  /// 列:名称,能量(kcal/100g),蛋白质(g),脂肪(g),碳水(g),膳食纤维(g)
  static String exportFoodNutritionCsv() {
    final sb = StringBuffer();
    sb.writeln('名称,能量(kcal/100g),蛋白质(g),脂肪(g),碳水(g),膳食纤维(g)');
    for (final e in FoodNutritionDB.exportAllToJson()) {
      sb.writeln(
        '"${e["name"]}",${e["energy"]},${e["protein"]},${e["fat"]},${e["carbs"]},${e["fiber"]}',
      );
    }
    return sb.toString();
  }

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
      _kWeeklyRecords,
      _kLastFoodClearDate,
      _kCustomFoodNutrition,
      _kSpeakerEnabled,
      _kLegacyEarphoneEnabled,
      _kLastProfileRemindDate,
      _kCalendarEventIds,
      _kAlarmTimes,
      _kDailyDietSummaries,
      _kDietAdvice,
      _kDishRecipes,
      _kExerciseCalories,
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
  final List<WeeklyRecord> weeklyRecords;
  final String lastFoodClearDate;
  final bool speakerEnabled;
  final List<DailyDietSummary> dailyDietSummaries;
  final DietAdvice? dietAdvice;

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
    required this.weeklyRecords,
    required this.lastFoodClearDate,
    required this.speakerEnabled,
    required this.dailyDietSummaries,
    required this.dietAdvice,
  });
}
