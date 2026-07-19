import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/feishu_service.dart';
import '../services/alarm_service.dart';

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
  bool _isLoopTab = true; // 循环/单次标签
  int _loopInterval = 60; // 分钟
  final List<SingleReminder> _singleReminders = [];
  String _rangeStart = '08:00';
  String _rangeEnd = '21:00';
  RepeatCycle _repeat = RepeatCycle.daily;
  bool _reminderPaused = false;

  bool get reminderEnabled => _reminderEnabled;
  bool get isLoopTab => _isLoopTab;
  int get loopInterval => _loopInterval;
  List<SingleReminder> get singleReminders =>
      List.unmodifiable(_singleReminders);
  String get rangeStart => _rangeStart;
  String get rangeEnd => _rangeEnd;
  RepeatCycle get repeat => _repeat;
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
      final savedDateStr = prefs.getString('todayReminderDate');
      final count = prefs.getInt('todayReminderCount') ?? 0;
      final lastStr = prefs.getString('lastReminderTime');
      final nextStr = prefs.getString('nextAlarmTime');

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

  /// 喝水动画触发计数器 - 每次 addRecord 自增,小人组件监听此值触发喝水动画
  int _drinkPulse = 0;
  int get drinkPulse => _drinkPulse;

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

  // ============ 耳机专属设置 ============
  bool _earphoneEnabled = true;
  SoundType _sound = SoundType.flow;
  double _earphoneVolume = 0.6;
  bool _earphoneConnected = false;

  bool get earphoneEnabled => _earphoneEnabled;
  SoundType get sound => _sound;
  double get earphoneVolume => _earphoneVolume;
  bool get earphoneConnected => _earphoneConnected;

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
  int? _focusMinutes; // 专注模式剩余分钟,null=未开启

  bool get nightDnd => _nightDnd;
  bool get noonDnd => _noonDnd;
  bool get hasPromptedNoonDnd => _hasPromptedNoonDnd;
  bool get focusModeActive => _focusMinutes != null;
  int? get focusMinutes => _focusMinutes;

  // ============ 扬声器提醒 ============
  /// 是否通过手机扬声器播放提醒音效(用户可自行关闭)
  bool _speakerEnabled = true;
  bool get speakerEnabled => _speakerEnabled;

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

  List<FoodRecord> get foodRecords => List.unmodifiable(_foodRecords);
  List<ExerciseRecord> get exerciseRecords =>
      List.unmodifiable(_exerciseRecords);

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
    _isLoopTab = d.isLoopTab;
    _loopInterval = d.loopInterval;
    _singleReminders
      ..clear()
      ..addAll(d.singleReminders.where((r) => !r.isExpired));
    _rangeStart = d.rangeStart;
    _rangeEnd = d.rangeEnd;
    _repeat = RepeatCycle.values[d.repeatIndex.clamp(0, 2)];
    _earphoneEnabled = d.earphoneEnabled;
    _sound = d.sound;
    _earphoneVolume = d.earphoneVolume;
    _feishuPushEnabled = d.feishuPushEnabled;
    _feishuPushText = d.feishuPushText;
    _feishuPushOnReminder = d.feishuPushOnReminder;
    _feishuPushOnPunch = d.feishuPushOnPunch;
    _nightDnd = d.nightDnd;
    _noonDnd = d.noonDnd;
    _hasPromptedNoonDnd = d.hasPromptedNoonDnd;
    _speakerEnabled = d.speakerEnabled;
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

  void setLoopTab(bool v) {
    _isLoopTab = v;
    StorageService.saveIsLoopTab(v);
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

  void setRange(String start, String end) {
    _rangeStart = start;
    _rangeEnd = end;
    StorageService.saveRange(start, end);
    notifyListeners();
  }

  void setRepeat(RepeatCycle r) {
    _repeat = r;
    StorageService.saveRepeat(r.index);
    notifyListeners();
  }

  /// 智能作息填充 - 读取账号页作息
  void applyScheduleFromProfile() {
    _rangeStart = _profile.wakeTime;
    _rangeEnd = _profile.bedTime;
    StorageService.saveRange(_rangeStart, _rangeEnd);
    notifyListeners();
  }

  void togglePauseToday() {
    _reminderPaused = !_reminderPaused;
    notifyListeners();
  }

  // ---- 耳机 ----
  void setEarphoneEnabled(bool v) {
    _earphoneEnabled = v;
    StorageService.saveEarphoneEnabled(v);
    notifyListeners();
  }

  void setSound(SoundType s) {
    _sound = s;
    StorageService.saveSound(s.name);
    notifyListeners();
  }

  void setEarphoneVolume(double v) {
    _earphoneVolume = v;
    StorageService.saveEarphoneVolume(v);
    notifyListeners();
  }

  void setEarphoneConnected(bool v) {
    _earphoneConnected = v;
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

  // ---- 扬声器提醒 ----
  void setSpeakerEnabled(bool v) {
    _speakerEnabled = v;
    StorageService.saveSpeakerEnabled(v);
    notifyListeners();
  }

  void startFocusMode(int minutes) {
    _focusMinutes = minutes;
    notifyListeners();
  }

  void stopFocusMode() {
    _focusMinutes = null;
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
    _drinkPulse++;
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
      _drinkPulse++;
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
    if (_nightDnd && (hm >= 22 * 60 || hm < 7 * 60)) return true;
    // 午休免打扰:12:30 ~ 14:30
    if (_noonDnd && hm >= 12 * 60 + 30 && hm < 14 * 60 + 30) return true;
    if (_focusMinutes != null) return true;
    return false;
  }

  /// 当前免打扰状态描述(供 UI 显示)
  String get dndStatusText {
    final now = DateTime.now();
    final hm = now.hour * 60 + now.minute;
    if (_focusMinutes != null) return '专注模式中';
    if (_nightDnd && (hm >= 22 * 60 || hm < 7 * 60)) return '夜间免打扰';
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
