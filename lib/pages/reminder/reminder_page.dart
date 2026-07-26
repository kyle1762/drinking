import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';
import '../../services/alarm_service.dart';
import '../../services/audio_service.dart';
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
            const RecordList(),
            _ReminderModule(),
            _TimeRangeModule(),
            _DndModule(),
            _EarphoneModule(),
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

  // 快捷间隔:20分钟、40分钟、60分钟
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
            Row(
              children: _quick.asMap().entries.map((entry) {
                final i = entry.key;
                final m = entry.value;
                final selected = s.loopInterval == m;
                return Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(right: i < _quick.length - 1 ? 8 : 0),
                    child: _Chip(
                      label: '$m分钟',
                      selected: selected,
                      onTap: () {
                        // 统一入口:保存配置 + 重注册闹钟 + 同步下次提醒时间
                        s.applyLoopInterval(m);
                      },
                    ),
                  ),
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
                      // 滑动结束时统一应用:重注册闹钟 + 同步下次提醒时间
                      s.applyLoopInterval(v.round());
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
            const SizedBox(height: 16),
            // 立即测试:直接触发通知+音效+飞书(不经过闹钟调度)
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
                  child: const Text('立即测试提醒 (通知+音效+飞书)',
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

/// 免打扰设置 - 午休/夜间开关 + 时间段说明
class _DndModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        const SectionTitle('免打扰'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
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
                  timeRange: '22:00 ~ 次日 07:00',
                  value: s.nightDnd,
                  onChanged: s.setNightDnd,
                  activeColor: AppColors.mintDeep,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('免打扰时段内,闹钟仍正常触发但会静音(通知栏可见)',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ),
      ],
    );
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

/// 扬声器 & 治愈音效设置 - 顶部扬声器总开关 + 音效切换
class _EarphoneModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Column(
      children: [
        const SectionTitle('扬声器 & 治愈音效'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 扬声器提醒总开关(用户可自行关闭)
                Row(
                  children: [
                    const Icon(Icons.volume_up_outlined,
                        size: 20, color: AppColors.softBlueDeep),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('扬声器提醒',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          Text('关闭后仅显示通知,不播放音效',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.speakerEnabled,
                      onChanged: s.setSpeakerEnabled,
                    ),
                  ],
                ),
                const Divider(height: 24),
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
                      onTap: s.speakerEnabled
                          ? () {
                              s.setSound(sd);
                              AudioService.playSound(sd,
                                  volume: s.earphoneVolume);
                            }
                          : null,
                    );
                  }).toList(),
                ),
                if (!s.speakerEnabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('扬声器已关闭,音效切换暂不可用',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 日历 & 闹钟批量操作模块
/// 用户可将提醒时间批量添加到手机日历和闹钟,支持一键清除
class _CalendarAlarmModule extends StatefulWidget {
  @override
  State<_CalendarAlarmModule> createState() => _CalendarAlarmModuleState();
}

class _CalendarAlarmModuleState extends State<_CalendarAlarmModule> {
  List<CalendarEventRef> _calendarRefs = [];
  List<AlarmTimeRecord> _alarmTimes = [];
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
      _alarmTimes = StorageService.loadAlarmTimes();
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

  /// 添加闹钟(打开底部弹窗,用户逐个添加)
  void _batchAddAlarms() {
    if (_reminderTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今日剩余提醒时间为空,请检查作息设置')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AlarmAddSheet(
        times: _reminderTimes,
        alreadyAdded: _alarmTimes,
        onAllDone: (added) async {
          await StorageService.saveAlarmTimes(added);
          if (mounted) {
            setState(() => _alarmTimes = added);
          }
        },
      ),
    );
  }

  /// 一键清除上次添加的日历和闹钟
  void _clearAll() {
    if (_calendarRefs.isEmpty && _alarmTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有已添加的日历事件或闹钟记录')),
      );
      return;
    }

    AppDialogs.confirm(
      context,
      title: '一键清除',
      content: '将删除 ${_calendarRefs.length} 个日历事件'
          '${_alarmTimes.isNotEmpty ? '并打开时钟App引导删除 ${_alarmTimes.length} 个闹钟' : ''}'
          '。是否继续?',
      confirmText: '清除',
      onConfirm: () => _performClear(),
    );
  }

  /// 执行一键清除(在确认对话框后调用)
  Future<void> _performClear() async {
    setState(() => _loading = true);

    // 先保存需要显示的信息(清除前)
    final alarmCount = _alarmTimes.length;
    final alarmListStr = _alarmTimes.map((a) => a.timeStr).join('、');

    int deletedCalendar = 0;
    // 1. 删除日历事件
    if (_calendarRefs.isNotEmpty) {
      deletedCalendar =
          await CalendarAlarmService.clearCalendarEvents(_calendarRefs);
      await StorageService.saveCalendarEventIds([]);
    }

    // 2. 清除闹钟追踪记录(闹钟本身需用户手动删除)
    await StorageService.saveAlarmTimes([]);

    if (mounted) {
      setState(() {
        _calendarRefs = [];
        _alarmTimes = [];
        _loading = false;
      });

      // 3. 如果有闹钟,打开时钟App引导用户手动删除
      if (alarmCount > 0) {
        AppDialogs.confirm(
          context,
          title: '请手动删除闹钟',
          content: '已删除 $deletedCalendar 个日历事件。\n'
              '由于系统限制,闹钟需手动删除。以下 $alarmCount 个闹钟需要删除:\n$alarmListStr\n\n'
              '点击「去删除」打开时钟App。',
          confirmText: '去删除',
          onConfirm: () async {
            await CalendarAlarmService.openAlarmApp();
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 $deletedCalendar 个日历事件')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionTitle('日历 & 闹钟'),
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
                      child: Text('将提醒时间批量添加到手机日历和闹钟',
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

                const SizedBox(height: 8),

                // 添加闹钟按钮
                SizedBox(
                  width: double.infinity,
                  child: RippleButton(
                    onTap: _batchAddAlarms,
                    borderRadius: AppThemeRadius.s,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.softBlue,
                        borderRadius: BorderRadius.circular(AppThemeRadius.s),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.alarm_add_outlined,
                              size: 16, color: AppColors.softBlueDeep),
                          const SizedBox(width: 6),
                          Text(
                            '添加闹钟提醒 ${_alarmTimes.isNotEmpty ? "(已添加${_alarmTimes.length}个)" : ""}',
                            style: const TextStyle(
                                color: AppColors.softBlueDeep,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 一键清除按钮
                if (_calendarRefs.isNotEmpty || _alarmTimes.isNotEmpty) ...[
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
                            Text('一键清除上次添加的日历和闹钟',
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

/// 闹钟添加底部弹窗 - 用户逐个添加闹钟到系统时钟App
class _AlarmAddSheet extends StatefulWidget {
  final List<DateTime> times;
  final List<AlarmTimeRecord> alreadyAdded;
  final Future<void> Function(List<AlarmTimeRecord>) onAllDone;

  const _AlarmAddSheet({
    required this.times,
    required this.alreadyAdded,
    required this.onAllDone,
  });

  @override
  State<_AlarmAddSheet> createState() => _AlarmAddSheetState();
}

class _AlarmAddSheetState extends State<_AlarmAddSheet> {
  late Set<int> _addedIndices;

  @override
  void initState() {
    super.initState();
    // 标记已添加的时间(通过小时+分钟匹配)
    _addedIndices = {};
    for (var i = 0; i < widget.times.length; i++) {
      final t = widget.times[i];
      for (final a in widget.alreadyAdded) {
        if (a.hour == t.hour && a.minute == t.minute) {
          _addedIndices.add(i);
          break;
        }
      }
    }
  }

  Future<void> _addAlarm(int index) async {
    final t = widget.times[index];
    final ok = await CalendarAlarmService.setAlarm(
      hour: t.hour,
      minute: t.minute,
      label: '喝水提醒',
    );
    if (ok && mounted) {
      setState(() {
        _addedIndices.add(index);
      });
      // 更新存储
      final records = <AlarmTimeRecord>[];
      for (var i = 0; i < widget.times.length; i++) {
        if (_addedIndices.contains(i)) {
          final time = widget.times[i];
          records.add(AlarmTimeRecord(
            hour: time.hour,
            minute: time.minute,
          ));
        }
      }
      // 合并已添加的旧记录
      for (final old in widget.alreadyAdded) {
        final exists = records.any(
            (r) => r.hour == old.hour && r.minute == old.minute);
        if (!exists) {
          records.add(old);
        }
      }
      await widget.onAllDone(records);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        widget.times.length - _addedIndices.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.alarm_add_outlined,
                    size: 20, color: AppColors.softBlueDeep),
                const SizedBox(width: 8),
                const Text('添加闹钟提醒',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('$remaining / ${widget.times.length} 待添加',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
                '点击时间添加闹钟到系统时钟App。每个闹钟会在时钟App中打开确认页面,保存后返回继续添加下一个。',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),

            // 时间列表
            ...widget.times.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              final added = _addedIndices.contains(i);
              final timeStr =
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RippleButton(
                  onTap: added ? null : () => _addAlarm(i),
                  borderRadius: AppThemeRadius.s,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: added ? AppColors.mint : AppColors.paused,
                      borderRadius:
                          BorderRadius.circular(AppThemeRadius.s),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          added ? Icons.check_circle : Icons.alarm,
                          size: 18,
                          color: added
                              ? AppColors.mintDeep
                              : AppColors.softBlueDeep,
                        ),
                        const SizedBox(width: 10),
                        Text(timeStr,
                            style: TextStyle(
                              color: added
                                  ? AppColors.mintDeep
                                  : AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            )),
                        const Spacer(),
                        Text(
                          added ? '已添加' : '点击添加',
                          style: TextStyle(
                            color: added
                                ? AppColors.mintDeep
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // 全部添加完成提示
            if (remaining == 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(AppThemeRadius.s),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18, color: AppColors.mintDeep),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('所有闹钟已添加完成!',
                          style: TextStyle(
                              color: AppColors.mintDeep,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

            // 关闭按钮
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: RippleButton(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: AppThemeRadius.s,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.softBlueDeep,
                    borderRadius: BorderRadius.circular(AppThemeRadius.s),
                  ),
                  alignment: Alignment.center,
                  child: const Text('完成',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
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
