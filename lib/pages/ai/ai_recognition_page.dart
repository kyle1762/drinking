import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../dialogs.dart';
import '../../services/ai_service.dart';

class AiRecognitionPage extends StatelessWidget {
  const AiRecognitionPage({super.key});

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
                  _TodaySummary(),
                  SizedBox(height: 16),
                  _ActionCards(),
                  SizedBox(height: 16),
                  SectionTitle('今日记录'),
                  _TodayRecordList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Row(
        children: [
          const Text('AI 饮食与运动',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          RippleButton(
            onTap: () => _openApiKeyDialog(context),
            borderRadius: 20,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.settings_outlined,
                  size: 22, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _openApiKeyDialog(BuildContext context) async {
    final s = context.read<AppState>();
    final currentKey = AiService.apiKey;
    final input = await AppDialogs.inputDialog(
      context,
      title: 'AI 接口配置',
      hint: '请输入 API Key',
      initial: currentKey,
    );
    if (input != null) {
      await AiService.saveApiKey(input);
      s.refreshAiData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(input.isEmpty ? '已清除 API Key' : 'API Key 已保存')),
        );
      }
    }
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        color: AppColors.softBlue,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _summaryItem(
                '摄入',
                '${s.todayFoodCalories}',
                'kcal',
                AppColors.softBlueDeep,
              ),
            ),
            Container(
              width: 1,
              height: 36,
              color: AppColors.softBlueDeep.withAlpha(80),
            ),
            Expanded(
              child: _summaryItem(
                '消耗',
                '${s.todayExerciseCalories}',
                'kcal',
                AppColors.mintDeep,
              ),
            ),
            Container(
              width: 1,
              height: 36,
              color: AppColors.softBlueDeep.withAlpha(80),
            ),
            Expanded(
              child: _summaryItem(
                '净摄入',
                '${s.todayNetCalories}',
                'kcal',
                AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 2),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text('kcal',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCards extends StatelessWidget {
  const _ActionCards();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _actionCard(
              context,
              icon: Icons.restaurant_outlined,
              title: '饮食记录',
              subtitle: '拍照识别食物',
              color: AppColors.softBlue,
              deepColor: AppColors.softBlueDeep,
              onTap: () => _pickAndRecognize(context, AiRecognitionType.food),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionCard(
              context,
              icon: Icons.directions_run_outlined,
              title: '运动记录',
              subtitle: '拍照识别运动',
              color: AppColors.mint,
              deepColor: AppColors.mintDeep,
              onTap: () => _pickAndRecognize(context, AiRecognitionType.exercise),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color deepColor,
    required VoidCallback onTap,
  }) {
    return CreamCard(
      onTap: onTap,
      color: color,
      radius: AppThemeRadius.l,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: deepColor),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  color: deepColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _pickAndRecognize(
      BuildContext context, AiRecognitionType type) async {
    final source = await showModalBottomSheet<_ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _SourceSheet(),
    );
    if (source == null) return;
    if (!context.mounted) return;

    final XFile? file;
    if (source == _ImageSource.camera) {
      file = await AiService.pickFromCamera();
    } else {
      file = await AiService.pickFromGallery();
    }
    if (file == null) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _LoadingDialog(),
    );

    final result = await AiService.recognize(
      type: type,
      imagePath: file.path,
    );

    if (context.mounted) {
      Navigator.pop(context);
    }

    if (result == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('识别失败,请重试')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResultSheet(result: result),
    );
  }
}

enum _ImageSource { camera, gallery }

class _SourceSheet extends StatelessWidget {
  const _SourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: RippleButton(
                  onTap: () => Navigator.pop(context, _ImageSource.camera),
                  borderRadius: AppThemeRadius.m,
                  child: CreamCard(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Row(
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 22, color: AppColors.softBlueDeep),
                        SizedBox(width: 12),
                        Text('拍照',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: RippleButton(
                  onTap: () => Navigator.pop(context, _ImageSource.gallery),
                  borderRadius: AppThemeRadius.m,
                  child: CreamCard(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Row(
                      children: [
                        Icon(Icons.photo_library_outlined,
                            size: 22, color: AppColors.softBlueDeep),
                        SizedBox(width: 12),
                        Text('从相册选择',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.softBlueDeep),
            ),
            SizedBox(height: 12),
            Text('AI 识别中...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ResultSheet extends StatefulWidget {
  const _ResultSheet({required this.result});
  final AiRecognitionResult result;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late double _amount;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _amount = widget.result.type == AiRecognitionType.food ? 150 : 30;
    _nameCtrl = TextEditingController(text: widget.result.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _totalCalories {
    return (widget.result.value * _amount).round();
  }

  Color get _confidenceColor {
    final c = widget.result.confidence;
    if (c >= 0.8) return AppColors.mintDeep;
    if (c >= 0.5) return AppColors.softBlueDeep;
    return const Color(0xFFFFB380);
  }

  @override
  Widget build(BuildContext context) {
    final isFood = widget.result.type == AiRecognitionType.food;
    final lowConfidence = widget.result.confidence < 0.8;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text('AI 识别结果',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              CreamCard(
                radius: 24,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.paused,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: widget.result.imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.file(
                                        File(widget.result.imagePath!),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.image_outlined,
                                      size: 32,
                                      color: AppColors.textDisabled),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _confidenceColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${(widget.result.confidence * 100).round()}%',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_nameCtrl.text,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                isFood
                                    ? '${widget.result.value.toStringAsFixed(0)} kcal / 100g'
                                    : '${widget.result.value.toStringAsFixed(0)} kcal / 分钟',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('$_totalCalories',
                                      style: TextStyle(
                                          color: isFood
                                              ? AppColors.softBlueDeep
                                              : AppColors.mintDeep,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 2),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 3),
                                    child: Text('kcal',
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (lowConfidence) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.banner,
                          borderRadius:
                              BorderRadius.circular(AppThemeRadius.s),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isFood
                                    ? '识别信心度较低,可微调克数确认'
                                    : '识别信心度较低,可微调时长确认',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(isFood ? '克数' : '时长',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          const Spacer(),
                          Text(
                              isFood
                                  ? '${_amount.round()} g'
                                  : '${_amount.round()} 分钟',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Slider(
                        min: isFood ? 20 : 5,
                        max: isFood ? 500 : 180,
                        divisions: isFood ? 48 : 35,
                        value: _amount.clamp(
                          isFood ? 20 : 5,
                          isFood ? 500 : 180,
                        ),
                        activeColor: isFood
                            ? AppColors.softBlueDeep
                            : AppColors.mintDeep,
                        onChanged: (v) {
                          setState(() => _amount = v);
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                    TextField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '名称',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.cream,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppThemeRadius.s),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    if (isFood) ...[
                      const _NutritionBar(carbs: 0.55, protein: 0.2, fat: 0.25),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _NutritionLabel(color: Color(0xFFFFB380), label: '碳水'),
                          _NutritionLabel(color: AppColors.mintDeep, label: '蛋白'),
                          _NutritionLabel(
                              color: AppColors.softBlueDeep, label: '脂肪'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RippleButton(
                      onTap: () => Navigator.pop(context),
                      borderRadius: AppThemeRadius.m,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.paused,
                          borderRadius:
                              BorderRadius.circular(AppThemeRadius.m),
                        ),
                        alignment: Alignment.center,
                        child: const Text('取消',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RippleButton(
                      onTap: () => _confirm(context),
                      borderRadius: AppThemeRadius.m,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              isFood ? AppColors.softBlue : AppColors.mint,
                          borderRadius:
                              BorderRadius.circular(AppThemeRadius.m),
                        ),
                        alignment: Alignment.center,
                        child: Text('确认计入',
                            style: TextStyle(
                                color: isFood
                                    ? AppColors.softBlueDeep
                                    : AppColors.mintDeep,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm(BuildContext context) {
    final s = context.read<AppState>();
    final isFood = widget.result.type == AiRecognitionType.food;
    final name = _nameCtrl.text.trim().isEmpty
        ? widget.result.name
        : _nameCtrl.text.trim();

    if (isFood) {
      s.addFoodRecord(FoodRecord(
        id: 'f${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        name: name,
        calories: _totalCalories,
        grams: _amount.round(),
        imagePath: widget.result.imagePath,
      ));
    } else {
      s.addExerciseRecord(ExerciseRecord(
        id: 'e${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        name: name,
        calories: _totalCalories,
        minutes: _amount.round(),
        imagePath: widget.result.imagePath,
      ));
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已记录 $name $_totalCalories kcal')),
    );
  }
}

class _NutritionBar extends StatelessWidget {
  const _NutritionBar({
    required this.carbs,
    required this.protein,
    required this.fat,
  });
  final double carbs;
  final double protein;
  final double fat;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            flex: (carbs * 100).round(),
            child: Container(height: 8, color: const Color(0xFFFFB380)),
          ),
          Expanded(
            flex: (protein * 100).round(),
            child: Container(height: 8, color: AppColors.mintDeep),
          ),
          Expanded(
            flex: (fat * 100).round(),
            child: Container(height: 8, color: AppColors.softBlueDeep),
          ),
        ],
      ),
    );
  }
}

class _NutritionLabel extends StatelessWidget {
  const _NutritionLabel({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: all.map((item) => _buildItem(context, item)).toList(),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, dynamic item) {
    final isFood = item is FoodRecord;
    final name = isFood ? item.name : (item as ExerciseRecord).name;
    final calories = isFood ? item.calories : (item as ExerciseRecord).calories;
    final subtitle =
        isFood ? '${item.grams} g' : '${(item as ExerciseRecord).minutes} 分钟';
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
                  color: isFood
                      ? AppColors.softBlueDeep
                      : AppColors.mintDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
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
