import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';
import '../../services/ai_service.dart';
import '../../services/storage_service.dart';
import '../../data/food_nutrition.dart';
import '../../data/diet_methods.dart';

part 'cards.dart';
part 'sheets.dart';
part 'records.dart';


class AiRecognitionPage extends StatefulWidget {
  const AiRecognitionPage({super.key});

  @override
  State<AiRecognitionPage> createState() => _AiRecognitionPageState();
}

class _AiRecognitionPageState extends State<AiRecognitionPage> {
  @override
  void initState() {
    super.initState();
    // 每日首次进入热量追踪页:提醒用户更新个人信息(体重/肌肉量等)
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRemindUpdate());
  }

  /// 仅当日首次打开时提醒更新个人信息
  void _maybeRemindUpdate() {
    final today =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final last = StorageService.getLastProfileRemindDate();
    if (last == today) return;
    // 首次进入或跨天:记录今日已提醒,并弹窗提示
    StorageService.saveLastProfileRemindDate(today);
    if (!mounted) return;
    AppDialogs.confirm(
      context,
      title: '每日打卡提醒',
      content: '建议每天更新体重和肌肉量,以便更精准地计算基础代谢与每日消耗。是否现在更新?',
      confirmText: '去更新',
      onConfirm: () {
        // _ProfileCard 是独立 widget,无法直接控制其编辑状态;
        // 这里滚动到个人信息卡片并提示用户点击"编辑"
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请点击上方「个人信息」卡片的「编辑」按钮更新数据')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: const [
                  SizedBox(height: 8),
                  _InfoCardRow(),
                  SizedBox(height: 12),
                  _IntakeWarningCard(),
                  SizedBox(height: 12),
                  _CalorieDialCard(),
                  SizedBox(height: 12),
                  _DietMethodCard(),
                  SizedBox(height: 16),
                  _ActionCards(),
                  SizedBox(height: 16),
                  _TodayRecordExpandable(),
                  SizedBox(height: 16),
                  SectionTitle('周记录'),
                  _WeeklyRecordList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

