import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';
import '../../services/notification_service.dart';
import '../../services/alarm_service.dart';
import '../../services/audio_service.dart';

class ReminderPage extends StatelessWidget {
  const ReminderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _Header(),
            if (!s.notificationGranted)
              SoftBanner(
                icon: Icons.notifications_none_rounded,
                text: '开启通知权限,才能温柔地提醒你喝水',
                actionText: '去开启',
                onAction: () => _requestNotification(context),
              ),
            if (s.isGuest)
              SoftBanner(
                icon: Icons.cloud_off_outlined,
                text: '游客模式下数据仅保存在本地,登录后可云端同步',
                actionText: '去登录',
                onAction: () => _goAccount(context),
              ),
            _OverviewCard(),
            _ReminderModule(),
            _TimeRangeModule(),
            _EarphoneModule(),
            _FeishuPushModule(),
            const SizedBox(height: 16),
            _BottomActions(),
          ],
        ),
      ),
    );
  }

  Future<void> _requestNotification(BuildContext context) async {
    final s = context.read<AppState>();
    final granted = await NotificationService.requestPermission();
    s.setNotificationGranted(granted);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(granted ? '通知权限已开启,温柔提醒已就绪' : '通知权限被拒绝,请在系统设置中开启')),
    );
    // 授权后立即注册循环提醒
    if (granted && s.reminderEnabled && !s.reminderPaused) {
      await AlarmService.scheduleLoop(s.loopInterval);
    }
  }

  void _goAccount(BuildContext context) {
    // 引导跳转账号页(通过底部Tab切换,这里仅提示)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请点击底部「账号&飞书」登录')),
    );
  }
}

/// 顶部标题状态栏
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('提醒设置', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 4),
                Text('温柔提醒你按时喝水',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          StatusTag(
            text:
                s.reminderPaused ? '已暂停' : (s.reminderEnabled ? '提醒中' : '已暂停'),
            active: s.reminderEnabled && !s.reminderPaused,
          ),
        ],
      ),
    );
  }
}

/// 今日提醒概览卡片
class _OverviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CreamCard(
        color: AppColors.softBlue,
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('今日提醒概览',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _overviewItem('下次提醒', s.nextReminderTime),
                      const SizedBox(height: 8),
                      _overviewItem('当前间隔', '${s.loopInterval} 分钟'),
                      const SizedBox(height: 8),
                      _overviewItem('今日已提醒', '${s.todayReminderCount} 次'),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(Icons.water_drop,
                  size: 80, color: Colors.white.withAlpha(120)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewItem(String label, String value) {
    return Row(
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Text(value,
            style: const TextStyle(
                color: AppColors.softBlueDeep,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// 定时提醒模块 - 循环/单次双标签
class _ReminderModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionTitle('定时提醒'),
        const SizedBox(height: 12),
        const _LoopReminder(),
      ],
    );
  }
}

/// 循环提醒 - 快捷间隔 + 自定义滑块
class _LoopReminder extends StatelessWidget {
  const _LoopReminder();

  static const _quick = [30, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('快捷间隔',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: _quick.map((m) {
                final selected = s.loopInterval == m;
                return _Chip(
                  label: m < 60 ? '$m分钟' : '${m ~/ 60}小时',
                  selected: selected,
                  onTap: () {
                    s.setLoopInterval(m);
                    if (s.reminderEnabled &&
                        s.notificationGranted &&
                        !s.reminderPaused) {
                      AlarmService.scheduleLoop(m);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              '已设置每${m < 60 ? '$m分钟' : '${m ~/ 60}小时'}提醒一次')),
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('自定义间隔',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(AppThemeRadius.s),
                  ),
                  child: Text('${s.loopInterval} 分钟',
                      style: const TextStyle(
                          color: AppColors.softBlueDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            Slider(
              min: 30,
              max: 240,
              divisions: 42,
              value: s.loopInterval.toDouble().clamp(30, 240),
              onChanged: (v) => s.setLoopInterval(v.round()),
              onChangeEnd: (v) {
                if (s.reminderEnabled &&
                    s.notificationGranted &&
                    !s.reminderPaused) {
                  AlarmService.scheduleLoop(v.round());
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('间隔已更新为 ${v.round()} 分钟')),
                );
              },
            ),
            const Text('滑动调整 30~240 分钟,后台定时自动生效',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.softBlue : AppColors.paused,
      borderRadius: BorderRadius.circular(AppThemeRadius.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemeRadius.s),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(label,
              style: TextStyle(
                color:
                    selected ? AppColors.softBlueDeep : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
        ),
      ),
    );
  }
}

/// 提醒生效时段
class _TimeRangeModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        const SectionTitle('提醒生效时段'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: Column(
              children: [
                Row(
                  children: [
                    _timePicker(context, '开始', s.rangeStart,
                        (v) => s.setRange(v, s.rangeEnd)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('至',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    _timePicker(context, '结束', s.rangeEnd,
                        (v) => s.setRange(s.rangeStart, v)),
                  ],
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('重复周期',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: RepeatCycle.values.map((r) {
                    final labels = {
                      RepeatCycle.daily: '每天',
                      RepeatCycle.weekday: '工作日',
                      RepeatCycle.weekend: '周末'
                    };
                    final selected = s.repeat == r;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Chip(
                          label: labels[r]!,
                          selected: selected,
                          onTap: () => s.setRepeat(r),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                RippleButton(
                  onTap: () {
                    s.applyScheduleFromProfile();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              '已按作息 ${s.profile.wakeTime}-${s.profile.bedTime} 填充')),
                    );
                  },
                  borderRadius: AppThemeRadius.s,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(AppThemeRadius.s),
                    ),
                    alignment: Alignment.center,
                    child: const Text('智能作息填充',
                        style: TextStyle(
                            color: AppColors.mintDeep,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _timePicker(BuildContext context, String label, String value,
      ValueChanged<String> onPick) {
    final s = context.read<AppState>();
    return Expanded(
      child: RippleButton(
        onTap: () async {
          final t = await AppDialogs.pickTime(context, initial: value);
          if (t != null)
            onPick(
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
        },
        borderRadius: AppThemeRadius.s,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.paused,
            borderRadius: BorderRadius.circular(AppThemeRadius.s),
          ),
          alignment: Alignment.center,
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 耳机专属设置 - 产品核心
class _EarphoneModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        const SectionTitle('耳机专属设置'),
        if (!s.earphoneConnected)
          const SoftBanner(
            icon: Icons.headset_off_outlined,
            text: '当前无耳机,仅静默通知。插入耳机后自动恢复音效',
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 耳机提醒总开关
                Row(
                  children: [
                    Icon(
                        s.earphoneConnected
                            ? Icons.headphones
                            : Icons.headset_off_outlined,
                        size: 20,
                        color: AppColors.softBlueDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('耳机提醒',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          Text('铃声仅路由至耳机,外放静音',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.earphoneEnabled,
                      onChanged: (v) {
                        if (!v) {
                          _confirmDisableEarphone(context, s);
                        } else {
                          s.setEarphoneEnabled(true);
                        }
                      },
                    ),
                  ],
                ),
                if (s.earphoneEnabled) ...[
                  const Divider(height: 24),
                  const Text('治愈音效',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: SoundType.values.map((sd) {
                      final selected = s.sound == sd;
                      return _Chip(
                        label: sd.label,
                        selected: selected,
                        onTap: () {
                          s.setSound(sd);
                          AudioService.playSound(sd, volume: s.earphoneVolume);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('提醒音量',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${(s.earphoneVolume * 100).round()}%',
                          style: const TextStyle(
                              color: AppColors.softBlueDeep,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Slider(
                    value: s.earphoneVolume,
                    onChanged: (v) => s.setEarphoneVolume(v),
                  ),
                  const Text('仅控制本App提醒音,不影响系统媒体音量',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDisableEarphone(BuildContext context, AppState s) {
    bool syncFeishu = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppThemeRadius.m)),
          title: const Text('关闭耳机提醒?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('关闭后将仅保留静默通知',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => syncFeishu = !syncFeishu),
                child: Row(
                  children: [
                    Icon(
                        syncFeishu
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 20,
                        color: AppColors.softBlueDeep),
                    const SizedBox(width: 8),
                    const Text('同步关闭飞书推送', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () {
                s.setEarphoneEnabled(false);
                if (syncFeishu) s.setFeishuPushEnabled(false);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('确认关闭',
                  style: TextStyle(color: AppColors.softBlueDeep)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 飞书推送设置
class _FeishuPushModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final disabled = s.isGuest || !s.isFeishuBound;
    return Column(
      children: [
        const SectionTitle('飞书电脑同步'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: Opacity(
              opacity: disabled ? 0.5 : 1,
              child: AbsorbPointer(
                absorbing: disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.dvr_outlined,
                            size: 20, color: AppColors.softBlueDeep),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('飞书推送',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                s.isGuest
                                    ? '登录后开启'
                                    : (s.isFeishuBound
                                        ? '已绑定 ${s.feishuName}'
                                        : '点击绑定飞书'),
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: s.feishuPushEnabled,
                          onChanged: (v) => s.setFeishuPushEnabled(v),
                        ),
                      ],
                    ),
                    if (s.isFeishuBound && s.feishuPushEnabled) ...[
                      const Divider(height: 24),
                      const Text('推送文案',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller:
                            TextEditingController(text: s.feishuPushText),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.cream,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppThemeRadius.s),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: s.setFeishuPushText,
                      ),
                      const SizedBox(height: 12),
                      const Text('推送时机',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      _checkTile('提醒时推送', s.feishuPushOnReminder,
                          (v) => s.setFeishuPushFlags(reminder: v)),
                      _checkTile('打卡同步', s.feishuPushOnPunch,
                          (v) => s.setFeishuPushFlags(punch: v)),
                    ],
                    if (disabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: RippleButton(
                            onTap: () => _guideLoginOrBind(context, s),
                            child: Text(s.isGuest ? '去登录 >' : '去绑定 >',
                                style: const TextStyle(
                                    color: AppColors.softBlueDeep,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _checkTile(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
                value
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: AppColors.softBlueDeep),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _guideLoginOrBind(BuildContext context, AppState s) {
    if (s.isGuest) {
      AppDialogs.centerDialog(
        context,
        title: '需要登录',
        content: '飞书推送需登录后使用,是否前往登录?',
        actions: [
          DialogAction('稍后再说', () => Navigator.pop(context)),
          DialogAction('去登录', () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请点击底部「账号&飞书」登录')),
            );
          }, primary: true),
        ],
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请前往账号页绑定飞书')),
      );
    }
  }
}

/// 底部操作 - 保存 + 暂停今日
class _BottomActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: RippleButton(
              onTap: () async {
                final s = context.read<AppState>();
                final ok = s.reminderEnabled &&
                    s.notificationGranted &&
                    !s.reminderPaused;
                if (ok) {
                  // 注册循环提醒
                  await AlarmService.scheduleLoop(s.loopInterval);
                } else {
                  // 暂停或未授权时取消循环闹钟
                  await AlarmService.cancelLoop();
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(ok ? '设置已保存,后台定时已生效' : '提醒已暂停或未授权通知,定时已取消')),
                );
              },
              borderRadius: AppThemeRadius.m,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.softBlueDeep,
                  borderRadius: BorderRadius.circular(AppThemeRadius.m),
                ),
                alignment: Alignment.center,
                child: const Text('保存设置',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          RippleButton(
            onTap: () async {
              s.togglePauseToday();
              if (s.reminderPaused) {
                await AlarmService.cancelLoop();
              } else if (s.reminderEnabled && s.notificationGranted) {
                await AlarmService.scheduleLoop(s.loopInterval);
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(s.reminderPaused ? '今日提醒已暂停' : '今日提醒已恢复')),
              );
            },
            borderRadius: AppThemeRadius.m,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.paused,
                borderRadius: BorderRadius.circular(AppThemeRadius.m),
              ),
              child: Text(s.reminderPaused ? '恢复' : '暂停今日',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
