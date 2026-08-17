part of 'ai_recognition_page.dart';

/// 今日摄入「避免吃」食材的克数警戒值(默认),超过则弹出红色摄入提醒
/// 实际阈值会根据用户 BMR 动态调整,见 [UserProfile.forbiddenWarningThreshold]
const double kDefaultForbiddenWarningThreshold = 150;

/// 计算一次记录中「避免吃」食材的总克数(用于红色摄入过多提醒),
/// 委托给 [DietMethods.forbiddenGramsOf] 以便复用与测试。
double _forbiddenGramsOf(List<FoodIngredient> ings, double amount,
    DietMethod? method,
    {double? totalRatio}) {
  return DietMethods.forbiddenGramsOf(ings, amount, method,
      totalRatio: totalRatio);
}

/// 记录食物后,若今日摄入「避免吃」食材超过警戒值,弹出提醒(每天最多一次)
Future<void> _maybeShowForbiddenWarning(BuildContext context, AppState s) async {
  final today =
      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
  if (StorageService.getForbiddenWarnedDate() == today) return;
  final threshold = s.profile.forbiddenWarningThreshold;
  if (s.todayForbiddenGrams < threshold) return;
  StorageService.saveForbiddenWarnedDate(today);
  if (!context.mounted) return;
  final text = StorageService.getForbiddenWarningText();
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeRadius.l),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828), size: 22),
          SizedBox(width: 8),
          Text('红色摄入过多',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '今日已摄入避免吃食材 ${s.todayForbiddenGrams.round()}g,超过警戒值 ${threshold.round()}g(根据您的身体信息自动计算)',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(text,
              style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('可在「账户-提醒文案」中更换或自定义这句话',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('知道了',
              style: TextStyle(
                  color: AppColors.softBlueDeep,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

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

/// 统一饮食记录 bottom sheet
/// 拍照 / 从相册 / 手动输入三种方式最终都进入本界面:
/// 菜名可编辑、食材占比可增删改、kcal/100g 可修改、食用重量可调、自动计算总热量。
/// [result] 为拍照/相册的 AI 识别结果(预填);为 null 时表示手动输入。
class _FoodRecordSheet extends StatefulWidget {
  const _FoodRecordSheet({this.result});

  /// 拍照/相册 AI 识别结果(手动输入时为 null)
  final AiRecognitionResult? result;

  @override
  State<_FoodRecordSheet> createState() => _FoodRecordSheetState();
}

class _FoodRecordSheetState extends State<_FoodRecordSheet> {
  late TextEditingController _nameCtrl;
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

  /// 是否为拍照/相册识别结果
  bool get _hasPhoto => widget.result != null && widget.result!.imagePath != null;

  /// 识别置信度(手动输入视为 1)
  double get _confidence => widget.result?.confidence ?? 1.0;

  /// 是否来自包装营养成分表
  bool get _fromLabel => widget.result?.fromLabel ?? false;

  /// 置信度颜色(高:绿,中:蓝,低:橙)
  Color get _confidenceColor {
    final c = _confidence;
    if (c >= 0.8) return AppColors.mintDeep;
    if (c >= 0.5) return AppColors.softBlueDeep;
    return const Color(0xFFFFB380);
  }

  /// 当前是否有可用食材(识别预填或手动确认)
  bool get _manualHasIngredients => _ingredients.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final r = widget.result;
    // 预填识别结果:名称、食材、用量、营养成分表数据
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    if (r != null) {
      if (r.ingredients.isNotEmpty) {
        _ingredients = List.of(r.ingredients);
        _confirmed = true;
      }
      if (r.fromLabel && r.labelNutrition != null) {
        // 营养成分表:直接用表上数据,不展示食材行
        _overrideNutrition = r.labelNutrition;
        _confirmed = true;
      }
      if (r.estimatedWeight > 0) {
        _amount = r.estimatedWeight.clamp(10, 1000);
      }
    }
    _amountCtrl = TextEditingController(text: _amount.round().toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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

  /// 添加单个食材:追加后重新归一化占比、重算营养
  Future<void> _addIngredient() async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加食材'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '如:米饭,鸡蛋,豆腐'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (name == null || name.isEmpty) return;
    if (!context.mounted) return;

    final exists = _ingredients.any((e) => e.name == name);
    if (exists) {
      messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 1), content: Text('食材「$name」已在列表中')));
      return;
    }

    setState(() => _lookingUp = true);

    // 查询/补全新食材营养
    var nut = FoodNutritionDB.lookup(name);
    if (nut == null) {
      debugPrint('[ManualFood] 添加食材未匹配,调用 AI 补全: $name');
      nut = await AiService.lookupIngredientNutrition(name);
      if (nut != null) {
        FoodNutritionDB.addCustom(nut);
        await StorageService.saveCustomFoodNutrition();
      }
    }
    if (!context.mounted) return;

    // 新食材占均分份额,已有食材按比例缩小,归一化保持总和为 1
    final baseSum = _ingredients.fold<double>(0, (s, e) => s + e.ratio);
    final newRatio = 1.0 / (_ingredients.length + 1);
    final baseScale = baseSum > 0 ? (_ingredients.length / (_ingredients.length + 1)) / baseSum : 0.0;
    final updated = <FoodIngredient>[
      for (var e in _ingredients)
        FoodIngredient(name: e.name, ratio: e.ratio * baseScale),
      FoodIngredient(name: name, ratio: newRatio),
    ];

    setState(() {
      _ingredients = updated;
      _overrideNutrition = null; // 让营养随占比重新计算
      _lookingUp = false;
    });

    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 1), content: Text('已添加「$name」,占比与营养已重新计算')));
  }

  /// 解析用户输入:
  /// - 单个菜名(无分隔符)→ 调用 AI 识别菜品中的食材及占比(可编辑)
  /// - 多个食材(逗号/顿号/空格分隔)→ 按等占比处理
  /// 之后对每个食材查询本地营养表,未匹配则调用 AI 补全并持久化
  Future<void> _lookupIngredients() async {
    final text = _nameCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(duration: Duration(seconds: 1), content: Text('请输入菜品或食材名称')),
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
    messenger.showSnackBar(SnackBar(duration: const Duration(seconds: 1), content: Text(msg)));
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
    // 非营养成分表食品必须已有食材;营养成分表食品无需食材
    if (!_confirmed || (_ingredients.isEmpty && !_fromLabel)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(duration: Duration(seconds: 1), content: Text('请先输入食材并点击「查询营养」')),
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
    final name = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : _ingredients.map((e) => e.name).join('+');
    final method = DietMethods.findByIdFor(s.profile.goal, s.profile.dietMethodId);
    final forbiddenGrams = _forbiddenGramsOf(
        _ingredients, _amount, method,
        totalRatio: _ratioSum);
    s.addFoodRecord(FoodRecord(
      id: 'f${DateTime.now().millisecondsSinceEpoch}',
      time: DateTime.now(),
      name: name,
      calories: _totalCalories,
      grams: amount,
      imagePath: widget.result?.imagePath,
      protein: nut.protein,
      fat: nut.fat,
      carbs: nut.carbs,
      fiber: nut.fiber,
      forbiddenGrams: forbiddenGrams,
    ));

    // 永久保存配方
    if (saveRecipe) {
      await StorageService.saveDishRecipe(_dishName, _ingredients);
    }

    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: const Duration(seconds: 1), 
          content: Text(saveRecipe
              ? '已记录 $name ${amount}g $_totalCalories kcal,配方已保存'
              : '已记录 $name ${amount}g $_totalCalories kcal')),
    );
    if (context.mounted) {
      await _maybeShowForbiddenWarning(context, s);
    }
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
              Text(_hasPhoto ? '识别结果 · 确认食物' : '记录饮食',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              // 拍照/相册:展示图片 + 置信度预览
              if (_hasPhoto) ...[
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(widget.result!.imagePath!),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.result!.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _confidenceColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'AI 置信度 ${(_confidence * 100).round()}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // 来自营养成分表标识
              if (_fromLabel) ...[
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
                          '数据来自包装营养成分表(每100g),可直接确认或修改',
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
                const SizedBox(height: 12),
              ],
              // 低置信度/无食材提示:引导用户核对或补录食材
              if (_hasPhoto &&
                  !_fromLabel &&
                  !_manualHasIngredients &&
                  _confidence < 0.7) ...[
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
                          '识别置信度较低,请核对下方食材占比,必要时用「添加食材」补录或修改',
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
                const SizedBox(height: 12),
              ],
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
                      controller: _nameCtrl,
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
                    // 非营养成分表食品才需要查询食材;标签食品已含全部营养数据
                    if (!_fromLabel) ...[
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
                    ],
                    // 有食材:展示食材占比编辑(可增删改)
                    if (_confirmed && _ingredients.isNotEmpty) ...[
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
                          final method = DietMethods.findByIdFor(
                              context.read<AppState>().profile.goal,
                              context.read<AppState>().profile.dietMethodId);
                          return _EditableIngredientRow(
                            key: ValueKey('ing_${i}_${ing.name}'),
                            name: ing.name,
                            ratio: ing.ratio,
                            matched: nutData != null,
                            dietStatus: DietMethods.classify(ing.name, method),
                            onRatioChanged: (r) => _updateRatio(i, r),
                            onDeleted: () => _removeIngredient(i),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 4),
                      // 追加单个食材(重新归一化占比与营养)
                      RippleButton(
                        onTap: _lookingUp ? null : _addIngredient,
                        borderRadius: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.divider,
                              width: 0.5,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  size: 14, color: AppColors.softBlueDeep),
                              SizedBox(width: 4),
                              Text('添加食材',
                                  style: TextStyle(
                                    color: AppColors.softBlueDeep,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else if (_confirmed && _fromLabel) ...[
                      // 营养成分表:无需食材,直接展示营养数据
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(AppThemeRadius.s),
                        ),
                        child: Text(
                          '能量${_kcalPer100g.toStringAsFixed(0)} kcal/100g · '
                          '蛋白${_nutrition.protein.toStringAsFixed(1)}g '
                          '脂肪${_nutrition.fat.toStringAsFixed(1)}g '
                          '碳水${_nutrition.carbs.toStringAsFixed(1)}g '
                          '纤维${_nutrition.fiber.toStringAsFixed(1)}g',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // 已确认:kcal/100g 可修改 + 摄入量 + 总热量 + 营养预览
                    if (_confirmed) ...[
                      const SizedBox(height: 12),
                      // 每100g营养:点击可手动修改(覆盖基于食材计算的结果)
                      RippleButton(
                        onTap: () async {
                          final dishName = _nameCtrl.text.trim().isNotEmpty
                              ? _nameCtrl.text.trim()
                              : _ingredients.map((e) => e.name).join('+');
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
                              SnackBar(duration: const Duration(seconds: 1), content: Text(
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

/// 可编辑食材占比行(食材名 + 信息标签 + 占比输入 + 删除)
/// 用于手动输入饮食时,展示 AI 识别出的食材并允许用户调整占比
class _EditableIngredientRow extends StatefulWidget {
  const _EditableIngredientRow({
    super.key,
    required this.name,
    required this.ratio,
    required this.matched,
    required this.dietStatus,
    required this.onRatioChanged,
    required this.onDeleted,
  });
  final String name;
  final double ratio;
  final bool matched;
  final DietFoodStatus dietStatus;
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
    final (Color nameColor, String? mark, Color markColor) =
        switch (widget.dietStatus) {
      DietFoodStatus.allowed => (
          const Color(0xFF2E7D32),
          '✓推荐',
          const Color(0xFF2E7D32)
        ),
      DietFoodStatus.forbidden => (
          const Color(0xFFC62828),
          '✗避免',
          const Color(0xFFC62828)
        ),
      DietFoodStatus.neutral => (AppColors.textPrimary, null, AppColors.textPrimary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧:食材名称 + 信息标签(标签换行展示,名称可占满剩余宽度)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: nameColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (mark != null)
                      _tag(mark,
                          color: markColor.withAlpha(16),
                          textColor: markColor),
                    _tag(widget.matched ? '已匹配' : 'AI补全',
                        color: widget.matched
                            ? AppColors.mint
                            : AppColors.banner,
                        textColor: widget.matched
                            ? AppColors.mintDeep
                            : AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 占比输入
          SizedBox(
            width: 60,
            child: TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.cream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppThemeRadius.s),
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
          // 删除按钮(固定靠右,贴近白底边缘)
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            color: AppColors.textSecondary,
            onPressed: widget.onDeleted,
          ),
        ],
      ),
    );
  }

  /// 信息小标签(推荐/避免/匹配状态)
  Widget _tag(String text, {required Color color, required Color textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: textColor, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 手动输入运动 bottom sheet
/// 用户输入运动名称后,点击"AI 估算"按钮,带上性别/年龄/身高/体重调用 AI 估算 kcal/次
/// 估算结果可手动微调;若未配置 API Key 或未填全个人信息,提示用户
/// 若传入 [initial](已有运动记录),则进入编辑模式:预填数值,确认时更新原记录
class _ExerciseRecordSheet extends StatefulWidget {
  const _ExerciseRecordSheet({this.initial, this.result});

  /// 编辑已有运动记录时的原记录
  final ExerciseRecord? initial;

  /// 拍照/相册 AI 识别结果(预填,手动输入时为 null)
  final AiRecognitionResult? result;

  @override
  State<_ExerciseRecordSheet> createState() => _ExerciseRecordSheetState();
}

class _ExerciseRecordSheetState extends State<_ExerciseRecordSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _kcalCtrl;
  late TextEditingController _repsCtrl;
  double _reps = 30;
  bool _estimating = false;
  bool _estimated = false; // 是否已成功估算过

  /// 是否编辑已有记录
  bool get _isEditing => widget.initial != null;

  /// 是否为拍照/相册识别结果
  bool get _hasPhoto => widget.result != null && widget.result!.imagePath != null;

  /// 识别置信度(手动输入视为 1)
  double get _confidence => widget.result?.confidence ?? 1.0;

  /// 置信度颜色(高:绿,中:蓝,低:橙)
  Color get _confidenceColor {
    final c = _confidence;
    if (c >= 0.8) return AppColors.mintDeep;
    if (c >= 0.5) return AppColors.softBlueDeep;
    return const Color(0xFFFFB380);
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    final r = widget.result;
    // 优先级:编辑已有记录 > 识别结果预填 > 空(手动输入)
    _nameCtrl = TextEditingController(text: init?.name ?? r?.name ?? '');
    if (init != null) {
      final perRep = init.reps > 0
          ? (init.calories / init.reps).toStringAsFixed(2)
          : '0.5';
      _kcalCtrl = TextEditingController(text: perRep);
      _reps = init.reps.toDouble().clamp(1, 999999);
      _repsCtrl = TextEditingController(text: init.reps.toString());
      _estimated = true;
    } else if (r != null && r.type == AiRecognitionType.exercise) {
      _kcalCtrl = TextEditingController(text: r.value.toStringAsFixed(2));
      _reps = 30;
      _repsCtrl = TextEditingController(text: '30');
      _estimated = true;
    } else {
      _kcalCtrl = TextEditingController(text: '0.5');
      _repsCtrl = TextEditingController(text: '30');
    }
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
        const SnackBar(duration: Duration(seconds: 1), content: Text('请先输入运动名称')),
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
        SnackBar(duration: const Duration(seconds: 1), content: Text('已使用保存的「$name」热量: ${saved.toStringAsFixed(2)} kcal/次')),
      );
      return;
    }
    if (!AiService.hasApiKey) {
      messenger.showSnackBar(
        const SnackBar(duration: Duration(seconds: 1), content: Text('请先在账户页配置 API Key')),
      );
      return;
    }
    final profile = context.read<AppState>().profile;
    if (!profile.profileComplete) {
      messenger.showSnackBar(
        const SnackBar(duration: Duration(seconds: 1), content: Text('请先在上方填全性别/年龄/身高/体重,以便 AI 精准估算')),
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
            const SnackBar(duration: Duration(seconds: 1), content: Text('AI 估算失败,请手动填写或稍后重试')),
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
            SnackBar(duration: const Duration(seconds: 1), content: Text(
                'AI 估算:${result.name} ${result.count}${result.unit} ≈ ${result.totalKcal.toStringAsFixed(0)} kcal(可微调数量)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(duration: const Duration(seconds: 1), content: Text('估算出错:$e')),
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
                  Text(
                    _isEditing
                        ? '编辑运动'
                        : (_hasPhoto ? '识别结果 · 确认运动' : '记录运动'),
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  if (_hasPhoto) ...[
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(widget.result!.imagePath!),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.result!.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _confidenceColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'AI 置信度 ${(_confidence * 100).round()}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
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
                        child: Text(_isEditing ? '保存修改' : '确认计入',
                            style: const TextStyle(
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
        const SnackBar(duration: Duration(seconds: 1), content: Text('请输入运动名称')),
      );
      return;
    }
    // 若单次热量被修改过且非已保存记录,询问是否永久保存(编辑模式不询问)
    final kcalPerRep = double.tryParse(_kcalCtrl.text.trim()) ?? 0;
    final saved = StorageService.lookupExerciseCalorie(name);
    bool saveCalorie = false;
    if (!_isEditing && kcalPerRep > 0 && saved == null) {
      saveCalorie = await _showSaveExerciseDialog(context, name, kcalPerRep);
      if (!context.mounted) return;
    }
    final s = context.read<AppState>();
    if (_isEditing) {
      s.updateExerciseRecord(
        widget.initial!.id,
        ExerciseRecord(
          id: widget.initial!.id,
          time: widget.initial!.time,
          name: name,
          calories: _totalCalories,
          reps: _reps.round(),
          imagePath: widget.initial!.imagePath,
        ),
      );
    } else {
      s.addExerciseRecord(ExerciseRecord(
        id: 'e${DateTime.now().millisecondsSinceEpoch}',
        time: DateTime.now(),
        name: name,
        calories: _totalCalories,
        reps: _reps.round(),
        imagePath: widget.result?.imagePath,
      ));
    }
    if (saveCalorie) {
      await StorageService.saveExerciseCalorie(name, kcalPerRep);
    }
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(duration: const Duration(seconds: 1), content: Text(_isEditing
          ? '已更新 $name ${_reps.round()} 次 $_totalCalories kcal'
          : (saveCalorie
              ? '已记录 $name ${_reps.round()} 次 $_totalCalories kcal,热量已保存'
              : '已记录 $name ${_reps.round()} 次 $_totalCalories kcal'))),
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
        const SnackBar(duration: Duration(seconds: 1), content: Text('请填写有效的能量值(kcal/100g)')),
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

