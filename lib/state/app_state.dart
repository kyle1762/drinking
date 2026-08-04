import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/feishu_service.dart';
import '../services/alarm_service.dart';
import '../services/ai_service.dart';

/// 全局状态 - 单一数据源(安卓ViewModel统一数据源)
/// 三页面共享:账号三态、全局参数单向同步、提醒/记录/飞书配置
/// 所有状态变更均持久化到 SharedPreferences,App 重启不丢失
class AppState extends ChangeNotifier {
  AppState() {
    _loadFromStorage();
    // App 启动时如果提醒已开启,自动重新注册闹钟(确保后台被杀后重启仍能提醒)
    _ensureAlarmScheduled();
    // 同步今日提醒次数(从 SharedPreferences 读取后台 isolate 写入的计数)
    syncReminderCount();
  }

  /// 确保闹钟已注册(App 启动时调用)
  void _ensureAlarmScheduled() {
    if (_reminderEnabled && !_reminderPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await AlarmService.scheduleLoop(_loopInterval);
          debugPrint('[AppState] 启动时已重新注册循环闹钟');
        } catch (e) {
          debugPrint('[AppState] 启动时注册闹钟失败: $e');
        }
      });
    }
  }

  // ============ 账号三态 ============
  AccountState _accountState = AccountState.guest;
  String _phone = '';
  String _feishuName = '';
  String _feishuAppId = '';
  String _feishuAppSecret = '';
  String _feishuOpenId = '';

  AccountState get accountState => _accountState;
  bool get isGuest => _accountState == AccountState.guest;
  bool get isLoggedIn => _accountState != AccountState.guest;
  bool get isFeishuBound => _accountState == AccountState.boundFeishu;
  String get phone => _phone;
  String get feishuName => _feishuName;
  String get feishuAppId => _feishuAppId;
  String get feishuAppSecret => _feishuAppSecret;
  String get feishuOpenId => _feishuOpenId;

  // ============ 全局参数(单向同步) ============
  UserProfile _profile = const UserProfile();
  UserProfile get profile => _profile;

  // ============ 通知权限 ============
  bool _notificationGranted = false;
  bool get notificationGranted => _notificationGranted;

  // ============ 提醒设置 ============
  bool _reminderEnabled = true;
  int _loopInterval = 60; // 分钟
  final List<SingleReminder> _singleReminders = [];
  bool _reminderPaused = false;

  bool get reminderEnabled => _reminderEnabled;
  int get loopInterval => _loopInterval;
  List<SingleReminder> get singleReminders =>
      List.unmodifiable(_singleReminders);
  bool get reminderPaused => _reminderPaused;

  /// 今日已提醒次数(从 SharedPreferences 同步,后台 isolate 也能写入)
  int _todayReminderCount = 0;
  int get todayReminderCount => _todayReminderCount;

  /// 上次提醒时间
  DateTime? _lastReminderTime;

  /// 下次闹钟触发时间(由 AlarmService 写入 SharedPreferences,精确值)
  DateTime? _nextAlarmTime;

  /// 从 SharedPreferences 同步今日提醒次数和下次提醒时间(App 回前台/定时刷新时调用)
  void syncReminderCount() {
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';
      final savedDateStr = prefs.getString(StorageService.kTodayReminderDate);
      final count = prefs.getInt(StorageService.kTodayReminderCount) ?? 0;
      final lastStr = prefs.getString(StorageService.kLastReminderTime);
      final nextStr = prefs.getString(StorageService.kNextAlarmTime);

      // 日期变更则重置
      if (savedDateStr != todayStr) {
        _todayReminderCount = 0;
      } else {
        _todayReminderCount = count;
      }

      _lastReminderTime = lastStr != null ? DateTime.tryParse(lastStr) : null;
      _nextAlarmTime = nextStr != null ? DateTime.tryParse(nextStr) : null;
      notifyListeners();
    });
  }

  /// 下次提醒时间
  /// 优先使用 AlarmService 写入的精确闹钟时间(实时同步),无则回退到计算值
  String get nextReminderTime {
    if (!_reminderEnabled || _reminderPaused) return '已暂停';
    final now = DateTime.now();
    // 优先使用 AlarmService 注册时写入的精确下次闹钟时间
    if (_nextAlarmTime != null && _nextAlarmTime!.isAfter(now)) {
      return '${_nextAlarmTime!.hour.toString().padLeft(2, '0')}:${_nextAlarmTime!.minute.toString().padLeft(2, '0')}';
    }
    // 回退:基于上次提醒时间 + 间隔计算
    final base = _lastReminderTime ?? now;
    final next = base.add(Duration(minutes: _loopInterval));
    final actualNext =
        next.isAfter(now) ? next : now.add(Duration(minutes: _loopInterval));
    return '${actualNext.hour.toString().padLeft(2, '0')}:${actualNext.minute.toString().padLeft(2, '0')}';
  }

  // ============ 飞书推送 ============
  bool _feishuPushEnabled = false;
  String _feishuPushText = '到时间啦~ 起身动动,接杯水喝一口吧';
  bool _feishuPushOnReminder = true;
  bool _feishuPushOnPunch = false;

  bool get feishuPushEnabled => _feishuPushEnabled;
  String get feishuPushText => _feishuPushText;
  bool get feishuPushOnReminder => _feishuPushOnReminder;
  bool get feishuPushOnPunch => _feishuPushOnPunch;

  // ============ 免打扰 ============
  bool _nightDnd = true;
  bool _noonDnd = false; // 默认关闭,首启时主动询问用户
  bool _hasPromptedNoonDnd = false; // 是否已弹过午休免打扰询问

  bool get nightDnd => _nightDnd;
  bool get noonDnd => _noonDnd;
  bool get hasPromptedNoonDnd => _hasPromptedNoonDnd;

  // ============ 喝水记录 ============
  final List<WaterRecord> _records = [];
  List<WaterRecord> get records => List.unmodifiable(_records);

  /// 仅今日记录(按本地日期过滤)
  List<WaterRecord> get todayRecords {
    final now = DateTime.now();
    return _records
        .where((r) =>
            r.time.year == now.year &&
            r.time.month == now.month &&
            r.time.day == now.day)
        .toList();
  }

  int get todayTotal => todayRecords.fold(0, (s, r) => s + r.amount);
  int get todayGoal => _profile.dailyGoal;
  int get todayRemaining =>
      (_profile.dailyGoal - todayTotal).clamp(0, _profile.dailyGoal);
  double get todayRate => todayTotal / _profile.dailyGoal.clamp(1, 99999);

  // ============ 饮食/运动追踪 ============
  final List<FoodRecord> _foodRecords = [];
  final List<ExerciseRecord> _exerciseRecords = [];
  final List<WeeklyRecord> _weeklyRecords = [];
  final List<DailyDietSummary> _dailyDietSummaries = [];
  DietAdvice? _dietAdvice;
  String _lastFoodClearDate = '';

  List<FoodRecord> get foodRecords => List.unmodifiable(_foodRecords);
  List<ExerciseRecord> get exerciseRecords =>
      List.unmodifiable(_exerciseRecords);
  List<WeeklyRecord> get weeklyRecords => List.unmodifiable(_weeklyRecords);
  List<DailyDietSummary> get dailyDietSummaries =>
      List.unmodifiable(_dailyDietSummaries);
  DietAdvice? get dietAdvice => _dietAdvice;

  /// 今日饮食记录
  List<FoodRecord> get todayFoodRecords {
    final now = DateTime.now();
    return _foodRecords
        .where((r) =>
            r.time.year == now.year &&
            r.time.month == now.month &&
            r.time.day == now.day)
        .toList();
  }

  /// 今日运动记录
  List<ExerciseRecord> get todayExerciseRecords {
    final now = DateTime.now();
    return _exerciseRecords
        .where((r) =>
            r.time.year == now.year &&
            r.time.month == now.month &&
            r.time.day == now.day)
        .toList();
  }

  /// 今日摄入热量 (kcal)
  int get todayFoodCalories =>
      todayFoodRecords.fold(0, (s, r) => s + r.calories);

  /// 今日消耗热量 (kcal)
  int get todayExerciseCalories =>
      todayExerciseRecords.fold(0, (s, r) => s + r.calories);

  /// 今日净摄入 (摄入 - 消耗)
  int get todayNetCalories => todayFoodCalories - todayExerciseCalories;

  /// 今日蛋白质 (g)
  double get todayProtein =>
      todayFoodRecords.fold(0.0, (s, r) => s + r.protein);

  /// 今日脂肪 (g)
  double get todayFat => todayFoodRecords.fold(0.0, (s, r) => s + r.fat);

  /// 今日碳水 (g)
  double get todayCarbs => todayFoodRecords.fold(0.0, (s, r) => s + r.carbs);

  /// 今日膳食纤维 (g)
  double get todayFiber => todayFoodRecords.fold(0.0, (s, r) => s + r.fiber);

  /// 每日消耗热量 = 消耗热量 + 基础代谢量 - 摄入热量
  /// 未填全个人信息时返回 null
  int? get todayDailyBurn {
    final bmr = _profile.bmr;
    if (bmr == null) return null;
    return todayExerciseCalories + bmr - todayFoodCalories;
  }

  /// 建议日消耗热量 = BMR - 建议摄入热量
  /// 减脂:正值(热量缺口);增肌:负值(热量盈余);保持:0
  /// 未填全个人信息或无建议摄入量时返回 null
  int? get suggestedDailyBurn {
    final bmr = _profile.bmr;
    if (bmr == null) return null;
    final sugCal = suggestedCalories;
    if (sugCal == null) return null;
    return bmr - sugCal;
  }

  /// 摄入是否低于最低阈值(男1500/女1200)
  bool get isIntakeTooLow {
    if (todayFoodCalories <= 0) return false; // 还没记录不算低
    return todayFoodCalories < _profile.minIntake;
  }

  /// 本周累计消耗热量(周一至今天,仅运动消耗)
  int get thisWeekBurnCalories {
    final now = DateTime.now();
    // 周一 = 1
    final weekDay = now.weekday;
    final monday = now.subtract(Duration(days: weekDay - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);
    return _exerciseRecords
        .where((r) => r.time.isAfter(startOfWeek))
        .fold(0, (s, r) => s + r.calories);
  }

  // ============ 饮食建议(增肌/减脂/保持) ============

  /// 当前有效的建议摄入热量(kcal)
  /// 优先使用 AI 建议值(含动态调整),无建议时用公式估算
  /// 最低不得低于 minIntake(男 1500 / 女 1200 kcal),防止减脂建议过低
  int? get suggestedCalories {
    final minIntake = _profile.minIntake;
    if (_dietAdvice != null && _dietAdvice!.isValid) {
      final raw = _dietAdvice!.suggestedCalories;
      // 确保不低于最低摄入标准
      return raw < minIntake ? minIntake : raw;
    }
    final base = _calcBaseSuggestedCalories();
    if (base == null) return null;
    return base < minIntake ? minIntake : base;
  }

  /// 当前有效的建议蛋白质(g)
  double? get suggestedProtein {
    if (_dietAdvice != null && _dietAdvice!.isValid) {
      return _dietAdvice!.suggestedProtein;
    }
    return _calcBaseSuggestedProtein();
  }

  /// 当前有效的建议脂肪(g)
  double? get suggestedFat {
    if (_dietAdvice != null && _dietAdvice!.isValid) {
      return _dietAdvice!.suggestedFat;
    }
    return _calcBaseSuggestedFat();
  }

  /// 当前有效的建议碳水(g)
  double? get suggestedCarbs {
    if (_dietAdvice != null && _dietAdvice!.isValid) {
      return _dietAdvice!.suggestedCarbs;
    }
    return _calcBaseSuggestedCarbs();
  }

  /// 当前有效的建议膳食纤维(g)
  double? get suggestedFiber {
    if (_dietAdvice != null && _dietAdvice!.isValid) {
      return _dietAdvice!.suggestedFiber;
    }
    return 25.0; // 中国营养学会推荐成人每日 25-30g
  }

  /// 基础建议热量(根据目标 + BMR 计算)
  int? _calcBaseSuggestedCalories() {
    final bmr = _profile.bmr;
    if (bmr == null) return null;
    switch (_profile.goal) {
      case UserGoal.loseFat:
        return (bmr * 0.8).round(); // 热量缺口 20%
      case UserGoal.gainMuscle:
        return (bmr * 1.1).round(); // 热量盈余 10%
      case UserGoal.maintain:
        return bmr;
    }
  }

  /// 基础建议蛋白质(g/kg 体重)
  double? _calcBaseSuggestedProtein() {
    if (_profile.weight <= 0) return null;
    switch (_profile.goal) {
      case UserGoal.loseFat:
        return _profile.weight * 1.5; // 减脂需高蛋白保肌肉
      case UserGoal.gainMuscle:
        return _profile.weight * 2.0; // 增肌需高蛋白
      case UserGoal.maintain:
        return _profile.weight * 1.2;
    }
  }

  /// 基础建议脂肪(g/kg 体重)
  double? _calcBaseSuggestedFat() {
    if (_profile.weight <= 0) return null;
    switch (_profile.goal) {
      case UserGoal.loseFat:
        return _profile.weight * 0.6; // 减脂控脂肪
      case UserGoal.gainMuscle:
        return _profile.weight * 0.8;
      case UserGoal.maintain:
        return _profile.weight * 0.7;
    }
  }

  /// 基础建议碳水(g/kg 体重)
  double? _calcBaseSuggestedCarbs() {
    if (_profile.weight <= 0) return null;
    switch (_profile.goal) {
      case UserGoal.loseFat:
        return _profile.weight * 2.0; // 减脂控碳水
      case UserGoal.gainMuscle:
        return _profile.weight * 4.0; // 增肌高碳水
      case UserGoal.maintain:
        return _profile.weight * 3.0;
    }
  }

  /// 设置用户目标
  void setUserGoal(UserGoal goal) {
    _profile = _profile.copyWith(goal: goal);
    StorageService.saveProfile(_profile);
    notifyListeners();
  }

  /// 保存 AI 生成的饮食建议
  void setDietAdvice(DietAdvice advice) {
    _dietAdvice = advice;
    StorageService.saveDietAdvice(advice);
    notifyListeners();
  }

  /// 触发 AI 饮食分析,生成个性化建议
  /// 取最近 N 天的饮食摘要 + 今日实时数据 + 用户目标 + 个人信息,调用 AiService 生成 DietAdvice
  /// 返回 (success, message)
  Future<(bool success, String message)> triggerDietAnalysis({
    int recentDays = 3,
  }) async {
    if (!_profile.profileComplete) {
      return (false, '请先完善个人信息(性别/年龄/身高/体重)');
    }

    // 取最近 recentDays 天的摘要(不含今天,因为今天的还在记录中)
    final today = DateTime.now();
    final cutoff = today.subtract(Duration(days: recentDays));
    final recent = _dailyDietSummaries
        .where((s) => s.date.isAfter(cutoff) && s.date.isBefore(DateTime(today.year, today.month, today.day)))
        .toList();

    // 构造今日实时摘要(含运动消耗),让 AI 看到今日真实摄入情况
    final todayFood = todayFoodRecords;
    final todaySummary = DailyDietSummary(
      date: DateTime(today.year, today.month, today.day),
      calories: todayFood.fold(0, (s, r) => s + r.calories),
      exerciseCalories: todayExerciseCalories,
      protein: todayFood.fold(0.0, (s, r) => s + r.protein),
      fat: todayFood.fold(0.0, (s, r) => s + r.fat),
      carbs: todayFood.fold(0.0, (s, r) => s + r.carbs),
      fiber: todayFood.fold(0.0, (s, r) => s + r.fiber),
      foodNames: todayFood.map((r) => r.name).toSet().toList(),
    );

    // 调用 AI 服务生成建议(同时传递今日实时数据)
    final advice = await AiService.analyzeDietAndAdvise(
      recentSummaries: recent,
      todaySummary: todaySummary,
      goal: _profile.goal,
      profile: _profile,
    );

    if (advice == null) {
      return (false, 'AI 分析失败,请检查网络或 API Key 后重试');
    }

    setDietAdvice(advice);
    return (true, '已生成新的饮食建议,有效期至 ${advice.validUntil.month}-${advice.validUntil.day}');
  }

  /// 检查昨日摄入是否超量/不足,动态调整未来三天的建议值
  /// 在每日清空食物记录前调用
  void _adjustAdviceBasedOnYesterday() {
    if (_dietAdvice == null || !_dietAdvice!.isValid) return;

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    // 从饮食摘要历史中找昨天的记录
    DailyDietSummary? yesterdaySummary;
    for (final s in _dailyDietSummaries) {
      if (s.date.year == yesterday.year &&
          s.date.month == yesterday.month &&
          s.date.day == yesterday.day) {
        yesterdaySummary = s;
        break;
      }
    }
    if (yesterdaySummary == null) return;

    final advice = _dietAdvice!;
    double newCalories = advice.suggestedCalories.toDouble();
    double newProtein = advice.suggestedProtein;
    double newFat = advice.suggestedFat;
    double newCarbs = advice.suggestedCarbs;
    double newFiber = advice.suggestedFiber;
    bool changed = false;

    if (advice.goal == UserGoal.loseFat) {
      // 减脂:超量则未来三天建议少摄入 10%;纤维不足则增加 20%
      if (yesterdaySummary.calories > advice.suggestedCalories * 1.1) {
        newCalories *= 0.9;
        changed = true;
      }
      if (yesterdaySummary.carbs > advice.suggestedCarbs * 1.1) {
        newCarbs *= 0.9;
        changed = true;
      }
      if (yesterdaySummary.fat > advice.suggestedFat * 1.1) {
        newFat *= 0.9;
        changed = true;
      }
      if (yesterdaySummary.fiber < advice.suggestedFiber * 0.8) {
        newFiber *= 1.2;
        changed = true;
      }
    } else if (advice.goal == UserGoal.gainMuscle) {
      // 增肌:摄入不足则未来三天建议增加 10%
      if (yesterdaySummary.protein < advice.suggestedProtein * 0.9) {
        newProtein *= 1.1;
        changed = true;
      }
      if (yesterdaySummary.carbs < advice.suggestedCarbs * 0.9) {
        newCarbs *= 1.1;
        changed = true;
      }
      if (yesterdaySummary.calories < advice.suggestedCalories * 0.9) {
        newCalories *= 1.1;
        changed = true;
      }
    }

    if (changed) {
      // 确保热量不低于最低摄入标准(男 1500 / 女 1200 kcal)
      final minIntake = _profile.minIntake;
      final finalCalories = newCalories.round() < minIntake
          ? minIntake
          : newCalories.round();
      _dietAdvice = DietAdvice(
        createdAt: advice.createdAt,
        goal: advice.goal,
        eatMore: advice.eatMore,
        eatLess: advice.eatLess,
        summary: advice.summary,
        suggestedCalories: finalCalories,
        suggestedProtein: newProtein,
        suggestedFat: newFat,
        suggestedCarbs: newCarbs,
        suggestedFiber: newFiber,
        validUntil: advice.validUntil,
      );
      StorageService.saveDietAdvice(_dietAdvice);
      debugPrint('[AppState] 已动态调整建议值: cal=$finalCalories protein=$newProtein carbs=$newCarbs fat=$newFat fiber=$newFiber');
    }
  }

  // ============ 同步至飞书打卡记忆 ============
  bool _rememberSyncToFeishu = true;

  bool get rememberSyncToFeishu => _rememberSyncToFeishu;

  // ===================== 持久化加载 =====================

  void _loadFromStorage() {
    final d = StorageService.loadAll();
    _accountState = AccountState.values[d.accountStateIndex.clamp(0, 2)];
    _phone = d.phone;
    _feishuName = d.feishuName;
    _feishuAppId = d.feishuAppId;
    _feishuAppSecret = d.feishuAppSecret;
    _feishuOpenId = d.feishuOpenId;
    _profile = d.profile;
    _notificationGranted = d.notificationGranted;
    _reminderEnabled = d.reminderEnabled;
    _loopInterval = d.loopInterval;
    _singleReminders
      ..clear()
      ..addAll(d.singleReminders.where((r) => !r.isExpired));
    _feishuPushEnabled = d.feishuPushEnabled;
    _feishuPushText = d.feishuPushText;
    _feishuPushOnReminder = d.feishuPushOnReminder;
    _feishuPushOnPunch = d.feishuPushOnPunch;
    _nightDnd = d.nightDnd;
    _noonDnd = d.noonDnd;
    _hasPromptedNoonDnd = d.hasPromptedNoonDnd;
    _rememberSyncToFeishu = d.rememberSyncFeishu;
    // 仅加载最近 60 天的记录,避免无限增长
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    _records
      ..clear()
      ..addAll(d.records.where((r) => r.time.isAfter(cutoff)));
    _foodRecords
      ..clear()
      ..addAll(d.foodRecords.where((r) => r.time.isAfter(cutoff)));
    _exerciseRecords
      ..clear()
      ..addAll(d.exerciseRecords.where((r) => r.time.isAfter(cutoff)));
    _weeklyRecords
      ..clear()
      ..addAll(d.weeklyRecords);
    _dailyDietSummaries
      ..clear()
      ..addAll(d.dailyDietSummaries);
    _dietAdvice = d.dietAdvice;
    _lastFoodClearDate = d.lastFoodClearDate;
    // 启动时检查是否需要按日清空食物记录(内部会保存昨日摘要并动态调整建议)
    _checkDailyFoodClear();
    // 启动时检查是否需要记录周末周报
    _checkWeeklyRecord();
  }

  /// 检查每日食物记录清空:日期变更则清空今日之前的食物记录
  /// 清空前会先把昨日(及之前未保存的)饮食数据汇总成 DailyDietSummary 保存到历史
  /// 然后基于昨日数据动态调整未来三天的建议摄入量
  void _checkDailyFoodClear() {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    if (_lastFoodClearDate != todayStr) {
      // 把所有非今日的食物记录按日聚合保存为 DailyDietSummary(供 AI 分析历史饮食)
      _saveDailySummariesBeforeClear(today);

      // 日期已变更,清空非今日的食物记录(保留运动记录历史)
      _foodRecords.removeWhere((r) =>
          r.time.year != today.year ||
          r.time.month != today.month ||
          r.time.day != today.day);
      _lastFoodClearDate = todayStr;
      StorageService.saveLastFoodClearDate(todayStr);
      StorageService.saveFoodRecords(_foodRecords);

      // 基于昨日数据动态调整未来三天建议值(必须在保存摘要之后调用)
      _adjustAdviceBasedOnYesterday();

      debugPrint('[AppState] 已按日清空食物记录, date=$todayStr');
    }
  }

  /// 清空前把非今日的食物记录按日聚合保存为 DailyDietSummary
  /// 仅保存已有摘要缺失的日期,避免重复
  void _saveDailySummariesBeforeClear(DateTime today) {
    if (_foodRecords.isEmpty) return;
    // 找出所有非今日的食物记录
    final oldRecords = _foodRecords.where((r) =>
        r.time.year != today.year ||
        r.time.month != today.month ||
        r.time.day != today.day);

    // 按日分组
    final Map<String, List<FoodRecord>> byDay = {};
    for (final r in oldRecords) {
      final key = '${r.time.year}-${r.time.month}-${r.time.day}';
      byDay.putIfAbsent(key, () => []).add(r);
    }

    bool added = false;
    byDay.forEach((key, list) {
      // 已存在该日摘要则跳过
      final exists = _dailyDietSummaries.any((s) =>
          '${s.date.year}-${s.date.month}-${s.date.day}' == key);
      if (exists) return;
      final date = DateTime(list.first.time.year, list.first.time.month, list.first.time.day);
      // 同日的运动消耗(运动记录不清空,需从全量运动记录中按日聚合)
      final exerciseCalories = _exerciseRecords
          .where((e) =>
              e.time.year == date.year &&
              e.time.month == date.month &&
              e.time.day == date.day)
          .fold(0, (s, r) => s + r.calories);
      _dailyDietSummaries.add(DailyDietSummary(
        date: date,
        calories: list.fold(0, (s, r) => s + r.calories),
        exerciseCalories: exerciseCalories,
        protein: list.fold(0.0, (s, r) => s + r.protein),
        fat: list.fold(0.0, (s, r) => s + r.fat),
        carbs: list.fold(0.0, (s, r) => s + r.carbs),
        fiber: list.fold(0.0, (s, r) => s + r.fiber),
        foodNames: list.map((r) => r.name).toSet().toList(),
      ));
      added = true;
    });

    if (added) {
      // 仅保留最近 30 天摘要
      _dailyDietSummaries.sort((a, b) => a.date.compareTo(b.date));
      if (_dailyDietSummaries.length > 30) {
        _dailyDietSummaries.removeRange(0, _dailyDietSummaries.length - 30);
      }
      StorageService.saveDailyDietSummaries(_dailyDietSummaries);
    }
  }

  /// 手动清空今日食物摄入记录
  void clearTodayFoodRecords() {
    final today = DateTime.now();
    _foodRecords.removeWhere((r) =>
        r.time.year == today.year &&
        r.time.month == today.month &&
        r.time.day == today.day);
    StorageService.saveFoodRecords(_foodRecords);
    notifyListeners();
  }

  /// 检查是否需要记录周末周报(仅周日触发,每天最多一次)
  void _checkWeeklyRecord() {
    final now = DateTime.now();
    // 仅在周日(7)触发
    if (now.weekday != DateTime.sunday) {
      return;
    }
    // 当天已记录则跳过
    if (_weeklyRecords.any((r) =>
        r.date.year == now.year &&
        r.date.month == now.month &&
        r.date.day == now.day)) {
      return;
    }
    addWeeklyRecord();
  }

  /// 新增一条周末周报记录
  void addWeeklyRecord() {
    final now = DateTime.now();
    final record = WeeklyRecord(
      id: 'w${now.millisecondsSinceEpoch}',
      date: now,
      bmi: _profile.bmi,
      weeklyBurnCalories: thisWeekBurnCalories,
    );
    _weeklyRecords.add(record);
    // 仅保留最近 12 周
    if (_weeklyRecords.length > 12) {
      _weeklyRecords.removeRange(0, _weeklyRecords.length - 12);
    }
    StorageService.saveWeeklyRecords(_weeklyRecords);
    notifyListeners();
    debugPrint('[AppState] 已记录周末周报: bmi=${record.bmi}, burn=${record.weeklyBurnCalories}');
  }

  // ===================== 动作 =====================

  // ---- 账号 ----
  void login(String phone) {
    _phone = phone;
    _accountState = AccountState.loggedIn;
    StorageService.savePhone(phone);
    StorageService.saveAccountState(_accountState.index);
    notifyListeners();
  }

  /// 绑定飞书 - 传入 App 凭证和 open_id
  void bindFeishu({
    required String name,
    required String appId,
    required String appSecret,
    required String openId,
  }) {
    _feishuName = name;
    _feishuAppId = appId;
    _feishuAppSecret = appSecret;
    _feishuOpenId = openId;
    _accountState = AccountState.boundFeishu;
    _feishuPushEnabled = true;
    StorageService.saveFeishuName(name);
    StorageService.saveFeishuAppId(appId);
    StorageService.saveFeishuAppSecret(appSecret);
    StorageService.saveFeishuOpenId(openId);
    StorageService.saveAccountState(_accountState.index);
    StorageService.saveFeishuPushEnabled(true);
    notifyListeners();
  }

  /// 通过 OAuth 授权码登录飞书
  /// 流程: code → user_access_token → 用户信息(open_id + name) → 绑定
  /// 凭证从本地存储读取(用户在设置页填写),不再使用硬编码
  /// 返回 (success, message)
  Future<(bool success, String message)> loginWithFeishuOAuth(
      String code) async {
    // 1. 从本地存储读取用户配置的凭证
    if (_feishuAppId.isEmpty || _feishuAppSecret.isEmpty) {
      return (false, '请先在上方填写 App ID 和 App Secret 并保存');
    }

    // 2. 用 code 换取 user_access_token
    final userToken = await FeishuService.exchangeCodeForToken(
      code: code,
      appId: _feishuAppId,
      appSecret: _feishuAppSecret,
    );
    if (userToken == null) {
      return (false, '授权码无效或已过期,请重新登录');
    }

    // 3. 获取用户信息
    final userInfo = await FeishuService.getUserInfo(userToken);
    if (userInfo == null) {
      return (false, '获取飞书用户信息失败');
    }

    // 4. 绑定飞书(使用用户本地配置的凭证)
    bindFeishu(
      name: userInfo.name,
      appId: _feishuAppId,
      appSecret: _feishuAppSecret,
      openId: userInfo.openId,
    );

    return (true, '飞书登录成功!提醒将自动推送到飞书');
  }

  /// 通过手机号登录飞书(不依赖 OAuth 重定向 URL)
  /// 流程: 凭证 → tenant_access_token → 手机号查 open_id → 绑定
  /// 适用于 OAuth 重定向 URL 未配置的场景
  /// 返回 (success, message)
  Future<(bool success, String message)> loginWithPhone(String phone) async {
    if (_feishuAppId.isEmpty || _feishuAppSecret.isEmpty) {
      return (false, '请先填写 App ID 和 App Secret 并保存');
    }

    // 1. 获取 tenant_access_token
    final token = await FeishuService.getTenantAccessToken(
      appId: _feishuAppId,
      appSecret: _feishuAppSecret,
    );
    if (token == null) {
      return (false, '获取访问令牌失败,请检查凭证');
    }

    // 2. 通过手机号查询 open_id
    final openId = await FeishuService.getOpenIdByPhone(
      token: token,
      phone: phone,
    );
    if (openId == null) {
      return (false, '未找到该手机号对应的飞书用户,请确认手机号正确且与机器人同租户');
    }

    // 3. 绑定飞书
    bindFeishu(
      name: '飞书用户',
      appId: _feishuAppId,
      appSecret: _feishuAppSecret,
      openId: openId,
    );

    return (true, '飞书登录成功!提醒将自动推送到飞书');
  }

  void unbindFeishu() {
    _feishuName = '';
    _feishuAppId = '';
    _feishuAppSecret = '';
    _feishuOpenId = '';
    _accountState = AccountState.loggedIn;
    _feishuPushEnabled = false;
    StorageService.saveFeishuName('');
    StorageService.saveFeishuAppId('');
    StorageService.saveFeishuAppSecret('');
    StorageService.saveFeishuOpenId('');
    StorageService.saveAccountState(_accountState.index);
    StorageService.saveFeishuPushEnabled(false);
    notifyListeners();
  }

  void logout({required bool keepLocal}) {
    _phone = '';
    _feishuName = '';
    _feishuAppId = '';
    _feishuAppSecret = '';
    _feishuOpenId = '';
    _accountState = AccountState.guest;
    _feishuPushEnabled = false;
    _singleReminders.clear();
    if (!keepLocal) {
      _records.clear();
      StorageService.clearAll();
    } else {
      StorageService.savePhone('');
      StorageService.saveFeishuName('');
      StorageService.saveFeishuAppId('');
      StorageService.saveFeishuAppSecret('');
      StorageService.saveFeishuOpenId('');
      StorageService.saveAccountState(0);
      StorageService.saveFeishuPushEnabled(false);
      StorageService.saveSingleReminders(_singleReminders);
    }
    notifyListeners();
  }

  void enterGuest() {
    _accountState = AccountState.guest;
    StorageService.saveAccountState(0);
    notifyListeners();
  }

  // ---- 全局参数 ----
  void updateProfile(UserProfile profile) {
    _profile = profile;
    StorageService.saveProfile(profile);
    notifyListeners();
  }

  void setDailyGoal(int goal) {
    _profile = _profile.copyWith(dailyGoal: goal);
    StorageService.saveProfile(_profile);
    notifyListeners();
  }

  void setDefaultCup(int cup) {
    _profile = _profile.copyWith(defaultCup: cup);
    StorageService.saveProfile(_profile);
    notifyListeners();
  }

  // ---- 通知权限 ----
  void setNotificationGranted(bool granted) {
    _notificationGranted = granted;
    StorageService.saveNotificationGranted(granted);
    notifyListeners();
  }

  // ---- 提醒 ----
  void setReminderEnabled(bool v) {
    _reminderEnabled = v;
    StorageService.saveReminderEnabled(v);
    notifyListeners();
  }

  void setLoopInterval(int minutes) {
    _loopInterval = minutes;
    StorageService.saveLoopInterval(minutes);
    notifyListeners();
  }

  /// 应用间隔设置(统一入口):保存配置 + 重新注册闹钟 + 立即同步下次提醒时间
  /// 解决「设置后下次提醒时间不刷新」问题:仅在 setLoopInterval 后 UI 不会重读 nextAlarmTime
  /// 本方法等待闹钟注册完成,然后调用 syncReminderCount() 刷新 _nextAlarmTime 字段
  /// 返回 true 表示闹钟注册成功
  Future<bool> applyLoopInterval(int minutes) async {
    _loopInterval = minutes;
    StorageService.saveLoopInterval(minutes);
    notifyListeners();
    // 提醒关闭/暂停时不注册闹钟,但仍刷新 UI 显示
    if (!_reminderEnabled || _reminderPaused) {
      return false;
    }
    final ok = await AlarmService.scheduleLoop(minutes);
    // 立即同步下次提醒时间(从 SharedPreferences 读取 AlarmService 写入的 nextAlarmTime)
    syncReminderCount();
    return ok;
  }

  void addSingleReminder(DateTime time) {
    final r = SingleReminder(
      id: 's${DateTime.now().millisecondsSinceEpoch}',
      time: time,
    );
    _singleReminders.add(r);
    StorageService.saveSingleReminders(_singleReminders);
    notifyListeners();
  }

  void removeSingleReminder(String id) {
    _singleReminders.removeWhere((r) => r.id == id);
    StorageService.saveSingleReminders(_singleReminders);
    notifyListeners();
  }

  void togglePauseToday() {
    _reminderPaused = !_reminderPaused;
    notifyListeners();
  }

  // ---- 飞书 ----
  void setFeishuPushEnabled(bool v) {
    _feishuPushEnabled = v;
    StorageService.saveFeishuPushEnabled(v);
    notifyListeners();
  }

  void setFeishuPushText(String t) {
    _feishuPushText = t;
    StorageService.saveFeishuPushText(t);
    notifyListeners();
  }

  void setFeishuPushFlags({bool? reminder, bool? punch}) {
    if (reminder != null) _feishuPushOnReminder = reminder;
    if (punch != null) _feishuPushOnPunch = punch;
    StorageService.saveFeishuPushFlags(reminder: reminder, punch: punch);
    notifyListeners();
  }

  /// 保存用户填写的飞书机器人凭证(App ID / App Secret)
  /// 如果凭证发生变更,清除旧的 openId,要求用户重新 OAuth 登录
  void saveFeishuCredentials(
      {required String appId, required String appSecret}) {
    final changed = _feishuAppId != appId || _feishuAppSecret != appSecret;
    _feishuAppId = appId;
    _feishuAppSecret = appSecret;
    StorageService.saveFeishuAppId(appId);
    StorageService.saveFeishuAppSecret(appSecret);
    // 凭证变更时清除旧的 openId 和绑定状态
    if (changed && _feishuOpenId.isNotEmpty) {
      _feishuOpenId = '';
      _feishuName = '';
      _accountState = AccountState.loggedIn;
      StorageService.saveFeishuOpenId('');
      StorageService.saveFeishuName('');
      StorageService.saveAccountState(_accountState.index);
    }
    notifyListeners();
  }

  /// 测试飞书连接 - 读取本地凭证尝试获取 token
  /// 返回 (success, message),供 UI 显示成功/失败原因
  Future<(bool success, String message)> testFeishuConnection() async {
    return FeishuService.testConnection(
      appId: _feishuAppId,
      appSecret: _feishuAppSecret,
    );
  }

  /// 发送飞书消息(前台调用)
  /// 返回 (success, message),message 包含失败原因
  Future<(bool success, String message)> sendFeishuMessageWithDetail(
      String text) async {
    if (!isFeishuBound) return (false, '飞书未绑定,请先登录');
    if (_feishuAppId.isEmpty || _feishuAppSecret.isEmpty) {
      return (false, 'App ID/Secret 未配置');
    }
    if (_feishuOpenId.isEmpty) {
      return (false, 'openId 为空,请重新登录飞书绑定');
    }
    final token = await FeishuService.getTenantAccessToken(
      appId: _feishuAppId,
      appSecret: _feishuAppSecret,
    );
    if (token == null) {
      return (false, '获取 token 失败,请检查 App ID/Secret 是否正确');
    }
    return FeishuService.sendMessageWithDetail(
      token: token,
      openId: _feishuOpenId,
      text: text,
    );
  }

  /// 发送飞书消息(简化版,仅返回 bool)
  Future<bool> sendFeishuMessage(String text) async {
    final result = await sendFeishuMessageWithDetail(text);
    return result.$1;
  }

  // ---- 免打扰 ----
  void setNightDnd(bool v) {
    _nightDnd = v;
    StorageService.saveNightDnd(v);
    notifyListeners();
  }

  void setNoonDnd(bool v) {
    _noonDnd = v;
    StorageService.saveNoonDnd(v);
    notifyListeners();
  }

  /// 标记已弹过午休免打扰询问(首启时调用一次)
  void markNoonDndPrompted() {
    _hasPromptedNoonDnd = true;
    StorageService.saveHasPromptedNoonDnd(true);
    notifyListeners();
  }

  // ---- 喝水记录 ----
  void addRecord(int amount) {
    _records.insert(
        0,
        WaterRecord(
          id: 'r${DateTime.now().millisecondsSinceEpoch}',
          time: DateTime.now(),
          amount: amount,
        ));
    StorageService.saveRecords(_records);
    notifyListeners();
  }

  void removeRecord(String id) {
    _records.removeWhere((r) => r.id == id);
    StorageService.saveRecords(_records);
    notifyListeners();
  }

  void undoLastRecord() {
    if (_records.isNotEmpty) {
      _records.removeAt(0);
      StorageService.saveRecords(_records);
      notifyListeners();
    }
  }

  void setRememberSyncFeishu(bool v) {
    _rememberSyncToFeishu = v;
    StorageService.saveRememberSyncFeishu(v);
    notifyListeners();
  }

  // ---- 饮食/运动记录 ----
  void addFoodRecord(FoodRecord record) {
    _foodRecords.insert(0, record);
    StorageService.saveFoodRecords(_foodRecords);
    notifyListeners();
  }

  void removeFoodRecord(String id) {
    _foodRecords.removeWhere((r) => r.id == id);
    StorageService.saveFoodRecords(_foodRecords);
    notifyListeners();
  }

  void addExerciseRecord(ExerciseRecord record) {
    _exerciseRecords.insert(0, record);
    StorageService.saveExerciseRecords(_exerciseRecords);
    notifyListeners();
  }

  void removeExerciseRecord(String id) {
    _exerciseRecords.removeWhere((r) => r.id == id);
    StorageService.saveExerciseRecords(_exerciseRecords);
    notifyListeners();
  }

  /// 强制刷新 AI 相关数据(API Key 变更后调用)
  void refreshAiData() {
    notifyListeners();
  }

  /// 当前是否处于免打扰时段
  bool get inDndPeriod {
    final now = DateTime.now();
    final hm = now.hour * 60 + now.minute;
    if (_nightDnd && (hm >= 22 * 60 || hm < 8 * 60)) return true;
    // 午休免打扰:12:30 ~ 14:30
    if (_noonDnd && hm >= 12 * 60 + 30 && hm < 14 * 60 + 30) return true;
    return false;
  }

  /// 当前免打扰状态描述(供 UI 显示)
  String get dndStatusText {
    final now = DateTime.now();
    final hm = now.hour * 60 + now.minute;
    if (_nightDnd && (hm >= 22 * 60 || hm < 8 * 60)) return '夜间免打扰';
    if (_noonDnd && hm >= 12 * 60 + 30 && hm < 14 * 60 + 30) return '午休免打扰';
    return '';
  }

  // ===================== 统计辅助 =====================

  /// 指定日期的记录总量(ml)
  int totalForDay(DateTime day) {
    return _records
        .where((r) =>
            r.time.year == day.year &&
            r.time.month == day.month &&
            r.time.day == day.day)
        .fold(0, (s, r) => s + r.amount);
  }

  /// 最近 n 天的每日总量,返回从旧到新的列表
  List<DailyTotal> lastNDays(int n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(n, (i) {
      final day = today.subtract(Duration(days: n - 1 - i));
      return DailyTotal(day: day, total: totalForDay(day));
    });
  }

  /// 最近 n 天中达成目标的天数
  int goalHitDays(int n) {
    return lastNDays(n).where((d) => d.total >= _profile.dailyGoal).length;
  }

  /// 最近 n 天中有打卡记录的天数(不论是否达标)
  int punchDays(int n) {
    return lastNDays(n).where((d) => d.total > 0).length;
  }

  /// 最近 n 天中连续打卡的天数(从今天往前数)
  int continuousPunchDays() {
    final list = lastNDays(60);
    int count = 0;
    for (int i = list.length - 1; i >= 0; i--) {
      if (list[i].total > 0) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// 最近 n 天的日均 ml
  double averageDaily(int n) {
    final list = lastNDays(n);
    if (list.isEmpty) return 0;
    return list.fold(0, (s, d) => s + d.total) / list.length;
  }
}

/// 某日总量(统计用)
class DailyTotal {
  final DateTime day;
  final int total;
  const DailyTotal({required this.day, required this.total});
}
