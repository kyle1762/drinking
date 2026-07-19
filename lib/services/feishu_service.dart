import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'feishu_config.dart';

/// 飞书 API 服务
/// 负责 OAuth 授权、获取 user_access_token、查询用户信息、发送消息
/// 所有凭证(App ID/Secret)均由调用方传入,从本地存储动态读取,不再使用硬编码
/// 支持前台和后台 isolate 调用
class FeishuService {
  static const _baseUrl = 'https://open.feishu.cn/open-apis';

  // ============ OAuth 流程 ============

  /// 用授权码 code 换取 user_access_token
  /// [appId]/[appSecret] 由调用方从本地存储读取后传入
  /// 返回 token 字符串,失败返回 null
  /// 注意:v2 接口返回标准 OAuth 2.0 格式,access_token 在根层级
  /// 成功: { access_token, token_type, expires_in, refresh_token, open_id, ... }
  /// 失败: { error, error_description }
  static Future<String?> exchangeCodeForToken({
    required String code,
    required String appId,
    required String appSecret,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/authen/v2/oauth/token'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'grant_type': 'authorization_code',
          'client_id': appId,
          'client_secret': appSecret,
          'code': code,
          'redirect_uri': FeishuConfig.redirectUri,
        }),
      );
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data.containsKey('error')) return null;
      return data['access_token'] as String?;
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

  /// 获取 tenant_access_token(用用户配置的凭证)
  /// [appId]/[appSecret] 必填,由调用方从本地存储读取后传入
  /// 返回 token 字符串,失败返回 null
  /// 增加 10s 超时控制,防止后台 isolate 永久阻塞
  static Future<String?> getTenantAccessToken({
    required String appId,
    required String appSecret,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/auth/v3/tenant_access_token/internal'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'app_id': appId, 'app_secret': appSecret}),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint(
          '[FeishuToken] statusCode=${resp.statusCode}, body=${resp.body}');
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['code'] != 0) {
        debugPrint(
            '[FeishuToken] 获取失败: code=${data['code']}, msg=${data['msg']}');
        return null;
      }
      return data['tenant_access_token'] as String?;
    } catch (e) {
      debugPrint('[FeishuToken] 异常: $e');
      return null;
    }
  }

  /// 测试飞书连接 - 用于设置页「测试连接」按钮
  /// 读取本地凭证,尝试获取一次 tenant_access_token
  /// 返回 (success, message):成功提示「飞书连接成功」,失败给出具体原因
  static Future<(bool success, String message)> testConnection({
    required String appId,
    required String appSecret,
  }) async {
    if (appId.isEmpty || appSecret.isEmpty) {
      return (false, '请先填写 App ID 和 App Secret');
    }
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/auth/v3/tenant_access_token/internal'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'app_id': appId, 'app_secret': appSecret}),
      );
      if (resp.statusCode != 200) {
        return (false, '网络错误: HTTP ${resp.statusCode}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final code = data['code'];
      if (code == 0 && data['tenant_access_token'] != null) {
        return (true, '飞书连接成功');
      }
      // 飞书错误码: 99773=App ID 不存在, 99991663=App Secret 错误
      final msg = data['msg'] as String? ?? '未知错误';
      return (false, '凭证错误: $msg (code: $code)');
    } catch (e) {
      return (false, '网络异常: $e');
    }
  }

  /// 通过手机号查询用户 open_id
  /// 适用于 OAuth 重定向 URL 未配置的场景
  /// [phone] 需为不带国家码的手机号(如 13800138000)
  /// 返回 open_id 字符串,失败返回 null
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
        body: jsonEncode({
          'mobiles': [phone]
        }),
      );
      debugPrint(
          '[FeishuPhone] statusCode=${resp.statusCode}, body=${resp.body}');
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['code'] != 0) {
        debugPrint(
            '[FeishuPhone] 查询失败: code=${data['code']}, msg=${data['msg']}');
        return null;
      }
      final userList = data['data']?['user_list'] as List?;
      if (userList == null || userList.isEmpty) {
        debugPrint('[FeishuPhone] user_list 为空');
        return null;
      }
      // 飞书 v3 batch_get_id 返回的 user_list 元素直接包含 open_id 字段
      // 格式: [{ "user_id": "...", "open_id": "ou_xxx", "mobile": "..." }]
      // 注意: 不是嵌套在 'user' 字段里
      final openId = userList[0]['open_id'] as String?;
      if (openId == null || openId.isEmpty) {
        debugPrint('[FeishuPhone] open_id 为空, user_list[0]=${userList[0]}');
      }
      return openId;
    } catch (e) {
      debugPrint('[FeishuPhone] 异常: $e');
      return null;
    }
  }

  /// 发送文本消息给指定用户
  /// 返回 (success, message),message 包含失败原因
  /// 增加 10s 超时控制,防止网络异常时永久阻塞后台 isolate
  static Future<(bool success, String message)> sendMessageWithDetail({
    required String token,
    required String openId,
    required String text,
  }) async {
    try {
      final resp = await http
          .post(
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
          )
          .timeout(const Duration(seconds: 10));
      debugPrint(
          '[FeishuMsg] statusCode=${resp.statusCode}, body=${resp.body}');
      if (resp.statusCode != 200) {
        // 尝试解析 body 获取飞书错误信息
        try {
          final errData = jsonDecode(resp.body) as Map<String, dynamic>;
          final errMsg = errData['msg'] as String? ?? '';
          return (false, 'HTTP ${resp.statusCode}: $errMsg');
        } catch (_) {
          return (false, 'HTTP ${resp.statusCode}');
        }
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final code = data['code'];
      if (code == 0) {
        return (true, '发送成功');
      }
      // 常见错误码翻译
      final msg = data['msg'] as String? ?? '未知错误';
      return (false, 'code:$code $msg');
    } catch (e) {
      return (false, '异常: $e');
    }
  }

  /// 发送文本消息给指定用户(简化版,仅返回 bool)
  static Future<bool> sendMessage({
    required String token,
    required String openId,
    required String text,
  }) async {
    final result =
        await sendMessageWithDetail(token: token, openId: openId, text: text);
    return result.$1;
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

  /// 后台闹钟触发时调用:发送飞书消息
  /// DND/时段/重复周期检查已由 NotificationService.onAlarmFired 完成
  /// 本方法仅负责凭证检查和消息发送,全程不依赖 AppState/Provider
  ///
  /// 增强可靠性(解决「经常性推送失败」问题):
  /// - HTTP 请求全部带 10s 超时,避免后台 isolate 永久阻塞
  /// - token 失效或发送失败时自动重试,最多 3 次,间隔递增(2s/4s/6s)
  /// - token 失效(code 99991663/99991661 等)时强制重新获取 token
  /// - 详细记录每次失败原因到日志
  static Future<void> pushReminderFromBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // reload() 确保后台 isolate 读到主 isolate 最新写入的配置
      await prefs.reload();

      // 1. 检查推送是否开启(默认 true,避免旧版本升级后值缺失导致推送失效)
      final pushEnabled = prefs.getBool(_kFeishuPushEnabled) ?? true;
      if (!pushEnabled) {
        debugPrint('[FeishuPush] 推送已关闭,跳过');
        return;
      }

      // 2. 检查提醒时推送是否开启
      final pushOnReminder = prefs.getBool(_kFeishuPushOnReminder) ?? true;
      if (!pushOnReminder) {
        debugPrint('[FeishuPush] 提醒推送已关闭,跳过');
        return;
      }

      // 3. 获取凭证(仅使用用户本地配置)
      final appId = prefs.getString(_kFeishuAppId);
      final appSecret = prefs.getString(_kFeishuAppSecret);
      final openId = prefs.getString(_kFeishuOpenId);
      if (appId == null || appId.isEmpty) {
        debugPrint('[FeishuPush] appId 缺失,跳过');
        return;
      }
      if (appSecret == null || appSecret.isEmpty) {
        debugPrint('[FeishuPush] appSecret 缺失,跳过');
        return;
      }
      if (openId == null || openId.isEmpty) {
        debugPrint('[FeishuPush] openId 缺失,跳过');
        return;
      }

      // 4. 构建消息(含今日统计)
      final message = _buildReminderMessage(prefs);

      // 5. 获取 token 并发送,最多重试 3 次,间隔递增
      // 重试场景:网络异常、token 获取失败、token 失效、发送 HTTP 非 200
      const maxRetries = 3;
      const retryDelays = [Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 6)];
      String? token = await getTenantAccessToken(appId: appId, appSecret: appSecret);
      if (token == null) {
        debugPrint('[FeishuPush] 首次获取 token 失败');
      }

      for (int attempt = 0; attempt < maxRetries; attempt++) {
        if (token == null) {
          // token 获取失败时等待后重试
          if (attempt < maxRetries - 1) {
            debugPrint('[FeishuPush] ${attempt + 1}/$maxRetries 等待 ${retryDelays[attempt].inSeconds}s 后重新获取 token');
            await Future.delayed(retryDelays[attempt]);
            token = await getTenantAccessToken(appId: appId, appSecret: appSecret);
          }
          continue;
        }

        debugPrint('[FeishuPush] 第 ${attempt + 1}/$maxRetries 次发送消息...');
        final result = await sendMessageWithDetail(
          token: token,
          openId: openId,
          text: message,
        );

        if (result.$1) {
          debugPrint('[FeishuPush] 发送成功(第 ${attempt + 1} 次尝试)');
          return;
        }

        final errMsg = result.$2;
        debugPrint('[FeishuPush] 第 ${attempt + 1} 次发送失败: $errMsg');

        // 判断是否 token 失效(需要重新获取)
        // 飞书 token 失效错误码: 99991663(token 无效)、99991661(token 过期)、99991664(token 已被吊销)
        final tokenInvalid = errMsg.contains('99991663') ||
            errMsg.contains('99991661') ||
            errMsg.contains('99991664') ||
            errMsg.contains('token') ||
            errMsg.contains('Token');

        // 判断是否 open_id 不存在或权限不足(这类错误重试无意义,直接放弃)
        final openIdInvalid = errMsg.contains('230001') ||
            errMsg.contains('230002') ||
            errMsg.contains('open_id') ||
            errMsg.contains('receive_id');

        if (openIdInvalid) {
          debugPrint('[FeishuPush] open_id 错误或权限不足,放弃推送: $errMsg');
          return;
        }

        if (attempt < maxRetries - 1) {
          if (tokenInvalid) {
            debugPrint('[FeishuPush] token 失效,等待 ${retryDelays[attempt].inSeconds}s 后重新获取');
            await Future.delayed(retryDelays[attempt]);
            token = await getTenantAccessToken(appId: appId, appSecret: appSecret);
          } else {
            debugPrint('[FeishuPush] 等待 ${retryDelays[attempt].inSeconds}s 后重试');
            await Future.delayed(retryDelays[attempt]);
          }
        }
      }

      debugPrint('[FeishuPush] 已达最大重试次数,放弃推送');
    } catch (e, st) {
      debugPrint('[FeishuPush] 推送异常: $e\n$st');
    }
  }

  /// 构建提醒消息,包含今日喝水统计
  static String _buildReminderMessage(SharedPreferences prefs) {
    final pushText = prefs.getString(_kFeishuPushText) ?? '到时间啦~ 起身动动,接杯水喝一口吧';

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

  /// 检查飞书是否已配置完整(用于 UI 判断)
  /// 仅检查本地是否已保存 App ID / Secret / open_id
  static Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    final appId = prefs.getString(_kFeishuAppId);
    final appSecret = prefs.getString(_kFeishuAppSecret);
    final openId = prefs.getString(_kFeishuOpenId);
    return appId != null &&
        appId.isNotEmpty &&
        appSecret != null &&
        appSecret.isNotEmpty &&
        openId != null &&
        openId.isNotEmpty;
  }
}
