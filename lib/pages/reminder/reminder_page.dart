import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';
import '../../services/alarm_service.dart';
import '../../services/notification_service.dart';
import '../../services/calendar_alarm_service.dart';
import '../../services/storage_service.dart';
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
            // 免打扰状态提示(仅在免打扰时段显示)
            if (s.inDndPeriod)
              SoftBanner(
                icon: Icons.do_not_disturb_on_outlined,
                text: '当前处于${s.dndStatusText},提醒将静音(闹钟仍正常触发)',
              ),
            const PunchButton(),
            const SizedBox(height: 8),
            const _TodayRecordExpandable(),
            _ReminderModule(),
            _DndModule(),
            _CalendarAlarmModule(),
            const SizedBox(height: 16),
            _BottomActions(),
          ],
        ),
      ),
    );
  }
}

/// 顶部 - 今日概览(左) + 云朵图像(右),各占一半
class _SplitHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左:今日概览
            Expanded(
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
                            size: 16, color: AppColors.softBlueDeep),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text('今日概览',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
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
                    const SizedBox(height: 8),
                    _overviewItem('下次提醒', s.nextReminderTime),
                    _overviewItem('当前间隔', '${s.loopInterval} 分钟'),
                    _overviewItem('今日已提醒', '${s.todayReminderCount} 次'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 右:云朵图像
            Expanded(
              child: _CloudCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: AppColors.softBlueDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// 云朵图像卡片 - 显示今日饮水进度(云朵+总量/目标)
class _CloudCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final rate = s.todayRate.clamp(0.0, 1.0);
    return CreamCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: CustomPaint(
                size: const Size(120, 80),
                painter: CloudPainter(rate),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${s.todayTotal}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.softBlueDeep)),
          Text('/ ${s.todayGoal} ml',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text('${(rate * 100).round()}%',
              style: const TextStyle(
                  color: AppColors.mintDeep,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// 定时提醒模块 - 循环/单次双标签
class _ReminderModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 4),
        _LoopReminder(),
      ],
    );
  }
}

/// 循环提醒 - 快捷间隔(20/60分钟) + 两侧±5分钟微调
class _LoopReminder extends StatelessWidget {
  const _LoopReminder();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行:左为「定时提醒」,右为当前间隔时间
            Row(
              children: [
                const Text('定时提醒',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
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
            const SizedBox(height: 12),
            // 间隔按钮行: [-5分钟] [20分钟] [60分钟] [+5分钟]
            Row(
              children: [
                _stepButton(
                  icon: Icons.remove,
                  onTap: () => _adjustInterval(s, -5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Chip(
                    label: '20分钟',
                    selected: s.loopInterval == 20,
                    onTap: () => s.applyLoopInterval(20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Chip(
                    label: '60分钟',
                    selected: s.loopInterval == 60,
                    onTap: () => s.applyLoopInterval(60),
                  ),
                ),
                const SizedBox(width: 8),
                _stepButton(
                  icon: Icons.add,
                  onTap: () => _adjustInterval(s, 5),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('点击 20/60 分钟快速切换,或点击 ±5 分钟微调(最小1分钟)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            // 立即测试:直接触发通知+飞书(不经过闹钟调度)
            SizedBox(
              width: double.infinity,
              child: RippleButton(
                onTap: () async {
                  await NotificationService.onTestAlarmFired();
                },
                borderRadius: AppThemeRadius.s,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(AppThemeRadius.s),
                  ),
                  alignment: Alignment.center,
                  child: const Text('立即测试提醒 (通知+飞书)',
                      style: TextStyle(
                          color: AppColors.mintDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 闹钟测试:5秒后通过闹钟调度触发(验证闹钟机制)
            SizedBox(
              width: double.infinity,
              child: RippleButton(
                onTap: () async {
                  try {
                    final ok = await AlarmService.scheduleTest();
                    debugPrint('[TestBtn] scheduleTest 返回: $ok');
                  } catch (e) {
                    debugPrint('[TestBtn] scheduleTest 异常: $e');
                  }
                },
                borderRadius: AppThemeRadius.s,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(AppThemeRadius.s),
                  ),
                  alignment: Alignment.center,
                  child: const Text('闹钟测试 (5秒后触发)',
                      style: TextStyle(
                          color: AppColors.softBlueDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
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
    // 统一入口:保存配置 + 重注册闹钟 + 同步下次提醒时间
    s.applyLoopInterval(newInterval);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
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
                color: disabled
                    ? AppColors.textDisabled
                    : (selected
                        ? AppColors.softBlueDeep
                        : AppColors.textSecondary),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
        ),
      ),
    );
  }
}

/// 免打扰设置 - 浮空展开界面(点击免打扰按钮才显示午休/夜间选项)
class _DndModule extends StatefulWidget {
  @override
  State<_DndModule> createState() => _DndModuleState();
}

class _DndModuleState extends State<_DndModule> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 免打扰按钮(点击展开/收起)
            RippleButton(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: AppThemeRadius.s,
              child: Row(
                children: [
                  const Icon(Icons.do_not_disturb_on_outlined,
                      size: 20, color: AppColors.softBlueDeep),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('免打扰',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  // 当前已启用的免打扰项简要状态
                  Text(
                    _statusSummary(s),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // 浮空展开内容
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 午休免打扰
                            _dndRow(
                              icon: Icons.free_breakfast_outlined,
                              title: '午休免打扰',
                              timeRange: '12:30 ~ 14:30',
                              value: s.noonDnd,
                              onChanged: s.setNoonDnd,
                              activeColor: AppColors.softBlueDeep,
                            ),
                            const Divider(height: 1),
                            // 夜间免打扰
                            _dndRow(
                              icon: Icons.nightlight_round_outlined,
                              title: '夜间免打扰',
                              timeRange: '22:00 ~ 次日 08:00',
                              value: s.nightDnd,
                              onChanged: s.setNightDnd,
                              activeColor: AppColors.mintDeep,
                            ),
                            const SizedBox(height: 6),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  '免打扰时段内,闹钟仍正常触发但会静音(通知栏可见)',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// 当前已启用的免打扰简要状态
  String _statusSummary(AppState s) {
    final list = <String>[];
    if (s.noonDnd) list.add('午休');
    if (s.nightDnd) list.add('夜间');
    return list.isEmpty ? '未启用' : list.join('、');
  }

  Widget _dndRow({
    required IconData icon,
    required String title,
    required String timeRange,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: activeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Text('时段:$timeRange',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: activeColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 日历批量操作模块
/// 用户可将提醒时间批量添加到手机日历,支持一键清除
class _CalendarAlarmModule extends StatefulWidget {
  @override
  State<_CalendarAlarmModule> createState() => _CalendarAlarmModuleState();
}

class _CalendarAlarmModuleState extends State<_CalendarAlarmModule> {
  List<CalendarEventRef> _calendarRefs = [];
  List<DateTime> _reminderTimes = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final s = context.read<AppState>();
    setState(() {
      _calendarRefs = StorageService.loadCalendarEventIds();
      _reminderTimes = CalendarAlarmService.generateReminderTimes(
        wakeTime: s.profile.wakeTime,
        bedTime: s.profile.bedTime,
        intervalMinutes: s.loopInterval,
      );
    });
  }

  /// 批量添加日历事件
  Future<void> _batchAddCalendar() async {
    if (_reminderTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今日剩余提醒时间为空,请检查作息设置')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      // 先清除上次的日历事件,避免重复
      if (_calendarRefs.isNotEmpty) {
        await CalendarAlarmService.clearCalendarEvents(_calendarRefs);
      }
      final refs = await CalendarAlarmService.batchAddCalendarEvents(
        title: '喝水提醒',
        times: _reminderTimes,
      );
      await StorageService.saveCalendarEventIds(refs);
      if (mounted) {
        setState(() {
          _calendarRefs = refs;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(refs.isEmpty
                ? '日历事件添加失败,请检查日历权限'
                : '已添加 ${refs.length} 个日历提醒事件(每日重复)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('日历添加异常: $e')),
        );
      }
    }
  }

  /// 一键清除上次添加的日历事件
  void _clearAll() {
    if (_calendarRefs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有已添加的日历事件')),
      );
      return;
    }

    AppDialogs.confirm(
      context,
      title: '一键清除',
      content: '将删除 ${_calendarRefs.length} 个日历事件。是否继续?',
      confirmText: '清除',
      onConfirm: () => _performClear(),
    );
  }

  /// 执行一键清除(在确认对话框后调用)
  Future<void> _performClear() async {
    setState(() => _loading = true);

    int deletedCalendar = 0;
    if (_calendarRefs.isNotEmpty) {
      deletedCalendar =
          await CalendarAlarmService.clearCalendarEvents(_calendarRefs);
      await StorageService.saveCalendarEventIds([]);
    }

    if (mounted) {
      setState(() {
        _calendarRefs = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 $deletedCalendar 个日历事件')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionTitle('日历'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 说明文字
                const Row(
                  children: [
                    Icon(Icons.event_available_outlined,
                        size: 16, color: AppColors.softBlueDeep),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text('将提醒时间批量添加到手机日历',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 今日提醒时间预览
                if (_reminderTimes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.paused,
                      borderRadius: BorderRadius.circular(AppThemeRadius.s),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日剩余 ${_reminderTimes.length} 个提醒时间',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _reminderTimes.take(8).map((t) {
                            return Text(
                              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  color: AppColors.softBlueDeep,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            );
                          }).toList(),
                        ),
                        if (_reminderTimes.length > 8)
                          const Text('...',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // 添加日历按钮
                SizedBox(
                  width: double.infinity,
                  child: RippleButton(
                    onTap: _loading ? null : _batchAddCalendar,
                    borderRadius: AppThemeRadius.s,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(AppThemeRadius.s),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: AppColors.mintDeep),
                          const SizedBox(width: 6),
                          Text(
                            _loading
                                ? '正在添加...'
                                : '添加日历提醒 ${_calendarRefs.isNotEmpty ? "(已添加${_calendarRefs.length}个)" : ""}',
                            style: const TextStyle(
                                color: AppColors.mintDeep,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 一键清除按钮
                if (_calendarRefs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: RippleButton(
                      onTap: _loading ? null : _clearAll,
                      borderRadius: AppThemeRadius.s,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.paused,
                          borderRadius:
                              BorderRadius.circular(AppThemeRadius.s),
                          border: Border.all(
                              color: AppColors.textSecondary.withAlpha(50)),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline,
                                size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 6),
                            Text('一键清除上次添加的日历事件',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 今日记录 - 浮空展开按钮(收起显示记录数,展开显示完整列表)
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
    final count = s.records.length;
    final totalMl = s.todayTotal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行(点击展开/收起)
            RippleButton(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: AppThemeRadius.s,
              child: Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 20, color: AppColors.softBlueDeep),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('今日记录',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    count == 0 ? '暂无记录' : '$count 条 · ${totalMl}ml',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // 浮空展开内容
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: count == 0
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text('还没有记录,喝口水开始吧~',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13)),
                                ),
                              )
                            : Column(
                                children: s.records
                                    .map((r) => _recordItem(context, r, s))
                                    .toList(),
                              ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordItem(BuildContext context, WaterRecord r, AppState s) {
    final time =
        '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
                color: AppColors.softBlue, shape: BoxShape.circle),
            child: const Icon(Icons.water_drop,
                size: 16, color: AppColors.softBlueDeep),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
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
                  size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
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
                final ok = s.reminderEnabled && !s.reminderPaused;
                if (ok) {
                  // 统一入口:保存配置 + 重注册闹钟 + 同步下次提醒时间
                  final success = await s.applyLoopInterval(s.loopInterval);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? '设置已保存,下次提醒:${s.nextReminderTime}'
                            : '设置已保存(闹钟注册失败,请检查权限)'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  await AlarmService.cancelLoop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('提醒已关闭/暂停,闹钟已取消'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
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
              } else {
                // 恢复时使用统一入口,确保下次提醒时间同步刷新
                await s.applyLoopInterval(s.loopInterval);
              }
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
