import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
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
            const _WelcomeCard(),
            _FeishuConfigCard(),
            // _FeishuBindCard 仅在已登录时显示(测试推送+退出登录)
            Selector<AppState, bool>(
              selector: (_, s) => s.isFeishuBound,
              builder: (_, bound, __) =>
                  bound ? _FeishuBindCard() : const SizedBox.shrink(),
            ),
            _ProfileModule(),
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
          Text('账号 & 飞书关联', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('双端同步,温柔陪伴你的每一天', style: Theme.of(context).textTheme.bodyMedium),
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

/// 欢迎卡片 - 纯展示,无登录流程
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CreamCard(
        color: AppColors.softBlue,
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: AppColors.softBlueDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      s.profile.nickname.isEmpty
                          ? '喝水小达人'
                          : s.profile.nickname,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const Text('本地模式 · 数据保存在本机',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.favorite_outline,
                  color: AppColors.softBlueDeep),
          ],
        ),
      ),
    );
  }
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.paused,
                      borderRadius: BorderRadius.circular(AppThemeRadius.s),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '1. 访问 open.feishu.cn 创建自建应用\n'
                            '2. 开启「机器人」能力\n'
                            '3. 权限:im:message、contact:user.base:readonly\n'
                            '4. 安全设置添加重定向 URL:\n'
                            '   https://drinking.example.com/oauth/callback',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.5),
                          ),
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
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(color: AppColors.softBlueDeep),
                    ))
                  else
                    RippleButton(
                      onTap: () => _startOAuth(context),
                      borderRadius: AppThemeRadius.s,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.feishu,
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login, size: 18, color: AppColors.softBlueDeep),
                            SizedBox(width: 8),
                            Text('飞书登录',
                                style: TextStyle(
                                    color: AppColors.softBlueDeep,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
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
                      const Icon(Icons.link, color: AppColors.mintDeep, size: 18),
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
    final ok = await s.sendFeishuMessage('喝水提醒测试:飞书推送已连通~');
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? '测试消息已发送至飞书' : '发送失败,请检查网络或凭证')),
    );
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
                _row(context, '默认水杯', '${s.profile.defaultCup} ml',
                    onTap: () async {
                  final v = await AppDialogs.inputDialog(context,
                      title: '默认水杯容量',
                      hint: '输入 ml',
                      keyboardType: TextInputType.number,
                      initial: '${s.profile.defaultCup}');
                  final cup = int.tryParse(v ?? '');
                  if (cup != null && cup > 0) {
                    s.setDefaultCup(cup);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('默认水杯已更新为 $cup ml,全局同步')),
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
