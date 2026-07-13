import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int _period = 0; // 0日 1周 2月

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _Header(
                period: _period, onChanged: (i) => setState(() => _period = i)),
            const _CloudProgressCard(),
            const _PunchButton(),
            const SizedBox(height: 8),
            const _RecordList(),
            _ChartSection(period: _period),
            const _FeishuExport(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.period, required this.onChanged});
  final int period;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['日', '周', '月'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日喝水', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 4),
                Text('每一口都是温柔的照顾',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.paused,
              borderRadius: BorderRadius.circular(AppThemeRadius.s),
            ),
            child: Row(
              children: List.generate(3, (i) {
                final selected = i == period;
                return GestureDetector(
                  onTap: () => onChanged(i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(labels[i],
                        style: TextStyle(
                          color: selected
                              ? AppColors.softBlueDeep
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// 云朵进度卡片(核心视觉)
class _CloudProgressCard extends StatelessWidget {
  const _CloudProgressCard();

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
                      painter: _CloudPainter(rate),
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

class _CloudPainter extends CustomPainter {
  _CloudPainter(this.rate);
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
  bool shouldRepaint(covariant _CloudPainter old) => old.rate != rate;
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

class _PunchButton extends StatelessWidget {
  const _PunchButton();

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
class _RecordList extends StatelessWidget {
  const _RecordList();

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

/// 周期统计图表
class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.period});
  final int period;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        SectionTitle(const ['今日分布', '本周打卡', '本月日均'][period]),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: period == 0
                ? _dailyChart(context)
                : period == 1
                    ? _weeklyChart(context)
                    : _monthlyChart(context),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            color: AppColors.mint,
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    size: 18, color: AppColors.mintDeep),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_insight(context, period),
                      style: const TextStyle(
                          color: AppColors.mintDeep,
                          fontSize: 13,
                          height: 1.4)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('温柔徽章',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _badge(Icons.local_drink_outlined, '初尝甘霖',
                        s.records.isNotEmpty),
                    _badge(Icons.eco_outlined, '七日坚持', s.punchDays(7) >= 5),
                    _badge(Icons.star_outline_rounded, '满月达成',
                        s.punchDays(30) >= 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.watch<AppState>().isGuest
                      ? '游客模式:徽章仅本地保存'
                      : '已登录:徽章云端同步',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(IconData icon, String label, bool unlocked) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: unlocked ? AppColors.softBlue : AppColors.paused,
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              size: 24,
              color:
                  unlocked ? AppColors.softBlueDeep : AppColors.textDisabled),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color:
                    unlocked ? AppColors.textPrimary : AppColors.textDisabled,
                fontSize: 11)),
      ],
    );
  }

  /// 根据真实数据生成洞察文案
  String _insight(BuildContext context, int period) {
    final s = context.watch<AppState>();
    if (period == 0) {
      final rate = (s.todayRate * 100).round();
      if (rate >= 100) return '今日已达标,太棒了~继续保持温柔的习惯';
      if (rate >= 50) return '今日喝水节奏平稳,已完成 $rate%,继续加油~';
      return '今日喝水偏少,记得定时补充水分哦~';
    } else if (period == 1) {
      final hit = s.goalHitDays(7);
      final punch = s.punchDays(7);
      return '本周打卡 $punch 天,达标 $hit 天,继续保持~';
    } else {
      final avg = s.averageDaily(30).round();
      if (avg >= s.todayGoal) return '近30天日均 ${avg}ml,已达标,太棒了~';
      return '近30天日均 ${avg}ml,离目标 ${s.todayGoal}ml 还差一点~';
    }
  }

  /// 日:时段分布柱状图
  Widget _dailyChart(BuildContext context) {
    final s = context.watch<AppState>();
    final buckets = List.filled(6, 0); // 0-4,4-8...20-24
    for (final r in s.todayRecords) {
      final idx = (r.time.hour ~/ 4).clamp(0, 5);
      buckets[idx] += r.amount;
    }
    final maxV = buckets.fold<int>(1, (a, b) => max(a, b));
    final labels = ['0-4', '4-8', '8-12', '12-16', '16-20', '20-24'];
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(6, (i) {
          final h = (buckets[i] / maxV) * 100;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: h + 4,
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i],
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 周:7天打卡日历底色标记
  Widget _weeklyChart(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 周一为本周第一天(weekday: 1=周一, 7=周日)
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final labels = ['一', '二', '三', '四', '五', '六', '日'];
    return SizedBox(
      height: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final day = weekStart.add(Duration(days: i));
          final isToday = day.isAtSameMomentAs(today);
          final isFuture = day.isAfter(today);
          final dayTotal = s.totalForDay(day);
          final done = dayTotal > 0 && !isFuture;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: done ? AppColors.softBlue : AppColors.paused,
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(color: AppColors.softBlueDeep, width: 2)
                      : null,
                ),
                child: done
                    ? const Icon(Icons.check,
                        size: 18, color: AppColors.softBlueDeep)
                    : const SizedBox(),
              ),
              const SizedBox(height: 6),
              Text(labels[i],
                  style: TextStyle(
                      color: isToday
                          ? AppColors.softBlueDeep
                          : AppColors.textSecondary,
                      fontSize: 12)),
              if (isToday)
                Text('${s.todayTotal}ml',
                    style: const TextStyle(
                        color: AppColors.softBlueDeep,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
            ],
          );
        }),
      ),
    );
  }

  /// 月:近30天每日总量折线
  Widget _monthlyChart(BuildContext context) {
    final s = context.watch<AppState>();
    final data = s.lastNDays(30).map((d) => d.total.toDouble()).toList();
    return SizedBox(
      height: 140,
      child: CustomPaint(
        size: Size.infinite,
        painter: _LinePainter(data: data, goal: s.todayGoal.toDouble()),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> data;
  final double goal;
  const _LinePainter({required this.data, required this.goal});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (data.length < 2) return;
    final maxV = [data.reduce(max), goal].reduce(max) * 1.15 + 1;
    final points = List.generate(data.length, (i) {
      final x = w * i / (data.length - 1);
      final y = h * 0.9 - (data[i] / maxV) * h * 0.8;
      return Offset(x, y);
    });
    // 目标参考线
    final goalY = h * 0.9 - (goal / maxV) * h * 0.8;
    canvas.drawLine(
      Offset(0, goalY),
      Offset(w, goalY),
      Paint()
        ..color = AppColors.mintDeep.withAlpha(100)
        ..strokeWidth = 1,
    );
    // 折线
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        linePath,
        Paint()
          ..color = AppColors.softBlueDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);
    // 填充
    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();
    canvas.drawPath(
        fillPath, Paint()..color = AppColors.softBlue.withAlpha(80));
    // 点
    for (final p in points) {
      canvas.drawCircle(p, 3, Paint()..color = AppColors.softBlueDeep);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      data != old.data || goal != old.goal;
}

/// 飞书导出按钮
class _FeishuExport extends StatelessWidget {
  const _FeishuExport();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final disabled = s.isGuest || !s.isFeishuBound;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: AbsorbPointer(
          absorbing: disabled,
          child: RippleButton(
            onTap: () async {
              final rate = (s.todayRate * 100).round();
              final msg = '今日喝水统计:\n已喝 ${s.todayTotal}ml / 目标 ${s.todayGoal}ml\n完成率 $rate%\n记录 ${s.records.length} 条';
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在推送至飞书...')),
              );
              final ok = await s.sendFeishuMessage(msg);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '统计已推送至飞书' : '推送失败,请检查网络或飞书配置')),
                );
              }
            },
            borderRadius: AppThemeRadius.m,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.feishu,
                borderRadius: BorderRadius.circular(AppThemeRadius.m),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_upload_outlined,
                      size: 18, color: AppColors.softBlueDeep),
                  const SizedBox(width: 8),
                  Text(disabled ? '登录并绑定飞书后导出' : '导出统计至飞书',
                      style: const TextStyle(
                          color: AppColors.softBlueDeep,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
