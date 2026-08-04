part of 'ai_recognition_page.dart';

/// 记录类型选择 sheet(食物/运动)
class _RecordTypeSheet extends StatelessWidget {
  const _RecordTypeSheet();

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
              const SizedBox(height: 12),
              const Text('选择记录类型',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _typeItem(
                context,
                icon: Icons.restaurant_outlined,
                title: '记录食物',
                subtitle: '拍照识别菜品/营养成分表,或手动输入食材',
                color: AppColors.softBlue,
                deepColor: AppColors.softBlueDeep,
                type: AiRecognitionType.food,
              ),
              const SizedBox(height: 8),
              _typeItem(
                context,
                icon: Icons.directions_run_outlined,
                title: '记录运动',
                subtitle: '拍照识别运动,或手动输入运动名称',
                color: AppColors.mint,
                deepColor: AppColors.mintDeep,
                type: AiRecognitionType.exercise,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color deepColor,
    required AiRecognitionType type,
  }) {
    return SizedBox(
      width: double.infinity,
      child: RippleButton(
        onTap: () => Navigator.pop(context, type),
        borderRadius: AppThemeRadius.m,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppThemeRadius.m),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: deepColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: deepColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: deepColor),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ImageSource { camera, gallery, manual }

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({this.withManual = false, this.isFood = false});
  final bool withManual;
  final bool isFood;

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
              const SizedBox(height: 12),
              // 提示文案:预包装食品建议直接拍营养成分表
              if (isFood) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius:
                        BorderRadius.circular(AppThemeRadius.s),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: AppColors.softBlueDeep),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '小贴士:预包装食品(如饼干、饮料、零食)建议直接拍摄包装上的「营养成分表」,识别更精准',
                          style: TextStyle(
                            color: AppColors.softBlueDeep,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _sourceItem(context, Icons.camera_alt_outlined, '拍照',
                  _ImageSource.camera),
              const SizedBox(height: 8),
              _sourceItem(context, Icons.photo_library_outlined, '从相册选择',
                  _ImageSource.gallery),
              if (withManual) ...[
                const SizedBox(height: 8),
                _sourceItem(
                    context,
                    Icons.edit_outlined,
                    isFood ? '手动输入食材' : '手动输入运动名称',
                    _ImageSource.manual),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceItem(
      BuildContext context, IconData icon, String label, _ImageSource src) {
    return SizedBox(
      width: double.infinity,
      child: RippleButton(
        onTap: () => Navigator.pop(context, src),
        borderRadius: AppThemeRadius.m,
        child: CreamCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.softBlueDeep),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
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

/// 手动输入饮食 bottom sheet
/// 用户输入本次菜品包含的食材(逗号分隔),系统查询每个食材的营养并计算 kcal/100g
/// 用户确认摄入克数后记录到 FoodRecord
class _ManualFoodSheet extends StatefulWidget {
  const _ManualFoodSheet();

  @override
  State<_ManualFoodSheet> createState() => _ManualFoodSheetState();
}

class _ManualFoodSheetState extends State<_ManualFoodSheet> {
  late TextEditingController _ingredientCtrl;
  late TextEditingController _amountCtrl;
  double _amount = 150;
  List<FoodIngredient> _ingredients = [];
  bool _lookingUp = false;
  bool _confirmed = false;
  // 用户手动编辑的每100g营养(覆盖基于食材计算的结果)
  FoodNutrition? _overrideNutrition;
  // 当前食材是否来自已保存的配方(命中则不再询问是否保存)
  bool _usedSavedRecipe = false;
  // 用户输入的原始菜名(单菜名时用于保存配方)
  String _dishName = '';

  @override
  void initState() {
    super.initState();
    _ingredientCtrl = TextEditingController();
    _amountCtrl = TextEditingController(text: '150');
  }

  @override
  void dispose() {
    _ingredientCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  /// 占比总和(用于归一化,用户编辑后占比之和可能≠1)
  double get _ratioSum =>
      _ingredients.fold(0.0, (s, e) => s + e.ratio);

  /// 占比合计百分比(显示用)
  int get ratioSumPercent => (_ratioSum * 100).round();

  /// 实时计算的每100g热量(优先用户覆盖值,否则基于食材列表+占比归一化)
  double get _kcalPer100g {
    if (_overrideNutrition != null) return _overrideNutrition!.energy;
    final sum = _ratioSum;
    if (sum <= 0) return 0;
    double total = 0;
    for (final ing in _ingredients) {
      final nut = FoodNutritionDB.lookup(ing.name);
      final kcal = nut?.energy ?? 150; // 未匹配按默认混合菜品
      total += kcal * (ing.ratio / sum);
    }
    return total;
  }

  /// 总热量(基于 kcal/100g * 摄入量)
  int get _totalCalories =>
      (_kcalPer100g * _amount / 100).round();

  ({double protein, double fat, double carbs, double fiber})
      get _nutrition {
    // 用户已编辑过营养:直接按克数线性缩放
    if (_overrideNutrition != null) {
      final scaled = _overrideNutrition!.scaled(_amount);
      return (
        protein: scaled.protein,
        fat: scaled.fat,
        carbs: scaled.carbs,
        fiber: scaled.fiber,
      );
    }
    final sum = _ratioSum;
    if (sum <= 0) return (protein: 0, fat: 0, carbs: 0, fiber: 0);
    double p = 0, f = 0, c = 0, fi = 0;
    for (final ing in _ingredients) {
      final nut = FoodNutritionDB.lookup(ing.name);
      if (nut != null) {
        final grams = _amount * (ing.ratio / sum);
        final scaled = nut.scaled(grams);
        p += scaled.protein;
        f += scaled.fat;
        c += scaled.carbs;
        fi += scaled.fiber;
      }
    }
    return (protein: p, fat: f, carbs: c, fiber: fi);
  }

  /// 更新某食材占比(用户手动编辑)
  /// 修改占比后清除手动覆盖的营养值,让热量随占比重新计算
  void _updateRatio(int index, double ratio) {
    setState(() {
      final clamped = ratio.clamp(0.0, 1.0);
      _ingredients[index] =
          FoodIngredient(name: _ingredients[index].name, ratio: clamped);
      _overrideNutrition = null;
    });
  }

  /// 删除某食材
  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
      if (_ingredients.isEmpty) _confirmed = false;
    });
  }

  /// 解析用户输入:
  /// - 单个菜名(无分隔符)→ 调用 AI 识别菜品中的食材及占比(可编辑)
  /// - 多个食材(逗号/顿号/空格分隔)→ 按等占比处理
  /// 之后对每个食材查询本地营养表,未匹配则调用 AI 补全并持久化
  Future<void> _lookupIngredients() async {
    final text = _ingredientCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请输入菜品或食材名称')),
      );
      return;
    }

    // 判断是否为多食材输入(含分隔符)
    final tokens = text
        .split(RegExp(r'[,，、\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return;
    final isMulti = tokens.length > 1;

    setState(() => _lookingUp = true);

    final ingredients = <FoodIngredient>[];
    int aiRecognized = 0;
    bool usedSavedRecipe = false;

    if (!isMulti) {
      // 单菜名:优先查找用户保存的配方(永久记录的食材占比)
      final saved = StorageService.lookupDishRecipe(text);
      if (saved != null && saved.isNotEmpty) {
        debugPrint('[ManualFood] 命中保存的菜品配方: $text -> ${saved.length} 个食材');
        ingredients.addAll(saved);
        usedSavedRecipe = true;
      } else if (AiService.hasApiKey) {
        // 无保存配方,调用 AI 识别菜品中的食材及占比
        debugPrint('[ManualFood] 单菜名输入,调用 AI 识别食材: $text');
        final aiIngredients =
            await AiService.recognizeIngredientsFromDish(text);
        if (aiIngredients != null && aiIngredients.isNotEmpty) {
          ingredients.addAll(aiIngredients);
          aiRecognized = aiIngredients.length;
        } else {
          // AI 失败,按单一食材处理
          ingredients.add(FoodIngredient(name: text, ratio: 1.0));
        }
      } else {
        // 无 API Key,按单一食材处理
        ingredients.add(FoodIngredient(name: text, ratio: 1.0));
      }
    } else {
      // 多食材:等占比
      final ratio = 1.0 / tokens.length;
      for (final name in tokens) {
        ingredients.add(FoodIngredient(name: name, ratio: ratio));
      }
    }

    // 对每个食材查询/补全营养表
    int matched = 0;
    for (final ing in ingredients) {
      var nut = FoodNutritionDB.lookup(ing.name);
      if (nut == null) {
        debugPrint('[ManualFood] 食材未匹配,调用 AI 补全: ${ing.name}');
        nut = await AiService.lookupIngredientNutrition(ing.name);
        if (nut != null) {
          FoodNutritionDB.addCustom(nut);
          await StorageService.saveCustomFoodNutrition();
          debugPrint(
              '[ManualFood] 新增自定义食材: ${ing.name} -> ${nut.energy}kcal/100g');
        }
      }
      if (nut != null) matched++;
    }

    if (!mounted) return;
    setState(() {
      _ingredients = ingredients;
      _confirmed = true;
      _lookingUp = false;
      _usedSavedRecipe = usedSavedRecipe;
      _dishName = isMulti ? '' : text;
    });

    final total = ingredients.length;
    String msg;
    if (usedSavedRecipe) {
      msg = '已使用保存的配方($total 个食材),可手动调整';
    } else if (aiRecognized > 0 && isMulti == false) {
      msg = 'AI 识别出 $aiRecognized 个食材及占比,可手动调整';
    } else if (matched == total) {
      msg = '已识别 $matched 个食材,营养已计算';
    } else {
      msg = '已识别 $matched/$total 个食材,未匹配按默认值估算';
    }
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setAmount(double v, {bool fromInput = false}) {
    setState(() {
      _amount = v;
      if (!fromInput) {
        _amountCtrl.text = v.round().toString();
      }
    });
  }

  Future<void> _confirm(BuildContext context) async {
    if (!_confirmed || _ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入食材并点击「查询营养」')),
      );
      return;
    }

    // 单菜名且非已保存配方且含多个食材时,询问是否永久保存配方
    bool saveRecipe = false;
    if (_dishName.isNotEmpty &&
        !_usedSavedRecipe &&
        _ingredients.length >= 2) {
      saveRecipe = await _showSaveRecipeDialog(context);
      if (!context.mounted) return;
    }

    final s = context.read<AppState>();
    final amount = _amount.round();
    final nut = _nutrition;
    final name = _ingredients.map((e) => e.name).join('+');
    s.addFoodRecord(FoodRecord(
      id: 'f${DateTime.now().millisecondsSinceEpoch}',
      time: DateTime.now(),
      name: name,
      calories: _totalCalories,
      grams: amount,
      protein: nut.protein,
      fat: nut.fat,
      carbs: nut.carbs,
      fiber: nut.fiber,
    ));

    // 永久保存配方
    if (saveRecipe) {
      await StorageService.saveDishRecipe(_dishName, _ingredients);
    }

    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(saveRecipe
              ? '已记录 $name ${amount}g $_totalCalories kcal,配方已保存'
              : '已记录 $name ${amount}g $_totalCalories kcal')),
    );
  }

  /// 询问用户是否永久保存菜品配方
  Future<bool> _showSaveRecipeDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('保存菜品配方?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: Text(
                '是否将「$_dishName」的食材占比永久保存?\n保存后下次输入相同菜名将直接使用此配方。',
                style: const TextStyle(fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('仅本次使用'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('永久保存'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final nut = _nutrition;
    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SingleChildScrollView(
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
              const Text('手动输入饮食',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              CreamCard(
                radius: 24,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('菜品/食材名称',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ingredientCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: '输入菜名(如:番茄炒蛋)自动识别食材,或用逗号分隔多个食材',
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
                    SizedBox(
                      width: double.infinity,
                      child: RippleButton(
                        onTap: _lookingUp ? null : _lookupIngredients,
                        borderRadius: AppThemeRadius.s,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _lookingUp
                                ? AppColors.paused
                                : (_confirmed
                                    ? AppColors.mint
                                    : AppColors.softBlue),
                            borderRadius:
                                BorderRadius.circular(AppThemeRadius.s),
                          ),
                          alignment: Alignment.center,
                          child: _lookingUp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        AppColors.textPrimary),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _confirmed
                                          ? Icons.refresh
                                          : Icons.search,
                                      size: 16,
                                      color: _confirmed
                                          ? AppColors.mintDeep
                                          : AppColors.softBlueDeep,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _confirmed ? '重新查询' : '查询营养',
                                      style: TextStyle(
                                        color: _confirmed
                                            ? AppColors.mintDeep
                                            : AppColors.softBlueDeep,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    // 已确认:展示食材列表 + kcal/100g + 摄入量 + 营养预览
                    if (_confirmed) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('食材占比(可手动调整)',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text(
                            '合计 ${(ratioSumPercent)}%',
                            style: TextStyle(
                              color: (ratioSumPercent - 100).abs() <= 5
                                  ? AppColors.mintDeep
                                  : const Color(0xFFE6A700),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Column(
                        children: _ingredients.asMap().entries.map((entry) {
                          final i = entry.key;
                          final ing = entry.value;
                          final nutData = FoodNutritionDB.lookup(ing.name);
                          return _EditableIngredientRow(
                            key: ValueKey('ing_${i}_${ing.name}'),
                            name: ing.name,
                            ratio: ing.ratio,
                            matched: nutData != null,
                            onRatioChanged: (r) => _updateRatio(i, r),
                            onDeleted: () => _removeIngredient(i),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      // 每100g营养:点击可手动修改(覆盖基于食材计算的结果)
                      RippleButton(
                        onTap: () async {
                          final dishName = _ingredients.map((e) => e.name).join('+');
                          final edited = await showModalBottomSheet<FoodNutrition>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => _EditNutritionSheet(
                              name: dishName,
                              initial: _overrideNutrition ??
                                  FoodNutrition(
                                    name: dishName,
                                    energy: _kcalPer100g,
                                    protein: _nutrition.protein / (_amount / 100).clamp(0.01, 999),
                                    fat: _nutrition.fat / (_amount / 100).clamp(0.01, 999),
                                    carbs: _nutrition.carbs / (_amount / 100).clamp(0.01, 999),
                                    fiber: _nutrition.fiber / (_amount / 100).clamp(0.01, 999),
                                  ),
                            ),
                          );
                          if (edited != null) {
                            FoodNutritionDB.addCustom(edited);
                            await StorageService.saveCustomFoodNutrition();
                            setState(() {
                              _overrideNutrition = edited;
                            });
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(
                                  '已更新「${edited.name}」每100g营养数据,并保存到本地数据库')),
                            );
                          }
                        },
                        borderRadius: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _overrideNutrition != null
                                ? const Color(0xFFFFF0E0)
                                : AppColors.cream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _overrideNutrition != null
                                  ? const Color(0xFFCC7A00).withAlpha(80)
                                  : AppColors.divider,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_note,
                                size: 14,
                                color: _overrideNutrition != null
                                    ? const Color(0xFFCC7A00)
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _overrideNutrition != null
                                    ? '${_overrideNutrition!.energy.toStringAsFixed(0)} kcal/100g (已修改,点击编辑)'
                                    : '${_kcalPer100g.toStringAsFixed(0)} kcal / 100g (点击修改)',
                                style: TextStyle(
                                  color: _overrideNutrition != null
                                      ? const Color(0xFFCC7A00)
                                      : AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_overrideNutrition != null) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '蛋白${_overrideNutrition!.protein.toStringAsFixed(1)}g '
                            '脂肪${_overrideNutrition!.fat.toStringAsFixed(1)}g '
                            '碳水${_overrideNutrition!.carbs.toStringAsFixed(1)}g '
                            '纤维${_overrideNutrition!.fiber.toStringAsFixed(1)}g (每100g)',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // 摄入量输入 + 滑块
                      Row(
                        children: [
                          const Text('本次摄入量',
                              style: TextStyle(
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
                                suffixText: 'g',
                                suffixStyle: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                              onChanged: (text) {
                                final v = double.tryParse(text);
                                if (v != null && v >= 0) {
                                  _setAmount(v.clamp(10, 1000), fromInput: true);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Slider(
                        min: 10,
                        max: 1000,
                        divisions: 99,
                        value: _amount.clamp(10, 1000),
                        activeColor: AppColors.softBlueDeep,
                        onChanged: (v) => _setAmount(v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$_totalCalories',
                              style: const TextStyle(
                                  color: AppColors.softBlueDeep,
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
                      const SizedBox(height: 12),
                      _NutritionPreview(
                        protein: nut.protein,
                        fat: nut.fat,
                        carbs: nut.carbs,
                        fiber: nut.fiber,
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
                          color: AppColors.softBlue,
                          borderRadius: BorderRadius.circular(AppThemeRadius.m),
                        ),
                        alignment: Alignment.center,
                        child: const Text('确认计入',
                            style: TextStyle(
                                color: AppColors.softBlueDeep,
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
        ),
      ),
    );
  }
}

/// 可编辑食材占比行(名称 + 匹配状态 + 占比输入 + 删除)
/// 用于手动输入饮食时,展示 AI 识别出的食材并允许用户调整占比
class _EditableIngredientRow extends StatefulWidget {
  const _EditableIngredientRow({
    super.key,
    required this.name,
    required this.ratio,
    required this.matched,
    required this.onRatioChanged,
    required this.onDeleted,
  });
  final String name;
  final double ratio;
  final bool matched;
  final ValueChanged<double> onRatioChanged;
  final VoidCallback onDeleted;

  @override
  State<_EditableIngredientRow> createState() =>
      _EditableIngredientRowState();
}

class _EditableIngredientRowState extends State<_EditableIngredientRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${(widget.ratio * 100).round()}');
  }

  @override
  void didUpdateWidget(covariant _EditableIngredientRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = '${(widget.ratio * 100).round()}';
    // 外部占比变更时同步输入框(如重新查询),避免覆盖用户正在输入的值
    if (_ctrl.text != newText && MediaQuery.of(context).viewInsets.bottom == 0) {
      _ctrl.text = newText;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: widget.matched ? AppColors.mint : AppColors.banner,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.matched ? '已匹配' : 'AI补全',
                    style: TextStyle(
                      color: widget.matched
                          ? AppColors.mintDeep
                          : AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 100,
                    divisions: 20,
                    value: (widget.ratio * 100).clamp(0.0, 100.0),
                    activeColor: AppColors.softBlueDeep,
                    onChanged: (v) {
                      _ctrl.text = '${v.round()}';
                      widget.onRatioChanged(v / 100);
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: TextField(
                    controller: _ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.cream,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppThemeRadius.s),
                        borderSide: BorderSide.none,
                      ),
                      suffixText: '%',
                      suffixStyle: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                    ),
                    onChanged: (text) {
                      final v = double.tryParse(text);
                      if (v != null) {
                        widget.onRatioChanged((v / 100).clamp(0.0, 1.0));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            color: AppColors.textSecondary,
            onPressed: widget.onDeleted,
          ),
        ],
      ),
    );
  }
}

/// 手动输入运动 bottom sheet
/// 用户输入运动名称后,点击"AI 估算"按钮,带上性别/年龄/身高/体重调用 AI 估算 kcal/次
/// 估算结果可手动微调;若未配置 API Key 或未填全个人信息,提示用户
class _ManualExerciseSheet extends StatefulWidget {
  const _ManualExerciseSheet();

  @override
  State<_ManualExerciseSheet> createState() => _ManualExerciseSheetState();
}

class _ManualExerciseSheetState extends State<_ManualExerciseSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _kcalCtrl;
  late TextEditingController _repsCtrl;
  double _reps = 30;
  bool _estimating = false;
  bool _estimated = false; // 是否已成功估算过

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _kcalCtrl = TextEditingController(text: '0.5');
    _repsCtrl = TextEditingController(text: '30');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  /// 总热量(单次消耗 * 次数)
  int get _totalCalories =>
      ((double.tryParse(_kcalCtrl.text) ?? 0) * _reps).round();

  /// 滑块最大值:随用户输入的数值动态扩大(支持如 10000 步)
  double get _sliderMax {
    if (_reps <= 200) return 200;
    if (_reps <= 1000) return 1000;
    if (_reps <= 5000) return 5000;
    if (_reps <= 10000) return 10000;
    return (_reps * 1.2).ceilToDouble();
  }

  /// 调用 AI 估算运动卡路里消耗
  Future<void> _estimate(BuildContext context) async {
    final name = _nameCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先输入运动名称')),
      );
      return;
    }
    // 优先查找用户保存的运动热量
    final saved = StorageService.lookupExerciseCalorie(name);
    if (saved != null) {
      setState(() {
        _kcalCtrl.text = saved.toStringAsFixed(2);
        _estimated = true;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('已使用保存的「$name」热量: ${saved.toStringAsFixed(2)} kcal/次')),
      );
      return;
    }
    if (!AiService.hasApiKey) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先在账户页配置 API Key')),
      );
      return;
    }
    final profile = context.read<AppState>().profile;
    if (!profile.profileComplete) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先在上方填全性别/年龄/身高/体重,以便 AI 精准估算')),
      );
      return;
    }
    setState(() => _estimating = true);
    try {
      final result = await AiService.estimateExerciseCalories(
        exerciseName: name,
        gender: profile.gender.index,
        age: profile.age,
        height: profile.height,
        weight: profile.weight,
      );
      if (result == null || result.totalKcal <= 0) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('AI 估算失败,请手动填写或稍后重试')),
          );
        }
      } else {
        setState(() {
          _nameCtrl.text = result.name;
          _kcalCtrl.text = result.kcalPerUnit.toStringAsFixed(2);
          _reps = result.count.toDouble().clamp(1, 99999);
          _repsCtrl.text = result.count.toString();
          _estimated = true;
        });
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(
                'AI 估算:${result.name} ${result.count}${result.unit} ≈ ${result.totalKcal.toStringAsFixed(0)} kcal(可微调数量)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('估算出错:$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SingleChildScrollView(
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
                  const Text('手动输入运动',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  CreamCard(
                    radius: 24,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('运动名称',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            hintText: '如:跑步、俯卧撑、瑜伽',
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
                    // AI 估算按钮
                    SizedBox(
                      width: double.infinity,
                      child: RippleButton(
                        onTap: _estimating
                            ? null
                            : () => _estimate(context),
                        borderRadius: AppThemeRadius.s,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _estimated
                                ? AppColors.mint
                                : AppColors.softBlue,
                            borderRadius:
                                BorderRadius.circular(AppThemeRadius.s),
                          ),
                          alignment: Alignment.center,
                          child: _estimating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        AppColors.textPrimary),
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _estimated
                                          ? Icons.refresh
                                          : Icons.auto_awesome,
                                      size: 16,
                                      color: _estimated
                                          ? AppColors.mintDeep
                                          : AppColors.softBlueDeep,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _estimated ? '重新估算' : 'AI 估算消耗(基于个人信息)',
                                      style: TextStyle(
                                        color: _estimated
                                            ? AppColors.mintDeep
                                            : AppColors.softBlueDeep,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('单次消耗(kcal/次)',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _kcalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.cream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                          borderSide: BorderSide.none,
                        ),
                        suffixText: 'kcal/次',
                        suffixStyle: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        hintText: '点击上方按钮 AI 估算,或手动填写',
                        hintStyle: const TextStyle(
                            color: AppColors.textDisabled, fontSize: 11),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('次数',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _repsCtrl,
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
                              suffixText: '次',
                              suffixStyle: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (text) {
                              final v = double.tryParse(text);
                              if (v != null) {
                                setState(() => _reps = v.clamp(1, 999999));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      min: 1,
                      max: _sliderMax,
                      divisions: _sliderMax > 200 ? 100 : 199,
                      value: _reps.clamp(1, _sliderMax),
                      activeColor: AppColors.mintDeep,
                      onChanged: (v) {
                        setState(() {
                          _reps = v;
                          _repsCtrl.text = v.round().toString();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$_totalCalories',
                            style: const TextStyle(
                                color: AppColors.mintDeep,
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
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(AppThemeRadius.m),
                        ),
                        alignment: Alignment.center,
                        child: const Text('确认计入',
                            style: TextStyle(
                                color: AppColors.mintDeep,
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
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入运动名称')),
      );
      return;
    }
    // 若单次热量被修改过且非已保存记录,询问是否永久保存
    final kcalPerRep = double.tryParse(_kcalCtrl.text.trim()) ?? 0;
    final saved = StorageService.lookupExerciseCalorie(name);
    bool saveCalorie = false;
    if (kcalPerRep > 0 && saved == null) {
      saveCalorie = await _showSaveExerciseDialog(context, name, kcalPerRep);
      if (!context.mounted) return;
    }
    final s = context.read<AppState>();
    s.addExerciseRecord(ExerciseRecord(
      id: 'e${DateTime.now().millisecondsSinceEpoch}',
      time: DateTime.now(),
      name: name,
      calories: _totalCalories,
      reps: _reps.round(),
    ));
    if (saveCalorie) {
      await StorageService.saveExerciseCalorie(name, kcalPerRep);
    }
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(saveCalorie
          ? '已记录 $name ${_reps.round()} 次 $_totalCalories kcal,热量已保存'
          : '已记录 $name ${_reps.round()} 次 $_totalCalories kcal')),
    );
  }

  /// 询问用户是否永久保存运动单次热量
  Future<bool> _showSaveExerciseDialog(
      BuildContext context, String name, double kcal) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('保存运动热量?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: Text(
                '是否将「$name」的单次消耗(${kcal.toStringAsFixed(2)} kcal/次)永久保存?\n保存后下次输入相同运动名将直接使用此热量值。',
                style: const TextStyle(fontSize: 13)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('仅本次使用'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('永久保存'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// AI 识别结果确认 sheet
/// 食物:展示识别出的菜品名+食材列表,用户只需确认吃的量
/// 运动:允许用户修改运动名称
class _ResultSheet extends StatefulWidget {
  const _ResultSheet({required this.result});
  final AiRecognitionResult result;

  @override
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> {
  late double _amount;
  late TextEditingController _nameCtrl; // 仅运动类型使用
  late TextEditingController _amountCtrl;
  // 低置信度时手动输入食材
  late TextEditingController _ingredientCtrl;
  // 用户覆盖后的 kcal/100g(空表示使用 AI 识别值)
  // 修改后立即持久化到本地食物营养数据库(覆盖同名食材)
  double? _overrideKcalPer100g;
  FoodNutrition? _overrideNutrition;
  List<FoodIngredient> _manualIngredients = const [];
  double _manualKcalPer100g = 0;
  bool _lookingUp = false;
  bool _manualConfirmed = false;

  @override
  void initState() {
    super.initState();
    // 食物:若 AI 结合餐具估算了重量,则预填该重量
    final est = widget.result.estimatedWeight;
    if (widget.result.type == AiRecognitionType.food && est > 0) {
      _amount = est.clamp(10, 1000);
    } else {
      _amount = widget.result.type == AiRecognitionType.food ? 150 : 30;
    }
    _nameCtrl = TextEditingController(text: widget.result.name);
    _amountCtrl = TextEditingController(text: _amount.round().toString());
    _ingredientCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _ingredientCtrl.dispose();
    super.dispose();
  }

  /// 是否需要手动输入食材(食物+非营养成分表+置信度低/未知/无食材)
  bool get _needManualInput {
    if (widget.result.type != AiRecognitionType.food) return false;
    if (widget.result.fromLabel) return false;
    if (_manualConfirmed) return false;
    return widget.result.confidence < 0.7 ||
        widget.result.name == '未知菜品' ||
        widget.result.ingredients.isEmpty;
  }

  /// 当前生效的食材列表(手动确认后用手动列表,否则用原识别结果)
  List<FoodIngredient> get _activeIngredients =>
      _manualConfirmed ? _manualIngredients : widget.result.ingredients;

  /// 当前生效的 kcal/100g
  /// 优先级:用户编辑过的覆盖值 > 手动确认值 > AI 识别值
  double get _activeKcalPer100g {
    if (_overrideKcalPer100g != null) return _overrideKcalPer100g!;
    return _manualConfirmed ? _manualKcalPer100g : widget.result.value;
  }

  /// 自动计算的总热量(kcal)
  /// 食物:kcal/100g × 量 / 100;运动:单次消耗 × 次数
  int get _totalCalories {
    if (widget.result.type == AiRecognitionType.food) {
      return (_activeKcalPer100g * _amount / 100).round();
    }
    return (widget.result.value * _amount).round();
  }

  /// 食物:根据食材比例和总克数计算营养
  /// 优先用用户编辑过的覆盖值;若来自营养成分表,直接用表上数据按克数线性缩放
  ({double protein, double fat, double carbs, double fiber})
      get _nutrition {
    if (widget.result.type != AiRecognitionType.food) {
      return (protein: 0, fat: 0, carbs: 0, fiber: 0);
    }
    // 用户已编辑过营养:直接按克数线性缩放
    if (_overrideNutrition != null) {
      final scaled = _overrideNutrition!.scaled(_amount);
      return (
        protein: scaled.protein,
        fat: scaled.fat,
        carbs: scaled.carbs,
        fiber: scaled.fiber,
      );
    }
    // 来自营养成分表:直接用 labelNutrition 按克数缩放
    if (widget.result.fromLabel && widget.result.labelNutrition != null) {
      final scaled = widget.result.labelNutrition!.scaled(_amount);
      return (
        protein: scaled.protein,
        fat: scaled.fat,
        carbs: scaled.carbs,
        fiber: scaled.fiber,
      );
    }
    // 来自菜品识别:按食材比例计算(使用当前生效的食材列表)
    final ings = _activeIngredients;
    double p = 0, f = 0, c = 0, fi = 0;
    for (final ing in ings) {
      final nut = FoodNutritionDB.lookup(ing.name);
      if (nut != null) {
        // 该食材的克数 = 总克数 * 比例
        final grams = _amount * ing.ratio;
        final scaled = nut.scaled(grams);
        p += scaled.protein;
        f += scaled.fat;
        c += scaled.carbs;
        fi += scaled.fiber;
      }
    }
    return (protein: p, fat: f, carbs: c, fiber: fi);
  }

  /// 解析用户手动输入的食材(逗号分隔),查询营养并重算 kcal/100g
  Future<void> _confirmManualIngredients() async {
    final text = _ingredientCtrl.text.trim();
    if (text.isEmpty) return;
    // 按中文/英文逗号分割
    final names = text
        .split(RegExp(r'[,，、\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (names.isEmpty) return;

    setState(() => _lookingUp = true);
    final messenger = ScaffoldMessenger.of(context);

    final ingredients = <FoodIngredient>[];
    double totalEnergy = 0;
    int matched = 0;

    // 均分比例
    final ratio = 1.0 / names.length;
    for (final name in names) {
      var nut = FoodNutritionDB.lookup(name);
      if (nut == null) {
        // 本地未匹配,调用 AI 评判(仅用于本次计算,不持久化)
        debugPrint('[ResultSheet] 食材未匹配,调用 AI 评判: $name');
        nut = await AiService.lookupIngredientNutrition(name);
        if (nut != null) {
          debugPrint('[ResultSheet] AI 评判食材: $name -> ${nut.energy}kcal/100g (不记录)');
        }
      }
      ingredients.add(FoodIngredient(name: name, ratio: ratio));
      if (nut != null) {
        totalEnergy += nut.energy * ratio;
        matched++;
      }
    }

    // 未匹配的食材按平均 150 kcal/100g 补
    if (matched < names.length) {
      totalEnergy += 150 * (1.0 - matched / names.length);
    }

    setState(() {
      _manualIngredients = ingredients;
      _manualKcalPer100g = totalEnergy;
      _manualConfirmed = true;
      _lookingUp = false;
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          matched == names.length
              ? '已识别 $matched 个食材,营养已重算'
              : '已识别 $matched/${names.length} 个食材,未匹配按默认值估算',
        ),
      ),
    );
  }

  Color get _confidenceColor {
    final c = widget.result.confidence;
    if (c >= 0.8) return AppColors.mintDeep;
    if (c >= 0.5) return AppColors.softBlueDeep;
    return const Color(0xFFFFB380);
  }

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
    final String unit = isFood ? '克' : '次';
    final String unitSymbol = isFood ? 'g' : '次';
    final String amountLabel = isFood ? '本次摄入量' : '本次运动量';
    final double minAmt = isFood ? 10 : 1;
    final double maxAmt = isFood ? 1000 : 200;
    final nut = _nutrition;

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SingleChildScrollView(
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
                  Text(isFood ? '菜品识别结果' : '运动识别结果',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  CreamCard(
                    radius: 24,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  Text(widget.result.name,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    isFood
                                        ? '${_activeKcalPer100g.toStringAsFixed(0)} kcal / 100g'
                                        : '${widget.result.value.toStringAsFixed(2)} kcal / 次',
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
                    // 食物:展示识别出的食材列表(只读参考)
                    // 若来自营养成分表,显示"来自营养成分表"标识,不显示食材列表
                    if (isFood && widget.result.fromLabel) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified,
                                size: 14, color: AppColors.mintDeep),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '数据来自包装营养成分表(每100g)',
                                style: TextStyle(
                                  color: AppColors.mintDeep,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isFood && _needManualInput) ...[
                      // 低置信度:显示手动输入食材框
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0E0),
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14, color: Color(0xFFCC7A00)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '识别置信度较低,请一次性输入本次菜品包含的所有食材,用逗号隔开(如:番茄,鸡蛋,葱花)',
                                style: TextStyle(
                                  color: Color(0xFFCC7A00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _ingredientCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: '如:番茄,鸡蛋,葱花,米饭',
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
                      const SizedBox(height: 8),
                      RippleButton(
                        onTap: _lookingUp ? null : _confirmManualIngredients,
                        borderRadius: AppThemeRadius.s,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _lookingUp
                                ? AppColors.paused
                                : AppColors.softBlueDeep,
                            borderRadius:
                                BorderRadius.circular(AppThemeRadius.s),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_lookingUp) ...[
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ],
                              Text(
                                _lookingUp ? '查询营养中...' : '确认食材并重算',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (isFood && _activeIngredients.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('识别到的食材',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          if (_manualConfirmed) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.mint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '已手动确认',
                                style: TextStyle(
                                  color: AppColors.mintDeep,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _activeIngredients.map((ing) {
                          final nutData = FoodNutritionDB.lookup(ing.name);
                          final matched = nutData != null;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: matched
                                  ? AppColors.softBlue
                                  : AppColors.banner,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${ing.name} ${(ing.ratio * 100).round()}%${matched ? '' : '(AI补全)'}',
                              style: TextStyle(
                                color: matched
                                    ? AppColors.softBlueDeep
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      // 手动确认后允许重新输入
                      if (_manualConfirmed) ...[
                        const SizedBox(height: 8),
                        RippleButton(
                          onTap: () => setState(() {
                            _manualConfirmed = false;
                            _ingredientCtrl.clear();
                          }),
                          borderRadius: 8,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                              '重新输入食材',
                              style: TextStyle(
                                color: AppColors.softBlueDeep,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    // 提示用户确认摄入量
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
                              '请确认$amountLabel(单位:$unit)',
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
                    const SizedBox(height: 12),
                    // 数量输入 + 滑块
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
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
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
                    // 食物:编辑每100g营养(用户觉得识别不准时使用)
                    if (isFood) ...[
                      const SizedBox(height: 8),
                      RippleButton(
                        onTap: () async {
                          final edited = await showModalBottomSheet<FoodNutrition>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => _EditNutritionSheet(
                              name: widget.result.name,
                              initial: _overrideNutrition ??
                                  widget.result.labelNutrition ??
                                  FoodNutrition(
                                    name: widget.result.name,
                                    energy: _activeKcalPer100g,
                                    protein: 0,
                                    fat: 0,
                                    carbs: 0,
                                    fiber: 0,
                                  ),
                            ),
                          );
                          if (edited != null) {
                            // 持久化到本地食物营养数据库(覆盖同名食材)
                            FoodNutritionDB.addCustom(edited);
                            await StorageService.saveCustomFoodNutrition();
                            setState(() {
                              _overrideNutrition = edited;
                              _overrideKcalPer100g = edited.energy;
                            });
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(
                                  '已更新「${edited.name}」每100g营养数据,并保存到本地数据库')),
                            );
                          }
                        },
                        borderRadius: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _overrideNutrition != null
                                ? const Color(0xFFFFF0E0)
                                : AppColors.cream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _overrideNutrition != null
                                  ? const Color(0xFFCC7A00).withAlpha(80)
                                  : AppColors.divider,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_note,
                                size: 14,
                                color: _overrideNutrition != null
                                    ? const Color(0xFFCC7A00)
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _overrideNutrition != null
                                      ? '已修改每100g营养(点击再次编辑)'
                                      : '每100g营养不准?点击修改',
                                  style: TextStyle(
                                    color: _overrideNutrition != null
                                        ? const Color(0xFFCC7A00)
                                        : AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_overrideNutrition != null) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '当前: ${_overrideNutrition!.energy.toStringAsFixed(0)}kcal '
                            '蛋白${_overrideNutrition!.protein.toStringAsFixed(1)}g '
                            '脂肪${_overrideNutrition!.fat.toStringAsFixed(1)}g '
                            '碳水${_overrideNutrition!.carbs.toStringAsFixed(1)}g '
                            '纤维${_overrideNutrition!.fiber.toStringAsFixed(1)}g (每100g)',
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                    // 运动:允许修改名称
                    if (!isFood) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          hintText: '运动名称(可修改)',
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
                    ],
                    // 食物:显示营养构成
                    if (isFood) ...[
                      const SizedBox(height: 12),
                      _NutritionPreview(
                        protein: nut.protein,
                        fat: nut.fat,
                        carbs: nut.carbs,
                        fiber: nut.fiber,
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
        ),
      ),
    );
  }

  void _confirm(BuildContext context) {
    final s = context.read<AppState>();
    final isFood = widget.result.type == AiRecognitionType.food;
    final amount = _amount.round();
    final nut = _nutrition;

    if (isFood) {
      s.addFoodRecord(FoodRecord(
        id: 'f${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        name: widget.result.name,
        calories: _totalCalories,
        grams: amount,
        imagePath: widget.result.imagePath,
        protein: nut.protein,
        fat: nut.fat,
        carbs: nut.carbs,
        fiber: nut.fiber,
      ));
    } else {
      final name = _nameCtrl.text.trim().isEmpty
          ? widget.result.name
          : _nameCtrl.text.trim();
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
              '已记录 ${isFood ? widget.result.name : _nameCtrl.text} ${isFood ? "$amount g" : "$amount 次"} $_totalCalories kcal')),
    );
  }
}

/// 编辑每100g营养 bottom sheet
/// 用户觉得识别不准时可手动修改能量/蛋白质/脂肪/碳水/膳食纤维
/// 保存后覆盖本地食物营养数据库中的同名食材
class _EditNutritionSheet extends StatefulWidget {
  const _EditNutritionSheet({required this.name, required this.initial});
  final String name;
  final FoodNutrition initial;

  @override
  State<_EditNutritionSheet> createState() => _EditNutritionSheetState();
}

class _EditNutritionSheetState extends State<_EditNutritionSheet> {
  late TextEditingController _energyCtrl;
  late TextEditingController _proteinCtrl;
  late TextEditingController _fatCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fiberCtrl;

  @override
  void initState() {
    super.initState();
    _energyCtrl =
        TextEditingController(text: widget.initial.energy.toStringAsFixed(1));
    _proteinCtrl =
        TextEditingController(text: widget.initial.protein.toStringAsFixed(1));
    _fatCtrl =
        TextEditingController(text: widget.initial.fat.toStringAsFixed(1));
    _carbsCtrl =
        TextEditingController(text: widget.initial.carbs.toStringAsFixed(1));
    _fiberCtrl =
        TextEditingController(text: widget.initial.fiber.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _energyCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    _fiberCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final energy = double.tryParse(_energyCtrl.text.trim()) ?? 0;
    final protein = double.tryParse(_proteinCtrl.text.trim()) ?? 0;
    final fat = double.tryParse(_fatCtrl.text.trim()) ?? 0;
    final carbs = double.tryParse(_carbsCtrl.text.trim()) ?? 0;
    final fiber = double.tryParse(_fiberCtrl.text.trim()) ?? 0;
    if (energy <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写有效的能量值(kcal/100g)')),
      );
      return;
    }
    Navigator.pop(
      context,
      FoodNutrition(
        name: widget.name,
        energy: energy,
        protein: protein,
        fat: fat,
        carbs: carbs,
        fiber: fiber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SingleChildScrollView(
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
                  Text('编辑「${widget.name}」每100g营养',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('修改后将保存到本地数据库,下次识别同一食物自动使用',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                  const SizedBox(height: 16),
                  CreamCard(
                    radius: 24,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field('能量(kcal)', _energyCtrl, 'kcal/100g'),
                        const SizedBox(height: 8),
                        _field('蛋白质(g)', _proteinCtrl, 'g/100g'),
                        const SizedBox(height: 8),
                        _field('脂肪(g)', _fatCtrl, 'g/100g'),
                        const SizedBox(height: 8),
                        _field('碳水化合物(g)', _carbsCtrl, 'g/100g'),
                        const SizedBox(height: 8),
                        _field('膳食纤维(g)', _fiberCtrl, 'g/100g'),
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
                          onTap: _save,
                          borderRadius: AppThemeRadius.m,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.softBlueDeep,
                              borderRadius: BorderRadius.circular(AppThemeRadius.m),
                            ),
                            alignment: Alignment.center,
                            child: const Text('保存',
                                style: TextStyle(
                                    color: Colors.white,
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
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String suffix) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: false),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppThemeRadius.s),
                borderSide: BorderSide.none,
              ),
              suffixText: suffix,
              suffixStyle:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// 营养预览(确认 sheet 内显示本次摄入的营养构成)
class _NutritionPreview extends StatelessWidget {
  const _NutritionPreview({
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.fiber,
  });
  final double protein;
  final double fat;
  final double carbs;
  final double fiber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppThemeRadius.s),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item('碳水', carbs, const Color(0xFFFFB380)),
          _item('蛋白质', protein, AppColors.mintDeep),
          _item('脂肪', fat, AppColors.softBlueDeep),
          _item('纤维', fiber, const Color(0xFFB39DDB)),
        ],
      ),
    );
  }

  Widget _item(String label, double value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 3),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 2),
        Text('${value.toStringAsFixed(1)}g',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

