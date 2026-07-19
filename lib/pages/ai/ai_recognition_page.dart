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
                  _ApiKeyCard(),
                  SizedBox(height: 12),
                  _TodaySummary(),
                  SizedBox(height: 16),
                  _ActionCards(),
                  SizedBox(height: 16),
                  SectionTitle('本日热量记录'),
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('饮食与运动',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// API Key 配置卡片 - 外显在页面上
class _ApiKeyCard extends StatefulWidget {
  const _ApiKeyCard();

  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  late TextEditingController _ctrl;
  bool _obscure = true;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: AiService.apiKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = AiService.hasApiKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        color: configured ? AppColors.mint : AppColors.softBlue,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  configured ? Icons.check_circle_outline : Icons.key_outlined,
                  size: 18,
                  color:
                      configured ? AppColors.mintDeep : AppColors.softBlueDeep,
                ),
                const SizedBox(width: 6),
                Text(
                  configured ? 'API Key 已配置' : 'API Key 未配置',
                  style: TextStyle(
                    color: configured
                        ? AppColors.mintDeep
                        : AppColors.softBlueDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                RippleButton(
                  onTap: () => setState(() => _editing = !_editing),
                  borderRadius: 12,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      _editing ? '收起' : '修改',
                      style: TextStyle(
                        color: configured
                            ? AppColors.mintDeep
                            : AppColors.softBlueDeep,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_editing) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: '输入 API Key',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: RippleButton(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RippleButton(
                    onTap: _saveKey,
                    borderRadius: AppThemeRadius.s,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: configured
                            ? AppColors.mintDeep
                            : AppColors.softBlueDeep,
                        borderRadius: BorderRadius.circular(AppThemeRadius.s),
                      ),
                      child: const Text('保存',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _saveKey() async {
    final key = _ctrl.text.trim();
    await AiService.saveApiKey(key);
    if (mounted) {
      context.read<AppState>().refreshAiData();
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(key.isEmpty ? '已清除 API Key' : 'API Key 已保存')),
      );
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
                    color: color, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(width: 2),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text('kcal',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11)),
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
              onTap: () =>
                  _pickAndRecognize(context, AiRecognitionType.exercise),
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
                  color: deepColor, fontSize: 15, fontWeight: FontWeight.w700)),
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
  late TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    // 食物默认 150g,运动默认 30 次
    _amount = widget.result.type == AiRecognitionType.food ? 150 : 30;
    _nameCtrl = TextEditingController(text: widget.result.name);
    _amountCtrl = TextEditingController(text: _amount.round().toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  /// 总热量(kcal)
  /// 食物: value(kcal/100g) * amount(g) / 100
  /// 运动: value(kcal/次) * amount(次)
  int get _totalCalories {
    if (widget.result.type == AiRecognitionType.food) {
      return (widget.result.value * _amount / 100).round();
    }
    return (widget.result.value * _amount).round();
  }

  Color get _confidenceColor {
    final c = widget.result.confidence;
    if (c >= 0.8) return AppColors.mintDeep;
    if (c >= 0.5) return AppColors.softBlueDeep;
    return const Color(0xFFFFB380);
  }

  /// 同步滑块和输入框
  void _setAmount(double v, {bool fromInput = false}) {
    setState(() {
      _amount = v;
      if (!fromInput) {
        _amountCtrl.text = v.round().toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFood = widget.result.type == AiRecognitionType.food;
    final lowConfidence = widget.result.confidence < 0.8;
    // 单位与文案
    final String unit = isFood ? '克' : '次';
    final String unitSymbol = isFood ? 'g' : '次';
    final String amountLabel = isFood ? '本次食物摄入量' : '本次运动量';
    final String valueUnitLabel = isFood
        ? '${widget.result.value.toStringAsFixed(0)} kcal / 100g'
        : '${widget.result.value.toStringAsFixed(2)} kcal / 次';
    // 滑块范围
    final double minAmt = isFood ? 10 : 1;
    final double maxAmt = isFood ? 1000 : 200;

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
                                      size: 32, color: AppColors.textDisabled),
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
                                valueUnitLabel,
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
                    // 提醒文案:本次食物摄入量 / 本次运动量
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFood ? AppColors.softBlue : AppColors.mint,
                        borderRadius: BorderRadius.circular(AppThemeRadius.s),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note,
                              size: 14,
                              color: isFood
                                  ? AppColors.softBlueDeep
                                  : AppColors.mintDeep),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '请输入$amountLabel(单位:$unit)',
                              style: TextStyle(
                                  color: isFood
                                      ? AppColors.softBlueDeep
                                      : AppColors.mintDeep,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (lowConfidence) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.banner,
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isFood ? '识别信心度较低,可微调克数确认' : '识别信心度较低,可微调次数确认',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // 数量输入框 + 滑块(始终显示)
                    Row(
                      children: [
                        Text(amountLabel,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.cream,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppThemeRadius.s),
                                borderSide: BorderSide.none,
                              ),
                              suffixText: unitSymbol,
                              suffixStyle: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            onChanged: (text) {
                              final v = double.tryParse(text);
                              if (v != null && v >= 0) {
                                _setAmount(v.clamp(minAmt, maxAmt),
                                    fromInput: true);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Slider(
                      min: minAmt,
                      max: maxAmt,
                      divisions: isFood ? 99 : 199,
                      value: _amount.clamp(minAmt, maxAmt),
                      activeColor:
                          isFood ? AppColors.softBlueDeep : AppColors.mintDeep,
                      onChanged: (v) => _setAmount(v),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: '名称(可修改)',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
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
                          _NutritionLabel(
                              color: Color(0xFFFFB380), label: '碳水'),
                          _NutritionLabel(
                              color: AppColors.mintDeep, label: '蛋白'),
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
                          borderRadius: BorderRadius.circular(AppThemeRadius.m),
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
                          color: isFood ? AppColors.softBlue : AppColors.mint,
                          borderRadius: BorderRadius.circular(AppThemeRadius.m),
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
    final amount = _amount.round();

    if (isFood) {
      s.addFoodRecord(FoodRecord(
        id: 'f${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        name: name,
        calories: _totalCalories,
        grams: amount,
        imagePath: widget.result.imagePath,
      ));
    } else {
      s.addExerciseRecord(ExerciseRecord(
        id: 'e${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        name: name,
        calories: _totalCalories,
        reps: amount,
        imagePath: widget.result.imagePath,
      ));
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '已记录 $name ${isFood ? "$amount g" : "$amount 次"} $_totalCalories kcal')),
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

  /// 格式化时间为 HH:mm
  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildItem(BuildContext context, dynamic item) {
    final isFood = item is FoodRecord;
    final name = isFood ? item.name : (item as ExerciseRecord).name;
    final calories = isFood ? item.calories : (item as ExerciseRecord).calories;
    final time = isFood ? item.time : (item as ExerciseRecord).time;
    // 食物单位:克;运动单位:次
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
