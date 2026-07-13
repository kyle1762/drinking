import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'feishu_config.dart';

/// 飞书 API 服务
/// 负责 OAuth 授权、获取 user_access_token、查询用户信息、发送消息
/// 支持前台和后台 isolate 调用
class FeishuService {
  static const _baseUrl = 'https://open.feishu.cn/open-apis';

  // ============ OAuth 流程 ============

  /// 用授权码 code 换取 user_access_token
  /// 返回 token 字符串,失败返回 null
  static Future<String?> exchangeCodeForToken(String code) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/authen/v2/oauth/token'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'grant_type': 'authorization_code',
          'client_id': FeishuConfig.appId,
          'client_secret': FeishuConfig.appSecret,
          'code': code,
          'redirect_uri': FeishuConfig.redirectUri,
        }),
      );
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['code'] != 0) return null;
      return data['data']?['access_token'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 通过 user_access_token 获取用户信息(含 open_id 和姓名)
  /// 返回 (open_id, name),失败返回 null
  static Future<({String openId, String name})?> getUserInfo(
      String userAccessToken) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/authen/v1/user_info'),
        headers: {'Authorization': 'Bearer $userAccessToken'},
      );
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['code'] != 0) return null;
      final openId = data['data']?['open_id'] as String?;
      final name = data['data']?['name'] as String? ?? '飞书用户';
      if (openId == null) return null;
      return (openId: openId, name: name);
    } catch (_) {
      return null;
    }
  }

  // ============ 消息发送 ============

  /// 获取 tenant_access_token(用预置凭证)
  /// 返回 token 字符串,失败返回 null
  static Future<String?> getTenantAccessToken({
    String? appId,
    String? appSecret,
  }) async {
    final aid = appId ?? FeishuConfig.appId;
    final asec = appSecret ?? FeishuConfig.appSecret;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/auth/v3/tenant_access_token/internal'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'app_id': aid, 'app_secret': asec}),
      );
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['code'] != 0) return null;
      return data['tenant_access_token'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 通过手机号查询用户 open_id(兼容旧流程)
  static Future<String?> getOpenIdByPhone({
    required String token,
    required String phone,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/contact/v3/users/batch_get_id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'mobiles': [phone]}),
      );
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['code'] != 0) return null;
      final userList = data['data']?['user_list'] as List?;
      if (userList == null || userList.isEmpty) return null;
      return userList[0]['user']?['open_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 发送文本消息给指定用户
  /// 返回是否发送成功
  static Future<bool> sendMessage({
    required String token,
    required String openId,
    required String text,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/im/v1/messages?receive_id_type=open_id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'receive_id': openId,
          'msg_type': 'text',
          'content': jsonEncode({'text': text}),
        }),
      );
      if (resp.statusCode != 200) return false;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  // ============ 后台 isolate 专用 ============

  /// SharedPreferences key 常量(与 StorageService 保持一致)
  static const _kFeishuAppId = 'feishuAppId';
  static const _kFeishuAppSecret = 'feishuAppSecret';
  static const _kFeishuOpenId = 'feishuOpenId';
  static const _kFeishuPushEnabled = 'feishuPushEnabled';
  static const _kFeishuPushText = 'feishuPushText';
  static const _kFeishuPushOnReminder = 'feishuPushOnReminder';
  static const _kRecords = 'records';
  static const _kProfile = 'profile';
  static const _kNightDnd = 'nightDnd';
  static const _kNoonDnd = 'noonDnd';
  static const _kRangeStart = 'rangeStart';
  static const _kRangeEnd = 'rangeEnd';
  static const _kRepeat = 'repeat';

  /// 后台闹钟触发时调用:检查免打扰/时段,发送飞书消息
  /// 全程不依赖 AppState/Provider,可在后台 isolate 中运行
  static Future<void> pushReminderFromBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. 检查推送是否开启
      final pushEnabled = prefs.getBool(_kFeishuPushEnabled) ?? false;
      if (!pushEnabled) return;

      // 2. 检查提醒时推送是否开启
      final pushOnReminder = prefs.getBool(_kFeishuPushOnReminder) ?? true;
      if (!pushOnReminder) return;

      // 3. 免打扰检查
      if (_isInDndPeriod(prefs)) return;

      // 4. 提醒时段检查
      if (!_isInRangeTime(prefs)) return;

      // 5. 重复周期检查
      if (!_isRepeatDay(prefs)) return;

      // 6. 获取凭证
      String? appId = prefs.getString(_kFeishuAppId);
      String? appSecret = prefs.getString(_kFeishuAppSecret);
      // 若未保存用户凭证,尝试使用预置凭证
      appId ??= FeishuConfig.appId != 'YOUR_APP_ID' ? FeishuConfig.appId : null;
      appSecret ??= FeishuConfig.appSecret != 'YOUR_APP_SECRET'
          ? FeishuConfig.appSecret
          : null;

      final openId = prefs.getString(_kFeishuOpenId);
      if (appId == null || appSecret == null || openId == null) return;

      // 7. 构建消息(含今日统计)
      final message = _buildReminderMessage(prefs);

      // 8. 获取 token 并发送(带一次重试)
      String? token = await getTenantAccessToken(appId: appId, appSecret: appSecret);
      if (token == null) {
        await Future.delayed(const Duration(seconds: 2));
        token = await getTenantAccessToken(appId: appId, appSecret: appSecret);
      }
      if (token == null) return;

      await sendMessage(token: token, openId: openId, text: message);
    } catch (_) {
      // 后台静默失败,不影响本地通知
    }
  }

  /// 构建提醒消息,包含今日喝水统计
  static String _buildReminderMessage(SharedPreferences prefs) {
    final pushText =
        prefs.getString(_kFeishuPushText) ?? '该喝水啦,记得补充水分~';

    // 读取今日统计
    final (todayTotal, todayGoal) = _loadTodayStats(prefs);
    final rate = todayGoal > 0 ? (todayTotal * 100 ~/ todayGoal) : 0;
    final remaining = todayGoal > todayTotal ? todayGoal - todayTotal : 0;

    return '$pushText\n\n'
        '今日已喝 ${todayTotal}ml / 目标 ${todayGoal}ml\n'
        '完成率 $rate%${remaining > 0 ? ',还差 ${remaining}ml' : ',已达标~'}';
  }

  /// 从 SharedPreferences 读取记录并计算今日统计
  static (int total, int goal) _loadTodayStats(SharedPreferences prefs) {
    // 读取每日目标
    int goal = 2000;
    final profileStr = prefs.getString(_kProfile);
    if (profileStr != null) {
      try {
        final p = jsonDecode(profileStr) as Map<String, dynamic>;
        goal = (p['dailyGoal'] as num?)?.toInt() ?? 2000;
      } catch (_) {}
    }

    // 读取记录并计算今日总量
    int total = 0;
    final recordsStr = prefs.getString(_kRecords);
    if (recordsStr != null) {
      try {
        final list = jsonDecode(recordsStr) as List;
        final now = DateTime.now();
        for (final e in list) {
          final r = e as Map<String, dynamic>;
          final timeStr = r['time'] as String?;
          if (timeStr == null) continue;
          try {
            final time = DateTime.parse(timeStr);
            if (time.year == now.year &&
                time.month == now.month &&
                time.day == now.day) {
              total += (r['amount'] as num?)?.toInt() ?? 0;
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    return (total, goal);
  }

  /// 检查当前是否处于免打扰时段
  static bool _isInDndPeriod(SharedPreferences prefs) {
    final nightDnd = prefs.getBool(_kNightDnd) ?? true;
    final noonDnd = prefs.getBool(_kNoonDnd) ?? true;

    final now = DateTime.now();
    final hm = now.hour * 60 + now.minute;

    // 夜间免打扰 22:00 - 7:00
    if (nightDnd && (hm >= 22 * 60 || hm < 7 * 60)) return true;
    // 午间免打扰 12:30 - 13:30
    if (noonDnd && hm >= 12 * 60 + 30 && hm < 13 * 60 + 30) return true;

    return false;
  }

  /// 检查当前是否在提醒生效时段内
  static bool _isInRangeTime(SharedPreferences prefs) {
    final start = prefs.getString(_kRangeStart) ?? '08:00';
    final end = prefs.getString(_kRangeEnd) ?? '21:00';

    final startParts = start.split(':');
    final endParts = end.split(':');
    if (startParts.length != 2 || endParts.length != 2) return true;

    final startMin = int.tryParse(startParts[0])! * 60 + int.tryParse(startParts[1])!;
    final endMin = int.tryParse(endParts[0])! * 60 + int.tryParse(endParts[1])!;

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    return nowMin >= startMin && nowMin <= endMin;
  }

  /// 检查今天是否属于重复周期
  static bool _isRepeatDay(SharedPreferences prefs) {
    final repeatIndex = prefs.getInt(_kRepeat) ?? 0; // 0=每天 1=工作日 2=周末
    final weekday = DateTime.now().weekday; // 1=周一 7=周日

    switch (repeatIndex) {
      case 0:
        return true; // 每天
      case 1:
        return weekday <= 5; // 工作日
      case 2:
        return weekday >= 6; // 周末
      default:
        return true;
    }
  }

  /// 检查飞书是否已配置完整(用于 UI 判断)
  static Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    final hasStored = prefs.getString(_kFeishuOpenId) != null;
    final hasPreset = FeishuConfig.isConfigured;
    return hasStored || hasPreset;
  }
}
