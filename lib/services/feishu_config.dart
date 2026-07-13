/// 飞书应用配置
///
/// 使用前需在飞书开放平台创建自建应用:
/// 1. 访问 https://open.feishu.cn/app 创建自建应用
/// 2. 开启「机器人」能力
/// 3. 权限管理 → 开通:im:message, contact:user.base:readonly
/// 4. 安全设置 → 重定向 URL 添加: drinking://oauth/callback
/// 5. 将下方 appId / appSecret 替换为你的应用凭证
class FeishuConfig {
  FeishuConfig._();

  // ============ 填入你的飞书应用凭证 ============
  // 从 https://open.feishu.cn/app → 你的应用 → 凭证与基础信息 获取
  static const String appId = 'cli_aad936fa2d789bee';
  static const String appSecret = 'C4ONLJZcfEodu8WJlyTNLelAKp1ZeBtx';

  // ============ OAuth 回调地址 ============
  // 需在飞书应用「安全设置 → 重定向 URL」中添加此地址
  // 此地址无需真实存在,App 内 WebView 会拦截跳转并提取 code
  static const String redirectUri = 'https://drinking.example.com/oauth/callback';

  // ============ OAuth 授权范围 ============
  static const List<String> scopes = [
    'contact:user.base:readonly', // 获取用户 open_id
    'im:message', // 发送消息
  ];

  /// 判断凭证是否已配置
  static bool get isConfigured =>
      appId != 'YOUR_APP_ID' && appSecret != 'YOUR_APP_SECRET';

  /// 构建 OAuth 授权 URL
  /// 注意:授权页面域名是 accounts.feishu.cn,不是 open.feishu.cn
  static String buildOAuthUrl() {
    final scope = scopes.join(' ');
    final params = <String, String>{
      'client_id': appId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': scope,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'https://accounts.feishu.cn/open-apis/authen/v1/authorize?$query';
  }
}
