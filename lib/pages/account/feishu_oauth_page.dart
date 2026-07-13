import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/feishu_config.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

/// 飞书 OAuth 登录页 - WebView 内嵌
/// 打开飞书授权页,用户授权后拦截重定向 URL,提取 code 返回
class FeishuOAuthPage extends StatefulWidget {
  const FeishuOAuthPage({super.key});

  @override
  State<FeishuOAuthPage> createState() => _FeishuOAuthPageState();
}

class _FeishuOAuthPageState extends State<FeishuOAuthPage>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;
  // 扫码后飞书会尝试 lark:// scheme 唤起飞书 App 确认,此时显示提示
  bool _waitingFeishuConfirm = false;

  @override
  void initState() {
    super.initState();
    // 监听 App 生命周期 - 从飞书 App 切回时自动清除遮罩并 reload
    WidgetsBinding.instance.addObserver(this);
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
          onPageFinished: (url) {
            setState(() => _loading = false);
            // 页面加载完成后注入 JS:自动切换到账号密码登录,隐藏扫码
            _switchToPasswordLogin();
          },
          onWebResourceError: (e) {
            // 重定向地址不存在是正常的(我们拦截它),不视为错误
            // lark:// scheme 报 ERR_UNKNOWN_URL_SCHEME 也不视为错误
            if (e.errorType == WebResourceErrorType.unknown &&
                e.description.contains('ERR_UNKNOWN_URL_SCHEME')) {
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
            // WebView 无法处理这些 scheme,需通过 url_launcher 启动外部飞书 App
            // 用户在飞书 App 确认后,切回本 App 时生命周期监听会自动 reload
            if (url.startsWith('lark://') ||
                url.startsWith('feishu://') ||
                url.startsWith('larksuite://')) {
              _launchFeishuApp(url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(FeishuConfig.buildOAuthUrl(
        context.read<AppState>().feishuAppId,
      )));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App 从后台切回前台时(用户从飞书 App 确认后切回)
    // 只清除遮罩,不 reload - 让 WebView 保持当前状态自动跳转到 redirect_uri
    // reload 会重新加载授权页,导致 session 丢失,登录失败
    if (state == AppLifecycleState.resumed && _waitingFeishuConfirm) {
      setState(() => _waitingFeishuConfirm = false);
    }
  }

  /// 注入 JS:自动切换到账号密码登录 tab,隐藏扫码登录
  /// 飞书授权页是 SPA,页面加载完成时内容可能还没渲染
  /// 使用 MutationObserver 持续监听 DOM,一旦发现"密码登录"tab 就点击
  void _switchToPasswordLogin() {
    const js = '''
(function() {
  if (window.__pwLoginSwitched) return;
  function trySwitch() {
    try {
      var clickables = document.querySelectorAll('a, button, span, div, li, [role="tab"], [role="button"]');
      var keywords = ['密码登录', '账号登录', '账号密码', '密码', '账号', 'Password', 'password'];
      for (var i = 0; i < clickables.length; i++) {
        var el = clickables[i];
        var text = (el.textContent || '').trim();
        if (text.length > 0 && text.length < 20) {
          for (var k = 0; k < keywords.length; k++) {
            if (text === keywords[k] || text.indexOf(keywords[k]) === 0) {
              el.click();
              window.__pwLoginSwitched = true;
              return true;
            }
          }
        }
      }
      var tabs = document.querySelectorAll('[class*="password"], [class*="account"], [data-type="password"]');
      if (tabs.length > 0) { tabs[0].click(); window.__pwLoginSwitched = true; return true; }
    } catch(e) {}
    return false;
  }
  // 立即尝试一次
  if (trySwitch()) return;
  // 用 MutationObserver 持续监听 DOM 变化(SPA 内容延迟渲染)
  var observer = new MutationObserver(function() {
    if (trySwitch()) {
      observer.disconnect();
    }
  });
  observer.observe(document.documentElement, {childList: true, subtree: true});
  // 10秒后停止监听(避免无限运行)
  setTimeout(function() { observer.disconnect(); }, 10000);
})();
''';
    _controller.runJavaScript(js);
  }

  /// 通过 url_launcher 唤起飞书 App 打开 lark:// URL
  Future<void> _launchFeishuApp(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        setState(() {
          _waitingFeishuConfirm = true;
        });
      } else {
        // 唤起失败 - 可能未安装飞书 App
        if (mounted) {
          setState(() {
            _waitingFeishuConfirm = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('未检测到飞书 App,请先安装飞书后再登录'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _waitingFeishuConfirm = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('无法打开飞书 App,请确认已安装飞书'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
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
          // 已唤起飞书 App,等待用户确认
          if (_waitingFeishuConfirm)
            Container(
              color: AppColors.cream.withValues(alpha: 0.95),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_android,
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
                        '已唤起飞书 App,请切换到飞书\n点击「确认登录」后自动返回',
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
                        child: const Text('重新加载'),
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
