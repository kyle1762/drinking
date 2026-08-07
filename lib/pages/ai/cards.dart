part of 'ai_recognition_page.dart';

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

/// 四卡片并列行:个人信息 / AI建议 / 今日营养 / 今日摄入
/// 精简显示,点击展开浮层查看详情
class _InfoCardRow extends StatelessWidget {
  const _InfoCardRow();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.profile;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _compactCard(
              context: context,
              icon: Icons.person_outline,
              title: '个人信息',
              subtitle: p.profileComplete
                  ? 'BMI ${p.bmi?.toStringAsFixed(1) ?? "-"}'
                  : '未完善',
              bgColor: AppColors.softBlue,
              accentColor: AppColors.softBlueDeep,
              detail: const _ProfileCard(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _compactCard(
              context: context,
              icon: Icons.auto_awesome_outlined,
              title: 'AI建议',
              subtitle: (s.dietAdvice?.isValid ?? false) ? '已生成' : '未生成',
              bgColor: AppColors.mint,
              accentColor: AppColors.mintDeep,
              detail: const _DietAdviceCard(),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _compactCard(
              context: context,
              icon: Icons.pie_chart_outline,
              title: '今日营养',
              subtitle: s.profile.goal == UserGoal.loseFat
                  ? '纤维${s.todayFiber.toStringAsFixed(1)}g'
                  : s.profile.goal == UserGoal.gainMuscle
                      ? '蛋白${s.todayProtein.toStringAsFixed(1)}g'
                      : '${s.todayFoodCalories}kcal',
              bgColor: AppColors.banner,
              accentColor: const Color(0xFFE6A700),
              detail: const _NutritionStatsCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color accentColor,
    required Widget detail,
  }) {
    return RippleButton(
      onTap: () => _showDetail(context, detail),
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: accentColor.withAlpha(180),
                    fontSize: 9,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  /// 展开浮层:漂浮在界面上,点击外部关闭
  void _showDetail(BuildContext context, Widget detail) {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => _DetailOverlay(detail: detail),
    );
  }
}

/// 浮层容器:带阴影圆角,键盘适配,点击外部关闭
class _DetailOverlay extends StatelessWidget {
  const _DetailOverlay({required this.detail});
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 透明背景层:点击关闭
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        // 浮层内容:用 AnimatedPadding 推到键盘上方,避免输入框被遮挡
        AnimatedPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          duration: const Duration(milliseconds: 200),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.transparent,
                elevation: 12,
                shadowColor: AppColors.shadow,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: detail,
                        ),
                        // 关闭按钮
                        Positioned(
                          top: 4,
                          right: 8,
                          child: RippleButton(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: 16,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close,
                                  size: 18, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 个人信息卡片 - 性别/年龄/身高/体重,计算 BMI/BMR/每日消耗
class _ProfileCard extends StatefulWidget {
  const _ProfileCard();

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _editing = false;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _muscleCtrl;
  Gender _gender = Gender.unspecified;
  UserGoal _goal = UserGoal.maintain;
  // 个人形象图片(编辑期临时持有;保存时写入 UserProfile.imagePath)
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();
  bool _scanning = false; // 体测图片识别中

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _gender = p.gender;
    _goal = p.goal;
    _imagePath = p.imagePath;
    _ageCtrl = TextEditingController(text: p.age > 0 ? p.age.toString() : '');
    _heightCtrl =
        TextEditingController(text: p.height > 0 ? p.height.toString() : '');
    _weightCtrl =
        TextEditingController(text: p.weight > 0 ? p.weight.toString() : '');
    _muscleCtrl = TextEditingController(
        text: p.muscle > 0 ? p.muscle.toStringAsFixed(1) : '');
  }

  /// 选择个人形象图片(相册)
  Future<void> _pickImage() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xfile == null) return;
      setState(() => _imagePath = xfile.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片选择失败: $e')),
      );
    }
  }

  /// 移除已选个人形象图片
  void _removeImage() => setState(() => _imagePath = null);

  /// 选择体测图片并调用 AI 识别身高/体重/肌肉量
  Future<void> _scanBodyMetrics() async {
    if (!AiService.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在账户页配置 AI API Key')),
      );
      return;
    }
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xfile == null) return;
      setState(() => _scanning = true);
      final result = await AiService.recognizeBodyMetrics(xfile.path);
      if (!mounted) return;
      if (result == null) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('识别失败,请重试或检查图片清晰度')),
        );
        return;
      }
      setState(() {
        _scanning = false;
        if (result.height != null) {
          _heightCtrl.text = result.height!.round().toString();
        }
        if (result.weight != null) {
          _weightCtrl.text = result.weight!.round().toString();
        }
        if (result.muscle != null) {
          _muscleCtrl.text = result.muscle!.toStringAsFixed(1);
        }
        // 自动进入编辑模式以便用户确认/修改
        _editing = true;
      });
      final parts = <String>[];
      if (result.height != null) parts.add('身高${result.height!.round()}cm');
      if (result.weight != null) parts.add('体重${result.weight!.toStringAsFixed(1)}kg');
      if (result.muscle != null) parts.add('肌肉量${result.muscle!.toStringAsFixed(1)}kg');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parts.isEmpty ? '未识别到身体数据' : '已识别: ${parts.join(", ")}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('识别异常: $e')),
      );
    }
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _muscleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.profile;
    final complete = p.profileComplete;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        color: complete ? AppColors.mint : AppColors.softBlue,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 18,
                    color: complete
                        ? AppColors.mintDeep
                        : AppColors.softBlueDeep),
                const SizedBox(width: 6),
                Text(
                  complete ? '个人信息已完善' : '请完善个人信息',
                  style: TextStyle(
                    color: complete
                        ? AppColors.mintDeep
                        : AppColors.softBlueDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // 体测图片识别按钮(无需进入编辑模式即可使用)
                RippleButton(
                  onTap: _scanning ? null : _scanBodyMetrics,
                  borderRadius: 12,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: _scanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                    AppColors.softBlueDeep)),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.document_scanner_outlined,
                                  size: 14,
                                  color: complete
                                      ? AppColors.mintDeep
                                      : AppColors.softBlueDeep),
                              const SizedBox(width: 4),
                              Text(
                                '图片识别',
                                style: TextStyle(
                                  color: complete
                                      ? AppColors.mintDeep
                                      : AppColors.softBlueDeep,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 4),
                RippleButton(
                  onTap: () => setState(() => _editing = !_editing),
                  borderRadius: 12,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      _editing ? '收起' : '编辑',
                      style: TextStyle(
                        color: complete
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
              const SizedBox(height: 12),
              // 个人形象图片
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('个人形象',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  RippleButton(
                    onTap: _pickImage,
                    borderRadius: 12,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.divider, width: 0.5),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _imagePath != null
                          ? Image.file(File(_imagePath!),
                              fit: BoxFit.cover)
                          : const Icon(Icons.add_a_photo,
                              size: 22, color: AppColors.textSecondary),
                    ),
                  ),
                  if (_imagePath != null) ...[
                    const SizedBox(width: 8),
                    RippleButton(
                      onTap: _removeImage,
                      borderRadius: 8,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text('移除',
                            style: TextStyle(
                                color: AppColors.softBlueDeep,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // 性别选择
              const Text('性别',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _genderChip('男', Gender.male),
                  const SizedBox(width: 8),
                  _genderChip('女', Gender.female),
                ],
              ),
              const SizedBox(height: 12),
              // 目标选择
              const Text('近期目标',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _goalChip('保持身材', UserGoal.maintain),
                  _goalChip('减脂', UserGoal.loseFat),
                  _goalChip('增肌', UserGoal.gainMuscle),
                ],
              ),
              const SizedBox(height: 12),
              _inputRow('年龄', _ageCtrl, '岁'),
              const SizedBox(height: 8),
              _inputRow('身高', _heightCtrl, 'cm'),
              const SizedBox(height: 8),
              _inputRow('体重', _weightCtrl, 'kg'),
              const SizedBox(height: 8),
              _inputRow('肌肉量', _muscleCtrl, 'kg'),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 48),
                child: Text('填写肌肉量后,基础代谢将改用更精准的 Katch-McArdle 公式计算',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ),
              const SizedBox(height: 12),
              RippleButton(
                onTap: _save,
                borderRadius: AppThemeRadius.s,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: complete
                        ? AppColors.mintDeep
                        : AppColors.softBlueDeep,
                    borderRadius: BorderRadius.circular(AppThemeRadius.s),
                  ),
                  alignment: Alignment.center,
                  child: const Text('保存',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.imagePath != null) ...[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.file(File(p.imagePath!),
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (complete) ...[
                          _infoChip('性别', p.gender == Gender.male ? '男' : '女'),
                          _infoChip('年龄', '${p.age}岁'),
                          _infoChip('身高', '${p.height}cm'),
                          _infoChip('体重', '${p.weight}kg'),
                          if (p.muscle > 0)
                            _infoChip('肌肉量', '${p.muscle.toStringAsFixed(1)}kg'),
                          if (p.bmi != null)
                            _infoChip('BMI', p.bmi!.toStringAsFixed(1)),
                          if (p.bmr != null)
                            _infoChip('基础代谢', '${p.bmr}kcal'),
                          _infoChip('目标', _goalLabel(p.goal)),
                        ] else ...[
                          _infoChip('提示', '请完善性别/年龄/身高/体重'),
                        ],
                      ],
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

  Widget _genderChip(String label, Gender g) {
    final selected = _gender == g;
    return RippleButton(
      onTap: () => setState(() => _gender = g),
      borderRadius: AppThemeRadius.s,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.softBlueDeep : AppColors.cream,
          borderRadius: BorderRadius.circular(AppThemeRadius.s),
          border: Border.all(
            color: selected ? AppColors.softBlueDeep : Colors.transparent,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }

  Widget _goalChip(String label, UserGoal g) {
    final selected = _goal == g;
    return RippleButton(
      onTap: () => setState(() => _goal = g),
      borderRadius: AppThemeRadius.s,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.mintDeep : AppColors.cream,
          borderRadius: BorderRadius.circular(AppThemeRadius.s),
          border: Border.all(
            color: selected ? AppColors.mintDeep : Colors.transparent,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }

  static String _goalLabel(UserGoal g) => switch (g) {
        UserGoal.maintain => '保持身材',
        UserGoal.loseFat => '减脂',
        UserGoal.gainMuscle => '增肌',
      };

  Widget _inputRow(
      String label, TextEditingController ctrl, String suffix) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
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
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label: $value',
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500)),
    );
  }

  void _save() {
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final height = int.tryParse(_heightCtrl.text.trim()) ?? 0;
    final weight = int.tryParse(_weightCtrl.text.trim()) ?? 0;
    final muscle = double.tryParse(_muscleCtrl.text.trim()) ?? 0;
    final s = context.read<AppState>();
    final goalChanged = s.profile.goal != _goal;
    var newProfile = s.profile.copyWith(
      gender: _gender,
      age: age,
      height: height,
      weight: weight,
      muscle: muscle,
      goal: _goal,
      imagePath: _imagePath,
    );
    // 目标变更后自动切换饮食方案(增肌 -> 增肌方案;减脂/保持 -> 减肥方法),默认选第一个
    if (goalChanged) {
      final plans = DietMethods.allFor(_goal);
      if (plans.isNotEmpty) {
        newProfile = newProfile.copyWith(dietMethodId: plans.first.id);
      }
    }
    s.updateProfile(newProfile);
    // 目标变更后,清空旧建议(新目标需要重新分析)
    if (goalChanged) {
      s.setDietAdvice(DietAdvice(
        createdAt: DateTime.now(),
        goal: _goal,
        eatMore: const [],
        eatLess: const [],
        summary: '目标已变更,请重新生成饮食建议',
        suggestedCalories: s.suggestedCalories ?? 1800,
        suggestedProtein: s.suggestedProtein ?? 60.0,
        suggestedFat: s.suggestedFat ?? 50.0,
        suggestedCarbs: s.suggestedCarbs ?? 200.0,
        suggestedFiber: s.suggestedFiber ?? 25.0,
        validUntil: DateTime.now().add(const Duration(days: 3)),
      ));
    }
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('个人信息已保存')),
    );
  }
}

/// 营养物质统计卡片 - 蛋白质/脂肪/碳水/膳食纤维
/// 减脂目标:碳水/脂肪/膳食纤维 显示「已摄入/建议摄入」
/// 增肌目标:蛋白质/碳水 显示「已摄入/建议摄入」
class _NutritionStatsCard extends StatelessWidget {
  const _NutritionStatsCard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final total = s.todayProtein + s.todayFat + s.todayCarbs;
    final goal = s.profile.goal;
    // 根据目标判断哪些营养素需要显示建议值
    final showCarbsSug = goal == UserGoal.loseFat || goal == UserGoal.gainMuscle;
    final showFatSug = goal == UserGoal.loseFat;
    final showProteinSug = goal == UserGoal.gainMuscle;
    final showFiberSug = goal == UserGoal.loseFat;
    final hasSuggestion = goal != UserGoal.maintain &&
        (s.suggestedProtein != null ||
            s.suggestedFat != null ||
            s.suggestedCarbs != null ||
            s.suggestedFiber != null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('今日营养构成',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                if (hasSuggestion) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.mint.withAlpha(80),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      goal == UserGoal.loseFat ? '减脂模式' : '增肌模式',
                      style: const TextStyle(
                          color: AppColors.mintDeep,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (total <= 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无饮食记录',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              )
            else ...[
              // 营养比例条
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    if (s.todayCarbs > 0)
                      Expanded(
                        flex: (s.todayCarbs * 100).round(),
                        child: Container(height: 8, color: const Color(0xFFFFB380)),
                      ),
                    if (s.todayProtein > 0)
                      Expanded(
                        flex: (s.todayProtein * 100).round(),
                        child: Container(height: 8, color: AppColors.mintDeep),
                      ),
                    if (s.todayFat > 0)
                      Expanded(
                        flex: (s.todayFat * 100).round(),
                        child: Container(height: 8, color: AppColors.softBlueDeep),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  showCarbsSug && s.suggestedCarbs != null
                      ? _nutItemWithSuggestion('碳水', s.todayCarbs,
                          s.suggestedCarbs!, 'g', const Color(0xFFFFB380))
                      : _nutItem('碳水', s.todayCarbs, 'g', const Color(0xFFFFB380)),
                  showProteinSug && s.suggestedProtein != null
                      ? _nutItemWithSuggestion('蛋白质', s.todayProtein,
                          s.suggestedProtein!, 'g', AppColors.mintDeep)
                      : _nutItem('蛋白质', s.todayProtein, 'g', AppColors.mintDeep),
                  showFatSug && s.suggestedFat != null
                      ? _nutItemWithSuggestion('脂肪', s.todayFat,
                          s.suggestedFat!, 'g', AppColors.softBlueDeep)
                      : _nutItem('脂肪', s.todayFat, 'g', AppColors.softBlueDeep),
                  showFiberSug
                      ? _nutItemWithSuggestion('膳食纤维', s.todayFiber,
                          s.suggestedFiber ?? 25.0, 'g', const Color(0xFFB39DDB))
                      : _nutItem('膳食纤维', s.todayFiber, 'g', const Color(0xFFB39DDB)),
                ],
              ),
              if (hasSuggestion)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('*显示为「已摄入/建议摄入」,建议值会根据近期饮食动态调整',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nutItem(String label, double value, String unit, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(1)}$unit',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  /// 已摄入/建议摄入 格式的营养项
  Widget _nutItemWithSuggestion(
      String label, double actual, double suggested, String unit, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: actual.toStringAsFixed(1),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: '/${suggested.toStringAsFixed(1)}$unit',
                style: TextStyle(
                    color: color.withAlpha(160),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 热量表盘卡片
/// 半圆表盘:左半红色弧=摄入热量,右半绿色弧=消耗热量(含BMR)
/// 中心显示日消耗值(消耗+BMR-摄入),不足目标时显示鼓励文案
class _CalorieDialCard extends StatelessWidget {
  const _CalorieDialCard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final dailyBurn = s.todayDailyBurn;
    final suggestedBurn = s.suggestedDailyBurn;
    final intake = s.todayFoodCalories;
    final bmr = s.profile.bmr ?? 0;
    // 消耗侧 = 运动消耗 + BMR(基础代谢也是消耗的一部分)
    final consume = s.todayExerciseCalories + bmr;

    // 目标缺口:日消耗 < 建议日消耗时,显示还差多少 kcal
    final showGap = dailyBurn != null &&
        suggestedBurn != null &&
        dailyBurn < suggestedBurn;
    final gap = showGap ? (suggestedBurn - dailyBurn) : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.speed_outlined,
                    size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 6),
                const Text('热量表盘',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                _legend(const Color(0xFFE57373), '摄入'),
                const SizedBox(width: 8),
                _legend(const Color(0xFF66BB6A), '消耗'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 150,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _DialPainter(
                      intake: intake.toDouble(),
                      consume: consume.toDouble(),
                    ),
                  ),
                  // 中心数值
                  Positioned(
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dailyBurn != null ? '$dailyBurn' : '--',
                          style: TextStyle(
                            color: dailyBurn != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text('日消耗 kcal',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 摄入 | 基础代谢 | 消耗 三列数值标注
            Row(
              children: [
                Expanded(
                  child: _sideLabel('摄入', '$intake', const Color(0xFFE57373)),
                ),
                Expanded(
                  child: _sideLabel(
                      '基础代谢', bmr > 0 ? '$bmr' : '--', AppColors.textSecondary),
                ),
                Expanded(
                  child: _sideLabel(
                      '消耗', '$consume', const Color(0xFF66BB6A)),
                ),
              ],
            ),
            if (showGap) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.banner,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined,
                        size: 16, color: Color(0xFFE6A700)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '距离今日目标还差 $gap kcal,继续加油哦~',
                        style: const TextStyle(
                            color: Color(0xFFE6A700),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (dailyBurn == null) ...[
              const SizedBox(height: 8),
              const Text('*完善个人信息后可计算每日消耗',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legend(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _sideLabel(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 2),
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text('kcal',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 9)),
            ),
          ],
        ),
      ],
    );
  }
}

/// 热量表盘画板:上半圆,红(摄入)和绿(消耗)按比例分割整个180度半圆
/// 摄入越多红色弧越大,消耗越多绿色弧越大,两者此消彼长
class _DialPainter extends CustomPainter {
  final double intake;
  final double consume;
  _DialPainter({
    required this.intake,
    required this.consume,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 圆心放在底部中央,半径自适应宽高
    final center = Offset(w / 2, h - 8);
    final radius = (w / 2 - 20).clamp(40.0, 160.0);

    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 18.0;
    const halfCircle = math.pi; // 180度

    // 背景轨道:上半圆(从 9 点经 12 点到 3 点)
    final bgPaint = Paint()
      ..color = AppColors.paused
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, halfCircle, false, bgPaint);

    // 按摄入/消耗比例分割180度(两者都为0时各占90度)
    final total = intake + consume;
    final intakeFrac = total > 0 ? intake / total : 0.5;
    final consumeFrac = total > 0 ? consume / total : 0.5;

    // 红色弧(摄入):从 9 点(π)顺时针生长,角度 = π * intakeFrac
    if (intakeFrac > 0) {
      final redPaint = Paint()
        ..color = const Color(0xFFE57373)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, math.pi, halfCircle * intakeFrac, false, redPaint);
    }

    // 绿色弧(消耗):从 3 点(2π)逆时针生长,即从 2π - π*consumeFrac 开始
    if (consumeFrac > 0) {
      final greenPaint = Paint()
        ..color = const Color(0xFF66BB6A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      final start = 2 * math.pi - halfCircle * consumeFrac;
      canvas.drawArc(rect, start, halfCircle * consumeFrac, false, greenPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.intake != intake || old.consume != consume;
}

/// 摄入不足提示卡片
class _IntakeWarningCard extends StatelessWidget {
  const _IntakeWarningCard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.isIntakeTooLow) return const SizedBox.shrink();
    final min = s.profile.minIntake;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        color: const Color(0xFFFFE0B2),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 20, color: Color(0xFFE65100)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '今日饮食量不足(${s.todayFoodCalories}kcal < 最低${min}kcal),请增加饮食摄入。',
                style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 减肥方法选择卡片
/// 展示已选减肥方法 + 推荐吃/避免吃的食物,点击可更换
class _DietMethodCard extends StatelessWidget {
  const _DietMethodCard();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final isGain = s.profile.goal == UserGoal.gainMuscle;
    final method =
        DietMethods.findByIdFor(s.profile.goal, s.profile.dietMethodId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        color: method != null ? AppColors.mint : AppColors.softBlue,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu_outlined,
                    size: 18,
                    color: method != null
                        ? AppColors.mintDeep
                        : AppColors.softBlueDeep),
                const SizedBox(width: 6),
                Text(
                  method != null
                      ? '已选择: ${method.name}'
                      : (isGain ? '选择增肌方案' : '选择减肥方法'),
                  style: TextStyle(
                    color: method != null
                        ? AppColors.mintDeep
                        : AppColors.softBlueDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                RippleButton(
                  onTap: () => _showDietMethodDialog(context),
                  borderRadius: 12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Text(
                      method != null ? '更换' : '选择',
                      style: TextStyle(
                        color: method != null
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
            if (method != null) ...[
              const SizedBox(height: 8),
              Text(
                method.description,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _dietTag('推荐吃', method.allowedFoods.take(3).join('、'),
                      AppColors.mintDeep),
                  const SizedBox(width: 6),
                  _dietTag('避免吃', method.forbiddenFoods.take(3).join('、'),
                      const Color(0xFFE65100)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dietTag(String label, String content, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(content,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 11, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showDietMethodDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final s = context.read<AppState>();
        final isGain = s.profile.goal == UserGoal.gainMuscle;
        final plans = DietMethods.allFor(s.profile.goal);
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu,
                            size: 20, color: AppColors.softBlueDeep),
                        const SizedBox(width: 8),
                        Text(isGain ? '选择增肌方案' : '选择减肥方法',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const Spacer(),
                        if (s.profile.dietMethodId.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              s.updateProfile(
                                  s.profile.copyWith(dietMethodId: ''));
                              Navigator.pop(ctx);
                            },
                            child: const Text('清除',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: plans.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final m = plans[i];
                          final selected = m.id == s.profile.dietMethodId;
                          return InkWell(
                            onTap: () {
                              s.updateProfile(
                                  s.profile.copyWith(dietMethodId: m.id));
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.mint
                                    : AppColors.cream,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.mintDeep
                                      : AppColors.divider,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(m.name,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: selected
                                                  ? AppColors.mintDeep
                                                  : AppColors.textPrimary)),
                                      const Spacer(),
                                      if (selected)
                                        const Icon(Icons.check_circle,
                                            size: 18,
                                            color: AppColors.mintDeep),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(m.description,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.4)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      ...m.allowedFoods.take(4).map((f) =>
                                          _foodChip(f, AppColors.mintDeep,
                                              true)),
                                      ...m.forbiddenFoods
                                          .take(3)
                                          .map((f) => _foodChip(
                                              f,
                                              const Color(0xFFE65100),
                                              false)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('适合: ${m.suitableFor}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textDisabled,
                                          fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _foodChip(String name, Color color, bool allowed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(allowed ? Icons.check : Icons.block,
              size: 10, color: color),
          const SizedBox(width: 3),
          Text(name,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// AI 饮食建议卡片
/// 显示建议多吃/少吃的食物种类 + 建议摄入量 + 触发分析按钮
class _DietAdviceCard extends StatefulWidget {
  const _DietAdviceCard();

  @override
  State<_DietAdviceCard> createState() => _DietAdviceCardState();
}

class _DietAdviceCardState extends State<_DietAdviceCard> {
  bool _analyzing = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final advice = s.dietAdvice;
    final goal = s.profile.goal;
    final goalLabel = switch (goal) {
      UserGoal.maintain => '保持身材',
      UserGoal.loseFat => '减脂',
      UserGoal.gainMuscle => '增肌',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        color: AppColors.mint,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined,
                    size: 18, color: AppColors.mintDeep),
                const SizedBox(width: 6),
                const Text('AI 饮食建议',
                    style: TextStyle(
                        color: AppColors.mintDeep,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.mintDeep.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(goalLabel,
                      style: const TextStyle(
                          color: AppColors.mintDeep,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                if (advice != null && advice.isValid)
                  Text(
                    '有效期至 ${advice.validUntil.month}-${advice.validUntil.day}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 10),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (advice != null && advice.isValid) ...[
              // 总结
              if (advice.summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(advice.summary,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              // 建议多吃
              if (advice.eatMore.isNotEmpty) ...[
                const Text('建议多吃',
                    style: TextStyle(
                        color: AppColors.mintDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: advice.eatMore
                      .map((e) => _adviceChip(e, AppColors.mintDeep,
                          Icons.thumb_up_outlined))
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              // 建议少吃
              if (advice.eatLess.isNotEmpty) ...[
                const Text('建议少吃',
                    style: TextStyle(
                        color: Color(0xFFE65100),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: advice.eatLess
                      .map((e) => _adviceChip(
                          e, const Color(0xFFE65100), Icons.thumb_down_outlined))
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              // 建议摄入量
              const Text('每日建议摄入量',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _suggestionChip('热量', '${advice.suggestedCalories}kcal'),
                  _suggestionChip(
                      '蛋白质', '${advice.suggestedProtein.toStringAsFixed(1)}g'),
                  _suggestionChip(
                      '脂肪', '${advice.suggestedFat.toStringAsFixed(1)}g'),
                  _suggestionChip(
                      '碳水', '${advice.suggestedCarbs.toStringAsFixed(1)}g'),
                  _suggestionChip(
                      '纤维', '${advice.suggestedFiber.toStringAsFixed(1)}g'),
                ],
              ),
            ] else ...[
              const Text('暂无 AI 建议,点击下方按钮根据近期饮食生成个性化建议',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            // 触发分析按钮
            Align(
              alignment: Alignment.centerRight,
              child: RippleButton(
                onTap: _analyzing ? null : () => _triggerAnalysis(context),
                borderRadius: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _analyzing
                        ? AppColors.mintDeep.withAlpha(120)
                        : AppColors.mintDeep,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_analyzing)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.refresh,
                              size: 14, color: Colors.white),
                        ),
                      Text(
                        _analyzing ? '分析中...' : '生成饮食建议',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adviceChip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value',
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _triggerAnalysis(BuildContext context) async {
    final s = context.read<AppState>();
    if (!s.profile.profileComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完善个人信息(性别/年龄/身高/体重)')),
      );
      return;
    }
    setState(() => _analyzing = true);
    try {
      final (success, message) = await s.triggerDietAnalysis();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分析失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }
}

/// 拍照记录卡片 - 合并饮食/运动入口
/// 点击后先选择"记录食物"或"记录运动",再选择拍照/相册/手动输入
class _ActionCards extends StatelessWidget {
  const _ActionCards();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreamCard(
        onTap: () => _chooseRecordType(context),
        color: AppColors.softBlue,
        radius: AppThemeRadius.l,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_outlined,
                  size: 24, color: AppColors.softBlueDeep),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('拍照记录',
                      style: TextStyle(
                          color: AppColors.softBlueDeep,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('点击拍照/选择图片,识别后选择记录食物或运动',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 22, color: AppColors.softBlueDeep),
          ],
        ),
      ),
    );
  }

  /// 第一步:选择记录类型(食物/运动)
  Future<void> _chooseRecordType(BuildContext context) async {
    final type = await showModalBottomSheet<AiRecognitionType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _RecordTypeSheet(),
    );
    if (type == null) return;
    if (!context.mounted) return;
    await _pickAndRecognize(context, type);
  }

  Future<void> _pickAndRecognize(
      BuildContext context, AiRecognitionType type) async {
    final isFood = type == AiRecognitionType.food;
    _ImageSource? source;
    source = await showModalBottomSheet<_ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SourceSheet(withManual: true, isFood: isFood),
    );
    if (source == null) return;
    if (!context.mounted) return;

    // 手动输入:同样进入统一记录界面
    if (source == _ImageSource.manual) {
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => isFood
            ? const _FoodRecordSheet()
            : const _ExerciseRecordSheet(),
      );
      return;
    }

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
      builder: (ctx) => isFood
          ? _FoodRecordSheet(result: result)
          : _ExerciseRecordSheet(result: result),
    );
  }
}

