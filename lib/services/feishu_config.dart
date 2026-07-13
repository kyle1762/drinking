/// 飞书应用配置(静态常量)
///
/// App ID 和 App Secret 由用户在「账号&飞书」页填写并持久化到本地,
/// 不再硬编码在此处。本文件仅保留与凭证无关的静态配置:
/// - OAuth 重定向地址
/// - OAuth 授权范围
///
/// 用户使用前需在飞书开放平台创建自建应用:
/// 1. 访问 https://open.feishu.cn/app 创建自建应用
/// 2. 开启「机器人」能力
/// 3. 权限管理 → 开通:im:message, contact:user.base:readonly
/// 4. 安全设置 → 重定向 URL 添加: https://drinking.example.com/oauth/callback
/// 5. 在本 App「账号&飞书」页填入 App ID 和 App Secret
class FeishuConfig {
  FeishuConfig._();

  // ============ OAuth 回调地址 ============
  // 需在飞书应用「安全设置 → 重定向 URL」中添加此地址
  // 此地址无需真实存在,App 内 WebView 会拦截跳转并提取 code
  static const String redirectUri = 'https://drinking.example.com/oauth/callback';

  // ============ OAuth 授权范围 ============
  static const List<String> scopes = [
    'contact:user.base:readonly', // 获取用户 open_id
    'im:message', // 发送消息
  ];

  /// 构建 OAuth 授权 URL
  /// [appId] 由用户在设置页填写,从本地存储动态读取
  /// 注意:授权页面域名是 accounts.feishu.cn,不是 open.feishu.cn
  static String buildOAuthUrl(String appId) {
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
