import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const _IllustrationHeader(),
            _LoginModule(),
            _FeishuBindCard(),
            _ProfileModule(),
            const _CloudSyncInfo(),
            if (s.isLoggedIn) const _LogoutButton(),
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
                // 电脑
                const Positioned(
                  right: 50,
                  bottom: 0,
                  child: Icon(Icons.dvr_outlined,
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

/// 登录模块
class _LoginModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.isLoggedIn) {
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
                    Text('已登录 ${s.phone}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.cloud_done_outlined,
                  color: AppColors.softBlueDeep),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CreamCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('登录解锁全功能',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('登录后定时、记录、徽章云端同步',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            RippleButton(
              onTap: () => _login(context, s),
              borderRadius: AppThemeRadius.s,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.softBlueDeep,
                  borderRadius: BorderRadius.circular(AppThemeRadius.s),
                ),
                alignment: Alignment.center,
                child: const Text('手机号验证码登录',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            RippleButton(
              onTap: () {
                s.enterGuest();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已进入游客模式,数据仅本地保存')),
                );
              },
              child: const Center(
                child: Text('游客模式使用 >',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _login(BuildContext context, AppState s) async {
    final phone = await AppDialogs.inputDialog(
      context,
      title: '手机号登录',
      hint: '请输入手机号',
      keyboardType: TextInputType.phone,
    );
    if (phone == null || phone.isEmpty) return;
    final code = await AppDialogs.inputDialog(
      context,
      title: '验证码',
      hint: '请输入验证码',
      keyboardType: TextInputType.number,
    );
    if (code == null || code.isEmpty) return;
    s.login(phone);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录成功,云端数据同步完成')),
      );
    }
  }
}

/// 飞书绑定核心卡片
class _FeishuBindCard extends StatelessWidget {
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
    final needLogin = s.isGuest;
    return Opacity(
      opacity: needLogin ? 0.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dvr_outlined, size: 22, color: AppColors.softBlueDeep),
              SizedBox(width: 10),
              Expanded(
                child: Text('绑定飞书电脑端',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('扫码授权后,提醒与打卡可推送至飞书私信',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 16),
          RippleButton(
            onTap: () {
              if (needLogin) {
                AppDialogs.centerDialog(
                  context,
                  title: '需要登录',
                  content: '请先登录账号,再绑定飞书',
                  actions: [
                    DialogAction('稍后再说', () => Navigator.pop(context)),
                    DialogAction('去登录', () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请在上方登录')),
                      );
                    }, primary: true),
                  ],
                );
              } else {
                _bindFeishu(context, s);
              }
            },
            borderRadius: AppThemeRadius.s,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.feishu,
                borderRadius: BorderRadius.circular(AppThemeRadius.s),
              ),
              alignment: Alignment.center,
              child: const Text('扫码授权绑定飞书',
                  style: TextStyle(
                      color: AppColors.softBlueDeep,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
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
              child: const Icon(Icons.dvr,
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
                  const Text('飞书已绑定',
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
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('测试推送已发送至飞书')),
                  );
                },
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
                  title: '解除飞书绑定?',
                  content: '解绑后所有飞书推送通道关闭,需重新授权',
                  confirmText: '解绑',
                  onConfirm: () {
                    s.unbindFeishu();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已解绑飞书,全局推送已关闭')),
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
                  child: const Text('解除绑定',
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

  void _bindFeishu(BuildContext context, AppState s) {
    // 模拟扫码授权
    AppDialogs.centerDialog(
      context,
      title: '扫码授权',
      content: '将跳转飞书完成授权,授权成功后自动回页',
      actions: [
        DialogAction('取消', () => Navigator.pop(context)),
        DialogAction('去授权', () {
          Navigator.pop(context);
          s.bindFeishu('飞书用户');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('授权成功,飞书推送已开启')),
          );
        }, primary: true),
      ],
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

/// 云端同步说明
class _CloudSyncInfo extends StatelessWidget {
  const _CloudSyncInfo();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        const SectionTitle('云端同步'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            color: AppColors.mint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined,
                        size: 20, color: AppColors.mintDeep),
                    const SizedBox(width: 8),
                    Text(s.isGuest ? '游客模式 · 仅本地' : '已开启云端备份',
                        style: const TextStyle(
                            color: AppColors.mintDeep,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                _item('定时提醒配置'),
                _item('饮水打卡记录'),
                _item('温柔徽章体系'),
                _item('飞书推送配置'),
                const SizedBox(height: 8),
                Text(
                  s.isGuest ? '登录后即可跨设备同步以上数据' : '以上数据支持跨设备同步,卸载重装不丢失',
                  style:
                      const TextStyle(color: AppColors.mintDeep, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: AppColors.mintDeep),
          const SizedBox(width: 8),
          Text(text,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}

/// 退出登录 - 保留本地 / 清空本地
class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: RippleButton(
        onTap: () => AppDialogs.centerDialog(
          context,
          title: '退出登录',
          content: '退出后全局恢复游客状态,飞书与云端功能禁用',
          actions: [
            DialogAction('取消', () => Navigator.pop(context)),
            DialogAction('保留本地', () {
              Navigator.pop(context);
              s.logout(keepLocal: true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出,本地数据已保留')),
              );
            }),
            DialogAction('清空本地', () {
              Navigator.pop(context);
              s.logout(keepLocal: false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已退出,本地数据已清空')),
              );
            }, primary: true),
          ],
        ),
        borderRadius: AppThemeRadius.m,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.paused,
            borderRadius: BorderRadius.circular(AppThemeRadius.m),
          ),
          alignment: Alignment.center,
          child: const Text('退出登录',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
