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
          onWebResourceError: (_) {
            // 重定向地址不存在是正常的(我们拦截它),不视为错误
          },
          onNavigationRequest: (request) {
            // 拦截重定向 URL,提取授权码 code
            if (request.url.startsWith(FeishuConfig.redirectUri)) {
              final uri = Uri.parse(request.url);
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
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: const LinearProgressIndicator(
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
        ],
      ),
    );
  }
}
