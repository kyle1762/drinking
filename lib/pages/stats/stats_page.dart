import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';

// 本文件原为独立「喝水统计」Tab 页面,已与「提醒设置」合并为单一 Tab。
// 保留下方组件供 ReminderPage 引用:喝水打卡、云朵画板。
// 已删除:StatsPage、_Header(周期切换)、_ChartSection(图表)、_FeishuExport(飞书导出)、
// CloudProgressCard、_RainAnimation、RecordList(清理死代码)。

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

/// 快速喝水按键 - 抿一口/喝小口/大口喝/自定义 四按钮并排一排
class _QuickPunchButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Row(
      children: [
        Expanded(child: _punchBtn(context, '抿一口', () => s.addRecord(10))),
        const SizedBox(width: 8),
        Expanded(child: _punchBtn(context, '喝小口', () => s.addRecord(50))),
        const SizedBox(width: 8),
        Expanded(child: _punchBtn(context, '大口喝', () => s.addRecord(200))),
        const SizedBox(width: 8),
        Expanded(child: _punchBtn(context, '自定义', () => _customAmount(context, s))),
      ],
    );
  }

  Widget _punchBtn(BuildContext context, String label, VoidCallback onTap) {
    return Material(
      color: AppColors.softBlue,
      borderRadius: BorderRadius.circular(AppThemeRadius.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemeRadius.s),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.softBlueDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
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
      }
    }
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
            const SizedBox(height: 12),
            RippleButton(
              onTap: () => s.undoLastRecord(),
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
      ),
    );
  }
}

