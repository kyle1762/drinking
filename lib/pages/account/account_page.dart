import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../state/app_state.dart';
import '../../services/ai_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';
import 'feishu_oauth_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const _IllustrationHeader(),
            const _ApiKeyCard(),
            _FeishuConfigCard(),
            // _FeishuBindCard 仅在已登录时显示(测试推送+退出登录)
            Selector<AppState, bool>(
              selector: (_, s) => s.isFeishuBound,
              builder: (_, bound, __) =>
                  bound ? _FeishuBindCard() : const SizedBox.shrink(),
            ),
            _ProfileModule(),
            const _WarningTextCard(),
            const _ExportDataCard(),
          ],
        ),
      ),
    );
  }
}

/// 顶部治愈插画 - 云朵+水杯+电脑
class _IllustrationHeader extends StatelessWidget {
  const _IllustrationHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 云朵
                Positioned(
                  left: 30,
                  top: 10,
                  child: _cloud(60, AppColors.softBlue),
                ),
                Positioned(
                  right: 20,
                  top: 30,
                  child: _cloud(50, AppColors.mint),
                ),
                // 水杯
                Positioned(
                  child: Container(
                    width: 56,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: AppColors.softBlueDeep, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 36,
                          margin: const EdgeInsets.only(
                              bottom: 6, left: 4, right: 4),
                          decoration: BoxDecoration(
                            color: AppColors.waterDrop,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 手机
                const Positioned(
                  right: 50,
                  bottom: 0,
                  child: Icon(Icons.phone_iphone,
                      size: 44, color: AppColors.feishu),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('AI & 飞书关联', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _cloud(double size, Color color) {
    return CustomPaint(
      size: Size(size, size * 0.6),
      painter: _CloudIconPainter(color),
    );
  }
}

class _CloudIconPainter extends CustomPainter {
  _CloudIconPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(w * 0.3, h * 0.6), radius: h * 0.4))
      ..addOval(
          Rect.fromCircle(center: Offset(w * 0.6, h * 0.45), radius: h * 0.5))
      ..addOval(
          Rect.fromCircle(center: Offset(w * 0.85, h * 0.6), radius: h * 0.4));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 飞书机器人配置卡片 - 用户自定义接入自己的飞书机器人
/// 显示逻辑:
/// 1. 顶部「启用飞书推送」开关
/// 2. 开关关闭:仅显示开关 + 简短说明
/// 3. 开关打开但凭证未保存:显示 App ID/Secret 输入框 + 保存 + 测试连接
/// 4. 凭证已保存且未登录:显示飞书登录按钮 + 「需和机器人同账户」提示
/// 5. 已登录:显示登录状态 + 测试推送 + 退出登录(由 _FeishuBindCard 处理)
class _FeishuConfigCard extends StatefulWidget {
  @override
  State<_FeishuConfigCard> createState() => _FeishuConfigCardState();
}

class _FeishuConfigCardState extends State<_FeishuConfigCard> {
  late final TextEditingController _appIdCtrl;
  late final TextEditingController _appSecretCtrl;
  bool _obscureSecret = true;
  bool _testing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _appIdCtrl = TextEditingController(text: s.feishuAppId);
    _appSecretCtrl = TextEditingController(text: s.feishuAppSecret);
  }

  @override
  void dispose() {
    _appIdCtrl.dispose();
    _appSecretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    // 凭证是否已保存(本地存储非空)
    final hasCredentials =
        s.feishuAppId.isNotEmpty && s.feishuAppSecret.isNotEmpty;
    return Column(
      children: [
        const SectionTitle('飞书机器人配置'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部:启用飞书推送开关(始终显示)
                Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined,
                        size: 20, color: AppColors.softBlueDeep),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('启用飞书推送',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                    Switch(
                      value: s.feishuPushEnabled,
                      onChanged: (v) => s.setFeishuPushEnabled(v),
                    ),
                  ],
                ),
                // 开关关闭时:简短说明,不显示任何输入/按钮
                if (!s.feishuPushEnabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('开启后可配置自己的飞书机器人,定时提醒将推送到飞书私信',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.5)),
                  )
                // 开关打开 + 凭证未保存:显示输入框 + 保存 + 测试连接
                else if (!hasCredentials) ...[
                  const Divider(height: 24),
                  const Text('App ID',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _appIdCtrl,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'cli_xxxxxxxxxxxxxx',
                      hintStyle: const TextStyle(
                          color: AppColors.textDisabled, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppThemeRadius.s),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('App Secret',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _appSecretCtrl,
                    obscureText: _obscureSecret,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'XXXXXXXXXXXXXXXX',
                      hintStyle: const TextStyle(
                          color: AppColors.textDisabled, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.cream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppThemeRadius.s),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureSecret
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscureSecret = !_obscureSecret),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 机器人创建教程链接(替代原多行文字说明)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.paused,
                      borderRadius: BorderRadius.circular(AppThemeRadius.s),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.menu_book_outlined,
                                size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '不知道如何创建飞书机器人?点击查看图文教程:',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: RippleButton(
                                onTap: () => _launchUrl(
                                    'http://xhslink.com/o/7WXxORSC6UN'),
                                borderRadius: AppThemeRadius.s,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.feishu,
                                    borderRadius:
                                        BorderRadius.circular(AppThemeRadius.s),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.open_in_new,
                                          size: 14,
                                          color: AppColors.softBlueDeep),
                                      SizedBox(width: 4),
                                      Text('小红书教程',
                                          style: TextStyle(
                                              color: AppColors.softBlueDeep,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RippleButton(
                                onTap: () => _launchUrl(
                                    'https://www.zhihu.com/pin/2062320602816549984'),
                                borderRadius: AppThemeRadius.s,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.softBlue,
                                    borderRadius:
                                        BorderRadius.circular(AppThemeRadius.s),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.open_in_new,
                                          size: 14,
                                          color: AppColors.softBlueDeep),
                                      SizedBox(width: 4),
                                      Text('知乎教程',
                                          style: TextStyle(
                                              color: AppColors.softBlueDeep,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '提示:保存凭证后点击「手机号登录」即可,无需配置重定向 URL',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: RippleButton(
                          onTap: _save,
                          borderRadius: AppThemeRadius.s,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.feishu,
                              borderRadius:
                                  BorderRadius.circular(AppThemeRadius.s),
                            ),
                            alignment: Alignment.center,
                            child: const Text('保存配置',
                                style: TextStyle(
                                    color: AppColors.softBlueDeep,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RippleButton(
                          onTap: _testing ? null : _testConnection,
                          borderRadius: AppThemeRadius.s,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _testing
                                  ? AppColors.paused
                                  : AppColors.softBlue,
                              borderRadius:
                                  BorderRadius.circular(AppThemeRadius.s),
                            ),
                            alignment: Alignment.center,
                            child: _testing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.softBlueDeep),
                                  )
                                : const Text('测试连接',
                                    style: TextStyle(
                                        color: AppColors.softBlueDeep,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ]
                // 开关打开 + 凭证已保存 + 未登录:显示飞书登录按钮 + 同账户提示
                else if (!s.isFeishuBound) ...[
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(AppThemeRadius.s),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.softBlueDeep),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '重要:登录的飞书账号必须与创建机器人的账号一致,\n'
                            '否则机器人无法向该账号发送消息。',
                            style: TextStyle(
                                color: AppColors.softBlueDeep,
                                fontSize: 12,
                                height: 1.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(
                          color: AppColors.softBlueDeep),
                    ))
                  else
                    Row(
                      children: [
                        // OAuth 登录(需配置重定向 URL)
                        Expanded(
                          child: RippleButton(
                            onTap: () => _startOAuth(context),
                            borderRadius: AppThemeRadius.s,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.feishu,
                                borderRadius:
                                    BorderRadius.circular(AppThemeRadius.s),
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login,
                                      size: 18, color: AppColors.softBlueDeep),
                                  SizedBox(width: 6),
                                  Text('飞书登录',
                                      style: TextStyle(
                                          color: AppColors.softBlueDeep,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 手机号登录(无需配置重定向 URL,更可靠)
                        Expanded(
                          child: RippleButton(
                            onTap: () => _startPhoneLogin(context),
                            borderRadius: AppThemeRadius.s,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.softBlue,
                                borderRadius:
                                    BorderRadius.circular(AppThemeRadius.s),
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone_android,
                                      size: 18, color: AppColors.softBlueDeep),
                                  SizedBox(width: 6),
                                  Text('手机号登录',
                                      style: TextStyle(
                                          color: AppColors.softBlueDeep,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  // 允许重新编辑凭证
                  Center(
                    child: RippleButton(
                      onTap: _clearCredentials,
                      child: const Text('重新填写凭证 >',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]
                // 已登录:显示登录状态(实际渲染由下方 _FeishuBindCard 完成,这里留空)
                else ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.feishu,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_iphone,
                            size: 20, color: AppColors.softBlueDeep),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.feishuName,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            const Text('飞书已登录',
                                style: TextStyle(
                                    color: AppColors.mintDeep, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.link,
                          color: AppColors.mintDeep, size: 18),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _save() {
    final s = context.read<AppState>();
    final appId = _appIdCtrl.text.trim();
    final appSecret = _appSecretCtrl.text.trim();
    if (appId.isEmpty || appSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App ID 和 App Secret 不能为空')),
      );
      return;
    }
    s.saveFeishuCredentials(appId: appId, appSecret: appSecret);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已保存,可点击下方「飞书登录」')),
    );
  }

  /// 打开外部链接(机器人创建教程)
  Future<void> _launchUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(content: Text('无法打开链接:$url')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('打开链接失败:$e')),
      );
    }
  }

  /// 清除已保存的凭证,让用户重新填写
  void _clearCredentials() {
    final s = context.read<AppState>();
    s.saveFeishuCredentials(appId: '', appSecret: '');
    _appIdCtrl.clear();
    _appSecretCtrl.clear();
    setState(() {});
  }

  Future<void> _testConnection() async {
    final s = context.read<AppState>();
    final appId = _appIdCtrl.text.trim();
    final appSecret = _appSecretCtrl.text.trim();
    if (appId.isEmpty || appSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写 App ID 和 App Secret')),
      );
      return;
    }
    s.saveFeishuCredentials(appId: appId, appSecret: appSecret);
    setState(() => _testing = true);
    final messenger = ScaffoldMessenger.of(context);
    final (success, message) = await s.testFeishuConnection();
    if (!mounted) return;
    setState(() => _testing = false);
    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// 启动飞书 OAuth 授权流程
  Future<void> _startOAuth(BuildContext context) async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final s = context.read<AppState>();

    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FeishuOAuthPage()),
    );

    if (!context.mounted) return;
    setState(() => _loading = false);

    if (code == null || code.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('已取消登录')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在登录飞书...'),
          ],
        ),
      ),
    );

    final (success, message) = await s.loginWithFeishuOAuth(code);

    if (!context.mounted) return;
    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// 通过手机号登录飞书(无需配置 OAuth 重定向 URL)
  Future<void> _startPhoneLogin(BuildContext context) async {
    final phone = await AppDialogs.inputDialog(
      context,
      title: '手机号登录',
      hint: '请输入飞书绑定的手机号(如 13800138000)',
      keyboardType: TextInputType.phone,
    );
    if (phone == null || phone.trim().isEmpty) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final s = context.read<AppState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在查询飞书用户...'),
          ],
        ),
      ),
    );

    final (success, message) = await s.loginWithPhone(phone.trim());

    if (!context.mounted) return;
    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }
}

/// 飞书绑定核心卡片 - 仅在已登录时显示测试推送和退出登录
/// (由 AccountPage 通过 Selector 仅在 isFeishuBound=true 时渲染)
class _FeishuBindCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        const SectionTitle('飞书绑定'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(child: _bound(context, s)),
        ),
      ],
    );
  }

  Widget _bound(BuildContext context, AppState s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.feishu,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_iphone,
                  size: 20, color: AppColors.softBlueDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.feishuName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const Text('飞书已登录',
                      style:
                          TextStyle(color: AppColors.mintDeep, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.link, color: AppColors.mintDeep, size: 18),
          ],
        ),
        const Divider(height: 24),
        Row(
          children: [
            Expanded(
              child: RippleButton(
                onTap: () => _testPush(context, s),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(AppThemeRadius.s),
                  ),
                  alignment: Alignment.center,
                  child: const Text('测试推送',
                      style: TextStyle(
                          color: AppColors.softBlueDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RippleButton(
                onTap: () => AppDialogs.confirm(
                  context,
                  title: '退出飞书登录?',
                  content: '退出后所有飞书推送通道关闭,需重新登录',
                  confirmText: '退出',
                  onConfirm: () {
                    s.unbindFeishu();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已退出飞书登录,全局推送已关闭')),
                    );
                  },
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.paused,
                    borderRadius: BorderRadius.circular(AppThemeRadius.s),
                  ),
                  alignment: Alignment.center,
                  child: const Text('退出登录',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 测试推送
  Future<void> _testPush(BuildContext context, AppState s) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在发送测试消息...')),
    );
    final result = await s.sendFeishuMessageWithDetail('动一动提醒测试:飞书推送已连通~');
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.$1 ? '测试消息已发送至飞书' : '发送失败: ${result.$2}'),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

/// API Key 配置卡片 - 配置智谱 AI API Key 用于图片识别/饮食建议
class _ApiKeyCard extends StatefulWidget {
  const _ApiKeyCard();

  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  late TextEditingController _ctrl;
  bool _obscure = true;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: AiService.apiKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = AiService.hasApiKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        color: configured ? AppColors.mint : AppColors.softBlue,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  configured ? Icons.check_circle_outline : Icons.key_outlined,
                  size: 18,
                  color:
                      configured ? AppColors.mintDeep : AppColors.softBlueDeep,
                ),
                const SizedBox(width: 6),
                Text(
                  configured ? 'API Key 已配置' : 'API Key 未配置',
                  style: TextStyle(
                    color: configured
                        ? AppColors.mintDeep
                        : AppColors.softBlueDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                RippleButton(
                  onTap: () => setState(() => _editing = !_editing),
                  borderRadius: 12,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      _editing ? '收起' : '修改',
                      style: TextStyle(
                        color: configured
                            ? AppColors.mintDeep
                            : AppColors.softBlueDeep,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_editing) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: '输入 API Key',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: RippleButton(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RippleButton(
                    onTap: _saveKey,
                    borderRadius: AppThemeRadius.s,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: configured
                            ? AppColors.mintDeep
                            : AppColors.softBlueDeep,
                        borderRadius: BorderRadius.circular(AppThemeRadius.s),
                      ),
                      child: const Text('保存',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('用于AI图片识别(食物/运动/体测)和饮食建议,免费申请: open.bigmodel.cn',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  void _saveKey() async {
    final key = _ctrl.text.trim();
    await AiService.saveApiKey(key);
    if (mounted) {
      context.read<AppState>().refreshAiData();
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(key.isEmpty ? '已清除 API Key' : 'API Key 已保存')),
      );
    }
  }
}

/// 个人资料设置
class _ProfileModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        const SectionTitle('个人资料'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: Column(
              children: [
                _row(context, '昵称',
                    s.profile.nickname.isEmpty ? '未设置' : s.profile.nickname,
                    onTap: () async {
                  final v = await AppDialogs.inputDialog(context,
                      title: '修改昵称', hint: '输入昵称', initial: s.profile.nickname);
                  if (v != null && v.isNotEmpty) {
                    s.updateProfile(s.profile.copyWith(nickname: v));
                  }
                }),
                const Divider(height: 1),
                _row(context, '目标体重',
                    s.profile.targetWeight > 0 ? '${s.profile.targetWeight} kg' : '未设置',
                    onTap: () async {
                  final v = await AppDialogs.inputDialog(context,
                      title: '目标体重',
                      hint: '输入 kg',
                      keyboardType: TextInputType.number,
                      initial: s.profile.targetWeight > 0
                          ? '${s.profile.targetWeight}'
                          : '');
                  final tw = int.tryParse(v ?? '');
                  if (tw != null && tw > 0) {
                    s.updateProfile(s.profile.copyWith(targetWeight: tw));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('目标体重已更新为 $tw kg')),
                      );
                    }
                  }
                }),
                const Divider(height: 1),
                _row(context, '每日目标', '${s.profile.dailyGoal} ml',
                    onTap: () async {
                  final v = await AppDialogs.inputDialog(context,
                      title: '每日目标',
                      hint: '输入 ml',
                      keyboardType: TextInputType.number,
                      initial: '${s.profile.dailyGoal}');
                  final goal = int.tryParse(v ?? '');
                  if (goal != null && goal > 0) {
                    s.setDailyGoal(goal);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('每日目标已更新为 $goal ml,全局同步')),
                      );
                    }
                  }
                }),
                const Divider(height: 1),
                _row(context, '起床时间', s.profile.wakeTime, onTap: () async {
                  final t = await AppDialogs.pickTime(context,
                      initial: s.profile.wakeTime);
                  if (t != null) {
                    s.updateProfile(s.profile.copyWith(
                        wakeTime:
                            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'));
                  }
                }),
                const Divider(height: 1),
                _row(context, '睡觉时间', s.profile.bedTime, onTap: () async {
                  final t = await AppDialogs.pickTime(context,
                      initial: s.profile.bedTime);
                  if (t != null) {
                    s.updateProfile(s.profile.copyWith(
                        bedTime:
                            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'));
                  }
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('修改后实时同步至提醒设置、喝水统计页',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {required VoidCallback onTap}) {
    return RippleButton(
      onTap: onTap,
      borderRadius: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 15)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

/// 红色摄入过多提醒的弹窗文案设置卡(可选预设或自定义)
class _WarningTextCard extends StatelessWidget {
  const _WarningTextCard();

  static const _presets = [
    '陛下,你的减肥大业药丸啦!',
    '今日红色超标,减肥大业告急!',
    '你又在偷吃禁忌食物了!',
    '红色警报:再吃这些小心发胖!',
    '哎,说好的管住嘴呢?',
  ];

  @override
  Widget build(BuildContext context) {
    final current = StorageService.getForbiddenWarningText();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('提醒文案'),
          CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: Color(0xFFC62828)),
                    const SizedBox(width: 6),
                    const Text('红色摄入提醒语',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    RippleButton(
                      onTap: () => _editText(context),
                      borderRadius: 8,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Text('更换/自定义',
                            style: TextStyle(
                                color: AppColors.softBlueDeep,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('今日摄入避免吃食材过多时,将弹出此提醒语',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 6),
                Text('「$current」',
                    style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editText(BuildContext context) {
    final ctrl = TextEditingController(
        text: StorageService.getForbiddenWarningText());
    String selected = StorageService.getForbiddenWarningText();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text('红色摄入提醒语',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('选择预设或自定义,保存后生效',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _presets.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final p = _presets[i];
                          final isSel = selected == p;
                          return InkWell(
                            onTap: () {
                              selected = p;
                              ctrl.text = p;
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFFFFE0E0)
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel
                                      ? const Color(0xFFC62828)
                                      : AppColors.divider,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(p,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textPrimary)),
                                  ),
                                  if (isSel)
                                    const Icon(Icons.check_circle,
                                        size: 16,
                                        color: Color(0xFFC62828)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: '自定义文案',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppThemeRadius.s),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    RippleButton(
                      onTap: () {
                        final text = ctrl.text.trim();
                        if (text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('文案不能为空')),
                          );
                          return;
                        }
                        StorageService.saveForbiddenWarningText(text);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('提醒文案已更新')),
                        );
                      },
                      borderRadius: AppThemeRadius.s,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828),
                          borderRadius:
                              BorderRadius.circular(AppThemeRadius.s),
                        ),
                        alignment: Alignment.center,
                        child: const Text('保存',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 导出全部数据到手机下载目录
class _ExportDataCard extends StatelessWidget {
  const _ExportDataCard();

  static const _channel = MethodChannel('drinking/export');

  Future<void> _export(BuildContext context) async {
    final json = StorageService.exportAllDataJson();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'drinking_export_$stamp.json';
    try {
      final path =
          await _channel.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'content': json,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导出到 $path'),
          duration: const Duration(seconds: 4),
        ),
      );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败:${e.message ?? '未知错误'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('数据备份'),
          CreamCard(
            child: Row(
              children: [
                const Icon(Icons.download_rounded,
                    size: 20, color: AppColors.softBlueDeep),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('导出全部数据',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 3),
                      Text('将账号、记录、营养表等所有数据导出为 JSON 文件',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                RippleButton(
                  onTap: () => _export(context),
                  borderRadius: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('导出',
                        style: TextStyle(
                            color: AppColors.softBlueDeep,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
