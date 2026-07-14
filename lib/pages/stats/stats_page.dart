import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';

// 本文件原为独立「喝水统计」Tab 页面,已与「提醒设置」合并为单一 Tab。
// 保留下方组件供 ReminderPage 引用:云朵进度卡片、喝水打卡、今日记录列表。
// 已删除:StatsPage、_Header(周期切换)、_ChartSection(图表)、_FeishuExport(飞书导出)。

/// 云朵进度卡片(核心视觉)
class CloudProgressCard extends StatelessWidget {
  const CloudProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final rate = s.todayRate.clamp(0.0, 1.0);
    final completed = rate >= 1.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CreamCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 云朵背景
                  Positioned(
                    top: 20,
                    child: CustomPaint(
                      size: const Size(220, 140),
                      painter: CloudPainter(rate),
                    ),
                  ),
                  // 数据
                  Positioned(
                    bottom: 8,
                    child: Column(
                      children: [
                        Text('${s.todayTotal}',
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: AppColors.softBlueDeep)),
                        Text('/ ${s.todayGoal} ml',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  // 编辑目标
                  Positioned(
                    top: 12,
                    right: 12,
                    child: RippleButton(
                      onTap: () => _editGoal(context),
                      child: const Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                  // 100% 雨滴动画
                  if (completed) const _RainAnimation(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  _stat('已喝', '${s.todayTotal}ml'),
                  _divider(),
                  _stat('剩余', '${s.todayRemaining}ml'),
                  _divider(),
                  _stat('完成率', '${(rate * 100).round()}%'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(_gentleCopy(rate),
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5),
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _divider() => const SizedBox(
      height: 24, child: VerticalDivider(color: AppColors.divider));

  String _gentleCopy(double rate) {
    if (rate >= 1.0) return '太棒了,今日水分已达标,身体一定很开心~';
    if (rate >= 0.5) return '已经过半啦,继续保持这个温柔节奏';
    return '慢慢来,小口喝水更舒服哦';
  }

  void _editGoal(BuildContext context) async {
    final s = context.read<AppState>();
    final input = await AppDialogs.inputDialog(
      context,
      title: '修改今日目标',
      hint: '输入每日目标 ml',
      initial: '${s.todayGoal}',
      keyboardType: TextInputType.number,
    );
    if (input != null) {
      final goal = int.tryParse(input);
      if (goal != null && goal > 0) {
        s.setDailyGoal(goal);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('今日目标已更新为 $goal ml,全局同步')),
          );
        }
      }
    }
  }
}

class CloudPainter extends CustomPainter {
  CloudPainter(this.rate);
  final double rate;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 云朵外形路径
    final path = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(w * 0.3, h * 0.55), radius: h * 0.35))
      ..addOval(
          Rect.fromCircle(center: Offset(w * 0.55, h * 0.45), radius: h * 0.42))
      ..addOval(
          Rect.fromCircle(center: Offset(w * 0.75, h * 0.58), radius: h * 0.34))
      ..addRect(Rect.fromLTRB(0, h * 0.6, w, h * 0.85));

    // 背景云(浅灰)
    canvas.drawPath(path, Paint()..color = AppColors.paused);
    // 填充水位(浅蓝) - 裁剪
    final fillHeight = h * (0.85 - 0.25 * rate);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTRB(0, fillHeight, w, h),
      Paint()..color = AppColors.softBlue,
    );
    canvas.restore();
    // 水位线
    final linePaint = Paint()
      ..color = AppColors.softBlueDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(w * 0.1, fillHeight), Offset(w * 0.9, fillHeight), linePaint);
  }

  @override
  bool shouldRepaint(covariant CloudPainter old) => old.rate != rate;
}

/// 100% 触发的雨滴动画
class _RainAnimation extends StatefulWidget {
  const _RainAnimation();

  @override
  State<_RainAnimation> createState() => _RainAnimationState();
}

class _RainAnimationState extends State<_RainAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return CustomPaint(
          size: const Size(200, 140),
          painter: _RainPainter(_c.value),
        );
      },
    );
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.rain;
    for (int i = 0; i < 8; i++) {
      final x = (i * 27.0) % size.width;
      final y = ((t * size.height * 1.2 + i * 18) % (size.height + 20)) - 10;
      canvas.drawCircle(Offset(x, y), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter old) => true;
}

/// 快速喝水按键 - 简易版/专业版切换
class _QuickPunchButtons extends StatefulWidget {
  @override
  State<_QuickPunchButtons> createState() => _QuickPunchButtonsState();
}

class _QuickPunchButtonsState extends State<_QuickPunchButtons> {
  /// true=简易版,false=专业版
  bool _simple = true;

  // 简易版:抿一口/喝小口/大口喝
  static const _simpleOptions = [
    ('抿一口', 10),
    ('喝小口', 50),
    ('大口喝', 200),
  ];
  // 专业版:精准数值
  static const _proOptions = [
    ('10ml', 10),
    ('100ml', 100),
    ('500ml', 500),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final options = _simple ? _simpleOptions : _proOptions;
    return Column(
      children: [
        // 简易版/专业版切换
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.paused,
            borderRadius: BorderRadius.circular(AppThemeRadius.m),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggle('简易版', _simple),
              _toggle('专业版', !_simple),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: options.map((o) {
            final (label, ml) = o;
            return Material(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(AppThemeRadius.s),
              child: InkWell(
                onTap: () {
                  s.addRecord(ml);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label 已记录 ${ml}ml')),
                  );
                },
                borderRadius: BorderRadius.circular(AppThemeRadius.s),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Text(label,
                      style: const TextStyle(
                          color: AppColors.softBlueDeep,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _toggle(String label, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _simple = label == '简易版'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppThemeRadius.s),
        ),
        child: Text(label,
            style: TextStyle(
              color:
                  selected ? AppColors.softBlueDeep : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

/// 喝水打卡卡片
class PunchButton extends StatelessWidget {
  const PunchButton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: CreamCard(
        child: Column(
          children: [
            _QuickPunchButtons(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RippleButton(
                  onTap: () => _customAmount(context, s),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(AppThemeRadius.s),
                    ),
                    child: const Text('自定义容量',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                RippleButton(
                  onTap: () {
                    s.undoLastRecord();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已撤销最近一次记录')),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(AppThemeRadius.s),
                    ),
                    child: const Text('撤销',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _customAmount(BuildContext context, AppState s) async {
    final input = await AppDialogs.inputDialog(
      context,
      title: '自定义饮水量',
      hint: '输入 ml',
      keyboardType: TextInputType.number,
    );
    if (input != null) {
      final amount = int.tryParse(input);
      if (amount != null && amount > 0) {
        s.addRecord(amount);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('已记录 $amount ml')));
        }
      }
    }
  }
}

/// 今日记录列表
class RecordList extends StatelessWidget {
  const RecordList({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        SectionTitle('今日记录',
            action: Text('${s.records.length} 条',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: s.records.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('还没有记录,喝口水开始吧~',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                )
              : CreamCard(
                  child: Column(
                    children: s.records
                        .map((r) => _recordItem(context, r, s))
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _recordItem(BuildContext context, WaterRecord r, AppState s) {
    final time =
        '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: AppColors.softBlue, shape: BoxShape.circle),
            child: const Icon(Icons.water_drop,
                size: 18, color: AppColors.softBlueDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text('${r.amount} ml',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          RippleButton(
            onTap: () => AppDialogs.confirm(
              context,
              title: '删除记录?',
              content: '将移除 $time 的 ${r.amount}ml 记录',
              onConfirm: () {
                s.removeRecord(r.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('记录已删除')),
                );
              },
              confirmText: '删除',
            ),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.delete_outline,
                  size: 18, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
