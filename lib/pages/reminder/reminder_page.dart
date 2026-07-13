import 'dart:math' as math;
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
import '../stats/stats_page.dart';

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
            _SplitHeader(),
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
            const CloudProgressCard(),
            const PunchButton(),
            const SizedBox(height: 8),
            const RecordList(),
            _ReminderModule(),
            _TimeRangeModule(),
            _EarphoneModule(),
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
/// 头部左右分栏 - 左:今日提醒概览卡片,右:空心小人(水位随今日饮水率填充)
class _SplitHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左:概览卡片
          Expanded(
            flex: 2,
            child: CreamCard(
              color: AppColors.softBlue,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop_outlined,
                          size: 18, color: AppColors.softBlueDeep),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text('今日提醒概览',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                      StatusTag(
                        text: s.reminderPaused
                            ? '已暂停'
                            : (s.reminderEnabled ? '提醒中' : '已暂停'),
                        active: s.reminderEnabled && !s.reminderPaused,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _overviewItem('下次提醒', s.nextReminderTime),
                  _overviewItem('当前间隔', '${s.loopInterval} 分钟'),
                  _overviewItem('今日已提醒', '${s.todayReminderCount} 次'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 右:空心小人容器(占据主要高度)
          Expanded(
            flex: 3,
            child: _FigureWidget(),
          ),
        ],
      ),
    );
  }

  Widget _overviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  color: AppColors.softBlueDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// 空心小人 - 黑色轮廓,内部水位随今日饮水率(rate)从脚部向上填充
/// 点击喝水按键时触发仰头喝水动画 + 水位补间动画
class _FigureWidget extends StatefulWidget {
  @override
  State<_FigureWidget> createState() => _FigureWidgetState();
}

class _FigureWidgetState extends State<_FigureWidget>
    with TickerProviderStateMixin {
  late final AnimationController _waterCtl; // 水位补间
  late final AnimationController _tiltCtl; // 仰头喝水
  late Animation<double> _waterAnim;
  late final Animation<double> _tiltAnim;
  double _displayedRate = 0;
  int _lastPulse = 0;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _displayedRate = s.todayRate.clamp(0.0, 1.0);
    _lastPulse = s.drinkPulse;
    _waterCtl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _waterAnim = ConstantTween(_displayedRate).animate(_waterCtl);
    _tiltCtl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850));
    // 0 -> -0.55(仰头) -> 0
    _tiltAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: -0.55)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: 45),
      TweenSequenceItem(
          tween: Tween<double>(begin: -0.55, end: 0.0)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 55),
    ]).animate(_tiltCtl)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _waterCtl.dispose();
    _tiltCtl.dispose();
    super.dispose();
  }

  void _onPulseChanged(int pulse, double targetRate) {
    if (pulse != _lastPulse) {
      _lastPulse = pulse;
      // 触发仰头喝水动画
      _tiltCtl.forward(from: 0);
    }
    // 水位补间到新值
    if ((targetRate - _displayedRate).abs() > 0.001) {
      final oldRate = _displayedRate;
      _waterCtl.reset();
      _waterAnim = Tween<double>(begin: oldRate, end: targetRate.clamp(0.0, 1.0))
          .animate(CurvedAnimation(
              parent: _waterCtl, curve: Curves.easeOutCubic))
        ..addListener(() {
          if (mounted) setState(() => _displayedRate = _waterAnim.value);
        });
      _waterCtl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final targetRate = s.todayRate.clamp(0.0, 1.0);
    // 监听 pulse 变化触发动画
    if (s.drinkPulse != _lastPulse ||
        (targetRate - _displayedRate).abs() > 0.001 && !_waterCtl.isAnimating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onPulseChanged(s.drinkPulse, targetRate);
      });
    }
    return CreamCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ClipRect(
        child: CustomPaint(
          size: Size.infinite,
          painter: _FigurePainter(
            rate: _displayedRate,
            tiltAngle: _tiltCtl.isAnimating ? _tiltAnim.value : 0.0,
          ),
        ),
      ),
    );
  }
}

/// 空心小人绘制器
/// 黑色轮廓:头/颈/身/手/腿;身体内部裁剪并从脚部填充淡蓝水位
class _FigurePainter extends CustomPainter {
  _FigurePainter({required this.rate, required this.tiltAngle});
  final double rate; // 0~1 今日饮水率
  final double tiltAngle; // 头部仰头角度(弧度,负值=后仰)

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final outlinePaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final waterPaint = Paint()..color = AppColors.softBlueDeep;

    // 身体区域(rounded rect)作为"杯子"
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.30, h * 0.26, w * 0.70, h * 0.72),
      Radius.circular(w * 0.10),
    );

    // ---- 1. 先画身体水位填充(裁剪到 bodyRect) ----
    final bodyBounds = bodyRect.outerRect;
    final fillH = bodyBounds.height * rate;
    canvas.save();
    canvas.clipRRect(bodyRect);
    final waterTop = bodyBounds.bottom - fillH;
    canvas.drawRect(
      Rect.fromLTRB(bodyBounds.left, waterTop, bodyBounds.right, bodyBounds.bottom),
      waterPaint,
    );
    // 水位顶部波浪
    if (rate > 0.001 && rate < 0.999) {
      final wavePaint = Paint()
        ..color = AppColors.softBlueDeep
        ..style = PaintingStyle.fill;
      final path = Path();
      const waveAmp = 3.0;
      path.moveTo(bodyBounds.left, waterTop + waveAmp);
      for (double x = bodyBounds.left; x <= bodyBounds.right; x += 4) {
        final y = waterTop +
            waveAmp * 0.6 * math.sin((x - bodyBounds.left) * 0.18);
        path.lineTo(x, y);
      }
      path.lineTo(bodyBounds.right, waterTop + waveAmp);
      path.lineTo(bodyBounds.right, bodyBounds.bottom);
      path.lineTo(bodyBounds.left, bodyBounds.bottom);
      path.close();
      canvas.drawPath(path, wavePaint);
    }
    canvas.restore();

    // ---- 2. 画身体轮廓 ----
    canvas.drawRRect(bodyRect, outlinePaint);

    // ---- 3. 腿 ----
    final legTopY = bodyBounds.bottom;
    canvas.drawLine(Offset(w * 0.40, legTopY), Offset(w * 0.36, h * 0.92),
        outlinePaint);
    canvas.drawLine(Offset(w * 0.60, legTopY), Offset(w * 0.64, h * 0.92),
        outlinePaint);

    // ---- 4. 手臂 ----
    final shoulderY = bodyBounds.top + bodyBounds.height * 0.12;
    canvas.drawLine(
        Offset(bodyBounds.left, shoulderY),
        Offset(w * 0.14, shoulderY + bodyBounds.height * 0.22),
        outlinePaint);
    canvas.drawLine(
        Offset(bodyBounds.right, shoulderY),
        Offset(w * 0.86, shoulderY + bodyBounds.height * 0.22),
        outlinePaint);

    // ---- 5. 头部+颈部(应用仰头旋转) ----
    final neckBase = Offset(w * 0.5, bodyBounds.top);
    final headCenter = Offset(w * 0.5, bodyBounds.top - h * 0.10);
    final headRadius = w * 0.13;
    canvas.save();
    canvas.translate(neckBase.dx, neckBase.dy);
    canvas.rotate(tiltAngle);
    canvas.translate(-neckBase.dx, -neckBase.dy);
    // 颈
    canvas.drawLine(neckBase, Offset(headCenter.dx, headCenter.dy + headRadius * 0.6),
        outlinePaint);
    // 头(空心圆)
    canvas.drawCircle(headCenter, headRadius, outlinePaint);
    // 嘴(小弧,表示喝水)
    final mouthPaint = Paint()
      ..color = AppColors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(headCenter.dx, headCenter.dy + headRadius * 0.15),
          radius: headRadius * 0.3),
      0.1,
      math.pi - 0.2,
      false,
      mouthPaint,
    );
    canvas.restore();

    // ---- 6. 底部百分比文字 ----
    final pct = (rate * 100).round();
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$pct%',
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
        canvas,
        Offset(w * 0.5 - textPainter.width / 2, h * 0.94));
  }

  @override
  bool shouldRepaint(covariant _FigurePainter old) =>
      old.rate != rate || old.tiltAngle != tiltAngle;
}

/// 定时提醒模块 - 循环/单次双标签
class _ReminderModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SectionTitle('定时提醒'),
        SizedBox(height: 12),
        _LoopReminder(),
      ],
    );
  }
}

/// 循环提醒 - 快捷间隔 + 自定义滑块(含加减5分钟按钮)
class _LoopReminder extends StatelessWidget {
  const _LoopReminder();

  // 快捷间隔:20分钟、40分钟、60分钟(1小时)
  static const _quick = [20, 40, 60];

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
            const SizedBox(height: 10),
            // 加减5分钟按钮 + 滑块(最小1分钟,最大240分钟)
            Row(
              children: [
                _stepButton(
                  icon: Icons.remove,
                  onTap: () => _adjustInterval(s, -5),
                ),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 240,
                    divisions: 239,
                    value: s.loopInterval.toDouble().clamp(1, 240),
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
                ),
                _stepButton(
                  icon: Icons.add,
                  onTap: () => _adjustInterval(s, 5),
                ),
              ],
            ),
            const Text('滑动调整 1~240 分钟,或点击 ±5 分钟微调',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  /// 加减5分钟微调按钮
  Widget _stepButton({required IconData icon, required VoidCallback onTap}) {
    return RippleButton(
      onTap: onTap,
      borderRadius: 20,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.softBlue,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.softBlueDeep),
      ),
    );
  }

  /// 调整间隔:delta 可正可负,范围 1~240
  void _adjustInterval(AppState s, int delta) {
    final newInterval = (s.loopInterval + delta).clamp(1, 240);
    s.setLoopInterval(newInterval);
    if (s.reminderEnabled && s.notificationGranted && !s.reminderPaused) {
      AlarmService.scheduleLoop(newInterval);
    }
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
    return Expanded(
      child: RippleButton(
        onTap: () async {
          final t = await AppDialogs.pickTime(context, initial: value);
          if (t != null) {
            onPick(
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
          }
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

/// 治愈音效设置 - 仅保留音效切换
class _EarphoneModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        const SectionTitle('治愈音效'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.music_note_rounded,
                        size: 20, color: AppColors.softBlueDeep),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('提醒音效',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
              ],
            ),
          ),
        ),
      ],
    );
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
