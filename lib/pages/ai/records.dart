part of 'ai_recognition_page.dart';

/// 本日热量记录 - 可展开卡片
/// 收起时显示精简统计(记录数+总热量),展开时内联显示完整列表
class _TodayRecordExpandable extends StatefulWidget {
  const _TodayRecordExpandable();

  @override
  State<_TodayRecordExpandable> createState() => _TodayRecordExpandableState();
}

class _TodayRecordExpandableState extends State<_TodayRecordExpandable> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final foodRecords = s.todayFoodRecords;
    final exerciseRecords = s.todayExerciseRecords;
    final totalCount = foodRecords.length + exerciseRecords.length;
    final hasRecords = totalCount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          children: [
            // 头部(可点击展开/收起)
            RippleButton(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: hasRecords ? AppColors.softBlue : AppColors.paused,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: hasRecords
                            ? AppColors.softBlueDeep
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('本日热量记录',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            hasRecords
                                ? '$totalCount 条记录 · 摄入 ${s.todayFoodCalories} / 消耗 ${s.todayExerciseCalories} kcal'
                                : '还没有记录,点击上方卡片开始记录~',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.chevron_right,
                          size: 20, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            // 展开内容(内联显示完整列表)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: _TodayRecordList(),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayRecordList extends StatelessWidget {
  const _TodayRecordList();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final foodRecords = s.todayFoodRecords;
    final exerciseRecords = s.todayExerciseRecords;

    if (foodRecords.isEmpty && exerciseRecords.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('还没有记录,点击上方卡片开始记录~',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
      );
    }

    final all = <dynamic>[
      ...foodRecords,
      ...exerciseRecords,
    ]..sort((a, b) => b.time.compareTo(a.time));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('共 ${all.length} 条记录',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        ...all.map((item) => _buildItem(context, item)),
      ],
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// 编辑运动记录:重新打开手动输入运动 sheet(预填),保存时更新原记录
  void _editExercise(BuildContext context, ExerciseRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExerciseRecordSheet(initial: record),
    );
  }

  Widget _buildItem(BuildContext context, dynamic item) {
    final isFood = item is FoodRecord;
    final name = isFood ? item.name : (item as ExerciseRecord).name;
    final calories = isFood ? item.calories : (item as ExerciseRecord).calories;
    final time = isFood ? item.time : (item as ExerciseRecord).time;
    final subtitle = isFood
        ? '${item.grams} g · ${_formatTime(time)}'
        : '${(item as ExerciseRecord).reps} 次 · ${_formatTime(time)}';
    final id = isFood ? item.id : (item as ExerciseRecord).id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isFood ? AppColors.softBlue : AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFood
                  ? Icons.restaurant_outlined
                  : Icons.directions_run_outlined,
              size: 18,
              color: isFood ? AppColors.softBlueDeep : AppColors.mintDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text('$calories kcal',
              style: TextStyle(
                  color: isFood ? AppColors.softBlueDeep : AppColors.mintDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          // 运动记录支持编辑修改(修改后落盘)
          if (!isFood) ...[
            RippleButton(
              onTap: () => _editExercise(context, item),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 2),
          ],
          RippleButton(
            onTap: () => AppDialogs.confirm(
              context,
              title: '删除记录?',
              content: '将移除 $name 的记录',
              onConfirm: () {
                final s = context.read<AppState>();
                if (isFood) {
                  s.removeFoodRecord(id);
                } else {
                  s.removeExerciseRecord(id);
                }
              },
              confirmText: '删除',
            ),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.delete_outline,
                  size: 18, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 周记录列表
class _WeeklyRecordList extends StatelessWidget {
  const _WeeklyRecordList();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final records = s.weeklyRecords;

    if (records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text('暂无周记录(每周末自动记录 BMI 和本周消耗热量)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );
    }

    final reversed = records.reversed.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: reversed.map((r) => _buildItem(context, r)).toList(),
        ),
      ),
    );
  }

  String _formatDate(DateTime t) {
    return '${t.month}/${t.day}';
  }

  /// 展示本周每日消耗详情 sheet
  void _showWeeklyDetail(BuildContext context, WeeklyRecord r) {
    // 周一~周日的日期
    final monday =
        r.date.subtract(Duration(days: r.date.weekday - 1));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text('${r.date.month}月${r.date.day}日 本周消耗详情',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 16),
                  // BMI + 周总消耗概览
                  Row(
                    children: [
                      _detailStat('本周消耗',
                          '${r.weeklyBurnCalories} kcal', AppColors.mintDeep),
                      const SizedBox(width: 12),
                      _detailStat(
                          'BMI', r.bmi?.toStringAsFixed(1) ?? '--', AppColors.softBlueDeep),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('每日消耗热量(运动)',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  _dailyBars(r, monday),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// 周一~周日每日常量柱状图
  Widget _dailyBars(WeeklyRecord r, DateTime monday) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    final daily = r.dailyBurnCalories;
    final hasData = daily.isNotEmpty;
    final max = hasData && daily.reduce((a, b) => a > b ? a : b) > 0
        ? daily.reduce((a, b) => a > b ? a : b).toDouble()
        : 1.0;
    final nowDate = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return Column(
      children: List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final value = hasData && i < daily.length ? daily[i] : 0;
        final ratio = hasData ? (value / max).clamp(0.0, 1.0) : 0.0;
        final isToday = DateTime(day.year, day.month, day.day)
            .isAtSameMomentAs(nowDate);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('周${names[i]}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 40,
                child: Text(
                  '${day.month}/${day.day}',
                  style: const TextStyle(
                      color: AppColors.textDisabled, fontSize: 10),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.paused,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.mintDeep : AppColors.mint,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: Text(
                  '$value kcal',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: isToday ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildItem(BuildContext context, WeeklyRecord r) {
    final bmiText = r.bmi != null ? r.bmi!.toStringAsFixed(1) : '--';
    return InkWell(
      onTap: () => _showWeeklyDetail(context, r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_outlined,
                  size: 18, color: AppColors.mintDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDate(r.date),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text('BMI: $bmiText',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('本周消耗',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 10)),
                SizedBox(height: 2),
              ],
            ),
            const SizedBox(width: 4),
            Text('${r.weeklyBurnCalories} kcal',
                style: const TextStyle(
                    color: AppColors.mintDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
