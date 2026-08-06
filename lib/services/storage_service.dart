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
  static const kAccountState = 'accountState';
  static const kPhone = 'phone';
  static const kFeishuName = 'feishuName';
  static const kFeishuAppId = 'feishuAppId';
  static const kFeishuAppSecret = 'feishuAppSecret';
  static const kFeishuOpenId = 'feishuOpenId';
  static const kProfile = 'profile';
  static const kNotificationGranted = 'notificationGranted';
  static const kReminderEnabled = 'reminderEnabled';
  static const kLoopInterval = 'loopInterval';
  static const kSingleReminders = 'singleReminders';
  static const kRepeat = 'repeat';
  static const kFeishuPushEnabled = 'feishuPushEnabled';
  static const kFeishuPushText = 'feishuPushText';
  static const kFeishuPushOnReminder = 'feishuPushOnReminder';
  static const kFeishuPushOnPunch = 'feishuPushOnPunch';
  static const kNightDnd = 'nightDnd';
  static const kNoonDnd = 'noonDnd';
  // 免打扰起止时间(可自设),格式 "HH:mm"
  static const kNoonDndStart = 'noonDndStart';
  static const kNoonDndEnd = 'noonDndEnd';
  static const kNightDndStart = 'nightDndStart';
  static const kNightDndEnd = 'nightDndEnd';
  static const kRememberSyncFeishu = 'rememberSyncFeishu';
  static const kRecords = 'records';
  static const kAiApiKey = 'aiApiKey';
  static const kFoodRecords = 'foodRecords';
  static const kExerciseRecords = 'exerciseRecords';
  static const kWeeklyRecords = 'weeklyRecords';
  static const kLastFoodClearDate = 'lastFoodClearDate';
  static const kCustomFoodNutrition = 'customFoodNutrition';
  // 午休免打扰首启询问标记
  static const kHasPromptedNoonDnd = 'hasPromptedNoonDnd';
  // 上次提醒更新个人信息的日期(每日首次进入热量追踪页提醒)
  static const kLastProfileRemindDate = 'lastProfileRemindDate';
  // 日历事件追踪(批量添加后记录 eventId,供一键清除使用)
  static const kCalendarEventIds = 'calendarEventIds';
  // 闹钟时间追踪(批量添加后记录时间,供一键清除提示)
  static const kAlarmTimes = 'alarmTimes';
  // 每日饮食摘要历史(每日清空食物记录前保存,供 AI 分析近期饮食)
  static const kDailyDietSummaries = 'dailyDietSummaries';
  // 当前 AI 饮食建议(含建议摄入量,可被动态调整)
  static const kDietAdvice = 'dietAdvice';
  // 用户保存的菜品配方(菜名 -> 食材及占比列表,永久记录供下次直接使用)
  static const kDishRecipes = 'dishRecipes';
  // 下次循环提醒的绝对时间(ISO8601)
  static const kNextAlarmTime = 'nextAlarmTime';
  // 提醒暂停开关(临时暂停全局提醒)
  static const kReminderPaused = 'reminderPaused';
  // 今日已触发提醒次数计数(跨天重置)
  static const kTodayReminderCount = 'todayReminderCount';
  static const kTodayReminderDate = 'todayReminderDate';
  static const kLastReminderTime = 'lastReminderTime';
  // 是否已询问过通知权限(首启引导)
  static const kHasPromptedNotification = 'hasPromptedNotification';
  // 红色摄入过多时的弹窗文案(用户可选预设或自定义)
  static const kForbiddenWarningText = 'forbiddenWarningText';
  // 今日是否已弹过红色摄入过多提醒(每天最多一次)
  static const kForbiddenWarnedDate = 'forbiddenWarnedDate';

  // ============ 菜品配方(永久保存的食材占比) ============

  /// 保存单个菜品配方(菜名 -> 食材列表),覆盖同名旧配方
  static Future<void> saveDishRecipe(String dishName, List<FoodIngredient> ingredients) async {
    final all = loadAllDishRecipes();
    all[dishName] = ingredients;
    await _p.setString(kDishRecipes,
        jsonEncode(all.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()))));
  }

  /// 加载全部菜品配方
  static Map<String, List<FoodIngredient>> loadAllDishRecipes() {
    final s = _p.getString(kDishRecipes);
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
  static const kExerciseCalories = 'exerciseCalories';

  /// 保存单个运动的单次热量(运动名 -> kcal/次),覆盖同名旧记录
  static Future<void> saveExerciseCalorie(String name, double kcalPerRep) async {
    final all = loadAllExerciseCalories();
    all[name] = kcalPerRep;
    await _p.setString(kExerciseCalories, jsonEncode(all));
  }

  /// 加载全部运动单次热量
  static Map<String, double> loadAllExerciseCalories() {
    final s = _p.getString(kExerciseCalories);
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
    return StoredData(
      accountStateIndex: p.getInt(kAccountState) ?? 0,
      phone: p.getString(kPhone) ?? '',
      feishuName: p.getString(kFeishuName) ?? '',
      feishuAppId: p.getString(kFeishuAppId) ?? '',
      feishuAppSecret: p.getString(kFeishuAppSecret) ?? '',
      feishuOpenId: p.getString(kFeishuOpenId) ?? '',
      profile: _loadProfile(),
      notificationGranted: p.getBool(kNotificationGranted) ?? false,
      reminderEnabled: p.getBool(kReminderEnabled) ?? true,
      loopInterval: p.getInt(kLoopInterval) ?? 60,
      singleReminders: _loadSingleReminders(),
      feishuPushEnabled: p.getBool(kFeishuPushEnabled) ?? false,
      feishuPushText: p.getString(kFeishuPushText) ?? '到时间啦~ 起来动一动,舒展一下身体吧',
      feishuPushOnReminder: p.getBool(kFeishuPushOnReminder) ?? true,
      feishuPushOnPunch: p.getBool(kFeishuPushOnPunch) ?? false,
      nightDnd: p.getBool(kNightDnd) ?? true,
      // 午休免打扰默认关闭,首启时主动询问用户
      noonDnd: p.getBool(kNoonDnd) ?? false,
      noonDndStart: p.getString(kNoonDndStart) ?? '12:30',
      noonDndEnd: p.getString(kNoonDndEnd) ?? '14:30',
      nightDndStart: p.getString(kNightDndStart) ?? '22:00',
      nightDndEnd: p.getString(kNightDndEnd) ?? '08:00',
      hasPromptedNoonDnd: p.getBool(kHasPromptedNoonDnd) ?? false,
      rememberSyncFeishu: p.getBool(kRememberSyncFeishu) ?? true,
      records: _loadRecords(),
      aiApiKey: p.getString(kAiApiKey) ?? '',
      foodRecords: _loadFoodRecords(),
      exerciseRecords: _loadExerciseRecords(),
      weeklyRecords: _loadWeeklyRecords(),
      lastFoodClearDate: p.getString(kLastFoodClearDate) ?? '',
      dailyDietSummaries: loadDailyDietSummaries(),
      dietAdvice: loadDietAdvice(),
    );
  }

  static UserProfile _loadProfile() {
    final s = _p.getString(kProfile);
    if (s == null) return const UserProfile();
    try {
      return UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const UserProfile();
    }
  }

  static List<SingleReminder> _loadSingleReminders() {
    final s = _p.getString(kSingleReminders);
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
    final s = _p.getString(kRecords);
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
    final s = _p.getString(kFoodRecords);
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
    final s = _p.getString(kExerciseRecords);
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
    final s = _p.getString(kWeeklyRecords);
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
      _p.setInt(kAccountState, index);
  static Future<void> savePhone(String v) => _p.setString(kPhone, v);
  static Future<void> saveFeishuName(String v) => _p.setString(kFeishuName, v);
  static Future<void> saveFeishuAppId(String v) =>
      _p.setString(kFeishuAppId, v);
  static Future<void> saveFeishuAppSecret(String v) =>
      _p.setString(kFeishuAppSecret, v);
  static Future<void> saveFeishuOpenId(String v) =>
      _p.setString(kFeishuOpenId, v);
  static Future<void> saveProfile(UserProfile p) =>
      _p.setString(kProfile, jsonEncode(p.toJson()));
  static Future<void> saveNotificationGranted(bool v) =>
      _p.setBool(kNotificationGranted, v);
  static Future<void> saveReminderEnabled(bool v) =>
      _p.setBool(kReminderEnabled, v);
  static Future<void> saveLoopInterval(int v) => _p.setInt(kLoopInterval, v);
  static Future<void> saveSingleReminders(List<SingleReminder> list) =>
      _p.setString(
          kSingleReminders, jsonEncode(list.map((e) => e.toJson()).toList()));
  static Future<void> saveFeishuPushEnabled(bool v) =>
      _p.setBool(kFeishuPushEnabled, v);
  static Future<void> saveFeishuPushText(String v) =>
      _p.setString(kFeishuPushText, v);
  static Future<void> saveFeishuPushFlags({bool? reminder, bool? punch}) {
    if (reminder != null) _p.setBool(kFeishuPushOnReminder, reminder);
    if (punch != null) _p.setBool(kFeishuPushOnPunch, punch);
    return Future.value();
  }

  static Future<void> saveNightDnd(bool v) => _p.setBool(kNightDnd, v);
  static Future<void> saveNoonDnd(bool v) => _p.setBool(kNoonDnd, v);
  static Future<void> saveHasPromptedNoonDnd(bool v) =>
      _p.setBool(kHasPromptedNoonDnd, v);

  // ---- 免打扰起止时间(可自设) ----
  static Future<void> saveNoonDndTime({String? start, String? end}) {
    if (start != null) _p.setString(kNoonDndStart, start);
    if (end != null) _p.setString(kNoonDndEnd, end);
    return Future.value();
  }

  static Future<void> saveNightDndTime({String? start, String? end}) {
    if (start != null) _p.setString(kNightDndStart, start);
    if (end != null) _p.setString(kNightDndEnd, end);
    return Future.value();
  }

  /// 读取上次提醒更新个人信息的日期(yyyy-MM-dd)
  static String getLastProfileRemindDate() =>
      _p.getString(kLastProfileRemindDate) ?? '';
  static Future<void> saveLastProfileRemindDate(String date) =>
      _p.setString(kLastProfileRemindDate, date);

  /// 日历事件追踪记录读写(批量添加日历事件后,记录 eventId 供一键清除)
  static List<CalendarEventRef> loadCalendarEventIds() {
    final s = _p.getString(kCalendarEventIds);
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
      _p.setString(kCalendarEventIds,
          jsonEncode(list.map((e) => e.toJson()).toList()));

  /// 闹钟时间追踪记录读写(批量添加闹钟后,记录时间供一键清除提示)
  static List<AlarmTimeRecord> loadAlarmTimes() {
    final s = _p.getString(kAlarmTimes);
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
          kAlarmTimes, jsonEncode(list.map((e) => e.toJson()).toList()));

  /// 每日饮食摘要历史读写
  static List<DailyDietSummary> loadDailyDietSummaries() {
    final s = _p.getString(kDailyDietSummaries);
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
      _p.setString(kDailyDietSummaries,
          jsonEncode(list.map((e) => e.toJson()).toList()));

  /// 当前 AI 饮食建议读写
  static DietAdvice? loadDietAdvice() {
    final s = _p.getString(kDietAdvice);
    if (s == null) return null;
    try {
      return DietAdvice.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveDietAdvice(DietAdvice? advice) {
    if (advice == null) {
      return _p.remove(kDietAdvice);
    }
    return _p.setString(kDietAdvice, jsonEncode(advice.toJson()));
  }
  static Future<void> saveRememberSyncFeishu(bool v) =>
      _p.setBool(kRememberSyncFeishu, v);
  static Future<void> saveRecords(List<WaterRecord> list) =>
      _p.setString(kRecords, jsonEncode(list.map((e) => e.toJson()).toList()));

  static Future<void> saveAiApiKey(String v) => _p.setString(kAiApiKey, v);
  static String getAiApiKey() => _p.getString(kAiApiKey) ?? '';
  static Future<void> saveFoodRecords(List<FoodRecord> list) => _p.setString(
      kFoodRecords, jsonEncode(list.map((e) => e.toJson()).toList()));
  static Future<void> saveExerciseRecords(List<ExerciseRecord> list) =>
      _p.setString(
          kExerciseRecords, jsonEncode(list.map((e) => e.toJson()).toList()));
  static Future<void> saveWeeklyRecords(List<WeeklyRecord> list) =>
      _p.setString(
          kWeeklyRecords, jsonEncode(list.map((e) => e.toJson()).toList()));
  static Future<void> saveLastFoodClearDate(String date) =>
      _p.setString(kLastFoodClearDate, date);

  /// 保存用户自定义食物营养表到本地
  static Future<void> saveCustomFoodNutrition() =>
      _p.setString(kCustomFoodNutrition,
          jsonEncode(FoodNutritionDB.customToJsonList()));

  /// 加载用户自定义食物营养表(启动时调用)
  static void loadCustomFoodNutrition() {
    final s = _p.getString(kCustomFoodNutrition);
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

  /// 导出全部持久化数据为 JSON 字符串(所有 SharedPreferences 键值)
  /// 键统一去掉 flutter. 前缀,便于阅读与后续导入
  static String exportAllDataJson() {
    final all = _p.getKeys();
    final map = <String, dynamic>{};
    for (final k in all) {
      final key = k.startsWith('flutter.') ? k.substring(8) : k;
      map[key] = _p.get(k);
    }
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// 红色摄入过多提醒的弹窗文案读写
  static String getForbiddenWarningText() =>
      _p.getString(kForbiddenWarningText) ?? '陛下,你的减肥大业药丸啦!';
  static Future<void> saveForbiddenWarningText(String v) =>
      _p.setString(kForbiddenWarningText, v);

  /// 今日是否已弹过红色摄入过多提醒(每天最多一次)
  static String getForbiddenWarnedDate() =>
      _p.getString(kForbiddenWarnedDate) ?? '';
  static Future<void> saveForbiddenWarnedDate(String date) =>
      _p.setString(kForbiddenWarnedDate, date);

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
      kAccountState,
      kPhone,
      kFeishuName,
      kFeishuAppId,
      kFeishuAppSecret,
      kFeishuOpenId,
      kProfile,
      kNotificationGranted,
      kReminderEnabled,
      kLoopInterval,
      kSingleReminders,
      kRepeat,
      kFeishuPushEnabled,
      kFeishuPushText,
      kFeishuPushOnReminder,
      kFeishuPushOnPunch,
      kNightDnd,
      kNoonDnd,
      kNoonDndStart,
      kNoonDndEnd,
      kNightDndStart,
      kNightDndEnd,
      kHasPromptedNoonDnd,
      kRememberSyncFeishu,
      kRecords,
      kAiApiKey,
      kFoodRecords,
      kExerciseRecords,
      kWeeklyRecords,
      kLastFoodClearDate,
      kCustomFoodNutrition,
      kLastProfileRemindDate,
      kCalendarEventIds,
      kAlarmTimes,
      kDailyDietSummaries,
      kDietAdvice,
      kDishRecipes,
      kExerciseCalories,
      kForbiddenWarningText,
      kForbiddenWarnedDate,
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
  final int loopInterval;
  final List<SingleReminder> singleReminders;
  final bool feishuPushEnabled;
  final String feishuPushText;
  final bool feishuPushOnReminder;
  final bool feishuPushOnPunch;
  final bool nightDnd;
  final bool noonDnd;
  final String noonDndStart;
  final String noonDndEnd;
  final String nightDndStart;
  final String nightDndEnd;
  final bool hasPromptedNoonDnd;
  final bool rememberSyncFeishu;
  final List<WaterRecord> records;
  final String aiApiKey;
  final List<FoodRecord> foodRecords;
  final List<ExerciseRecord> exerciseRecords;
  final List<WeeklyRecord> weeklyRecords;
  final String lastFoodClearDate;
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
    required this.loopInterval,
    required this.singleReminders,
    required this.feishuPushEnabled,
    required this.feishuPushText,
    required this.feishuPushOnReminder,
    required this.feishuPushOnPunch,
    required this.nightDnd,
    required this.noonDnd,
    required this.noonDndStart,
    required this.noonDndEnd,
    required this.nightDndStart,
    required this.nightDndEnd,
    required this.hasPromptedNoonDnd,
    required this.rememberSyncFeishu,
    required this.records,
    required this.aiApiKey,
    required this.foodRecords,
    required this.exerciseRecords,
    required this.weeklyRecords,
    required this.lastFoodClearDate,
    required this.dailyDietSummaries,
    required this.dietAdvice,
  });
}
