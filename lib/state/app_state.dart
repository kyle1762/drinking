import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

/// 全局状态 - 单一数据源(安卓ViewModel统一数据源)
/// 三页面共享:账号三态、全局参数单向同步、提醒/记录/飞书配置
/// 所有状态变更均持久化到 SharedPreferences,App 重启不丢失
class AppState extends ChangeNotifier {
  AppState() {
    _loadFromStorage();
  }

  // ============ 账号三态 ============
  AccountState _accountState = AccountState.guest;
  String _phone = '';
  String _feishuName = '';

  AccountState get accountState => _accountState;
  bool get isGuest => _accountState == AccountState.guest;
  bool get isLoggedIn => _accountState != AccountState.guest;
  bool get isFeishuBound => _accountState == AccountState.boundFeishu;
  String get phone => _phone;
  String get feishuName => _feishuName;

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

  /// 今日已提醒次数(运行时累计,重启归零)
  int _todayReminderCount = 0;
  int get todayReminderCount => _todayReminderCount;
  void incrementReminderCount() {
    _todayReminderCount++;
    notifyListeners();
  }

  /// 下次提醒时间
  String get nextReminderTime {
    if (!_reminderEnabled || _reminderPaused) return '已暂停';
    final now = DateTime.now();
    final next = now.add(Duration(minutes: _loopInterval));
    return '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';
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
  String _feishuPushText = '该喝水啦,记得补充水分~';
  bool _feishuPushOnReminder = true;
  bool _feishuPushOnPunch = false;

  bool get feishuPushEnabled => _feishuPushEnabled;
  String get feishuPushText => _feishuPushText;
  bool get feishuPushOnReminder => _feishuPushOnReminder;
  bool get feishuPushOnPunch => _feishuPushOnPunch;

  // ============ 免打扰 ============
  bool _nightDnd = true;
  bool _noonDnd = true;
  int? _focusMinutes; // 专注模式剩余分钟,null=未开启

  bool get nightDnd => _nightDnd;
  bool get noonDnd => _noonDnd;
  bool get focusModeActive => _focusMinutes != null;
  int? get focusMinutes => _focusMinutes;

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

  // ============ 同步至飞书打卡记忆 ============
  bool _rememberSyncToFeishu = true;

  bool get rememberSyncToFeishu => _rememberSyncToFeishu;

  // ===================== 持久化加载 =====================

  void _loadFromStorage() {
    final d = StorageService.loadAll();
    _accountState = AccountState.values[d.accountStateIndex.clamp(0, 2)];
    _phone = d.phone;
    _feishuName = d.feishuName;
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
    _rememberSyncToFeishu = d.rememberSyncFeishu;
    // 仅加载最近 60 天的记录,避免无限增长
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    _records
      ..clear()
      ..addAll(d.records.where((r) => r.time.isAfter(cutoff)));
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

  void bindFeishu(String name) {
    _feishuName = name;
    _accountState = AccountState.boundFeishu;
    _feishuPushEnabled = true;
    StorageService.saveFeishuName(name);
    StorageService.saveAccountState(_accountState.index);
    StorageService.saveFeishuPushEnabled(true);
    notifyListeners();
  }

  void unbindFeishu() {
    _feishuName = '';
    _accountState = AccountState.loggedIn;
    _feishuPushEnabled = false;
    StorageService.saveFeishuName('');
    StorageService.saveAccountState(_accountState.index);
    StorageService.saveFeishuPushEnabled(false);
    notifyListeners();
  }

  void logout({required bool keepLocal}) {
    _phone = '';
    _feishuName = '';
    _accountState = AccountState.guest;
    _feishuPushEnabled = false;
    _singleReminders.clear();
    if (!keepLocal) {
      _records.clear();
      StorageService.clearAll();
    } else {
      StorageService.savePhone('');
      StorageService.saveFeishuName('');
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

  /// 当前是否处于免打扰时段
  bool get inDndPeriod {
    final now = DateTime.now();
    final hm = now.hour * 60 + now.minute;
    if (_nightDnd && (hm >= 22 * 60 || hm < 7 * 60)) return true;
    if (_noonDnd && hm >= 12 * 60 + 30 && hm < 13 * 60 + 30) return true;
    if (_focusMinutes != null) return true;
    return false;
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
