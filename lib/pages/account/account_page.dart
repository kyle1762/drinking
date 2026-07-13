import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';
import '../../services/feishu_config.dart';
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
            _FeishuBindCard(),
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

/// 飞书绑定核心卡片
class _FeishuBindCard extends StatefulWidget {
  @override
  State<_FeishuBindCard> createState() => _FeishuBindCardState();
}

class _FeishuBindCardState extends State<_FeishuBindCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        const SectionTitle('飞书绑定'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: s.isFeishuBound ? _bound(context, s) : _unbound(context, s),
          ),
        ),
      ],
    );
  }

  Widget _unbound(BuildContext context, AppState s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.phone_iphone, size: 22, color: AppColors.softBlueDeep),
            SizedBox(width: 10),
            Expanded(
              child: Text('飞书登录',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('登录飞书后,定时提醒将自动推送到你的飞书私信',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 16),
        if (!FeishuConfig.isConfigured) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paused,
              borderRadius: BorderRadius.circular(AppThemeRadius.s),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '应用凭证未配置,请联系开发者填写 App ID 和 App Secret。\n'
                    '需在 open.feishu.cn 创建自建应用,开启机器人能力,\n'
                    '添加权限: im:message、contact:user.base:readonly,\n'
                    '并在安全设置中添加重定向 URL:\n'
                    'https://drinking.example.com/oauth/callback',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(color: AppColors.softBlueDeep),
          ))
        else
          RippleButton(
            onTap: FeishuConfig.isConfigured ? () => _startOAuth(context) : null,
            borderRadius: AppThemeRadius.s,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: FeishuConfig.isConfigured
                    ? AppColors.feishu
                    : AppColors.paused,
                borderRadius: BorderRadius.circular(AppThemeRadius.s),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 18, color: AppColors.softBlueDeep),
                  const SizedBox(width: 8),
                  Text(
                    FeishuConfig.isConfigured ? '飞书登录' : '凭证未配置',
                    style: const TextStyle(
                        color: AppColors.softBlueDeep,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
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

  /// 启动飞书 OAuth 授权流程
  /// 打开 WebView 内嵌飞书授权页,用户授权后返回 code,完成登录
  Future<void> _startOAuth(BuildContext context) async {
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final s = context.read<AppState>();

    // 打开 OAuth 页面,等待用户授权返回 code
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const FeishuOAuthPage()),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (code == null || code.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('已取消登录')),
      );
      return;
    }

    // 显示加载对话框
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
    Navigator.of(context).pop(); // 关闭加载对话框

    messenger.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// 测试推送
  Future<void> _testPush(BuildContext context, AppState s) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在发送测试消息...')),
    );
    final ok = await s.sendFeishuMessage('喝水提醒测试:飞书推送已连通~');
    if (!mounted) return;
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
