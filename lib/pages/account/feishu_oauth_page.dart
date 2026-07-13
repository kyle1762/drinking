import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/feishu_config.dart';
import '../../theme/app_colors.dart';

/// 飞书 OAuth 登录页 - WebView 内嵌
/// 打开飞书授权页,用户授权后拦截重定向 URL,提取 code 返回
class FeishuOAuthPage extends StatefulWidget {
  const FeishuOAuthPage({super.key});

  @override
  State<FeishuOAuthPage> createState() => _FeishuOAuthPageState();
}

class _FeishuOAuthPageState extends State<FeishuOAuthPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;
  // 扫码后飞书会尝试 lark:// scheme 唤起飞书 App 确认,此时显示提示
  bool _waitingFeishuConfirm = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _loading = true;
              _error = false;
            });
          },
          onPageFinished: (_) {
            setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            // 重定向地址不存在是正常的(我们拦截它),不视为错误
            // lark:// scheme 报 ERR_UNKNOWN_URL_SCHEME 也不视为错误
            if (e.errorType == WebResourceErrorType.unknown &&
                (e.description.contains('ERR_UNKNOWN_URL_SCHEME'))) {
              return;
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;

            // 1. 拦截重定向 URL,提取授权码 code
            if (url.startsWith(FeishuConfig.redirectUri)) {
              final uri = Uri.parse(url);
              final code = uri.queryParameters['code'];
              final error = uri.queryParameters['error'];
              if (error != null) {
                Navigator.of(context).pop();
                return NavigationDecision.prevent;
              }
              if (code != null) {
                Navigator.of(context).pop(code);
                return NavigationDecision.prevent;
              }
              Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }

            // 2. 拦截飞书自定义 scheme(lark://, feishu://) - 唤起飞书 App 确认
            // WebView 无法处理这些 scheme,阻止导航避免 ERR_UNKNOWN_URL_SCHEME 报错
            // 用户需手动到飞书 App 中点击确认,确认后网页会自动跳转到 redirect_uri
            if (url.startsWith('lark://') ||
                url.startsWith('feishu://') ||
                url.startsWith('larksuite://')) {
              setState(() => _waitingFeishuConfirm = true);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(FeishuConfig.buildOAuthUrl()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '飞书登录',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.paused,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.softBlueDeep),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_error)
            Container(
              color: AppColors.cream,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    const Text(
                      '加载失败,请检查网络',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        _controller.reload();
                        setState(() => _error = false);
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          // 扫码后提示用户去飞书 App 确认
          if (_waitingFeishuConfirm)
            Container(
              color: AppColors.cream.withValues(alpha: 0.95),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner,
                          size: 56, color: AppColors.softBlueDeep),
                      const SizedBox(height: 20),
                      const Text(
                        '请到飞书 App 中确认登录',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '已扫码成功,请打开飞书 App\n点击「确认登录」完成授权',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          setState(() => _waitingFeishuConfirm = false);
                          _controller.reload();
                        },
                        child: const Text('重新扫码'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
