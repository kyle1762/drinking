import '../models/models.dart';

/// 食材与饮食方案(减肥/增肌)的匹配状态
/// 用于食材列表的颜色标识:推荐=绿、避免=红、其余=白
enum DietFoodStatus { allowed, forbidden, neutral }

/// 减肥方法预设数据库
/// 每种方法包含:名称、描述、推荐吃的食物、避免吃的食物、适用人群
class DietMethod {
  final String id;
  final String name;
  final String description;
  final List<String> allowedFoods;
  final List<String> forbiddenFoods;
  final String suitableFor;

  const DietMethod({
    required this.id,
    required this.name,
    required this.description,
    required this.allowedFoods,
    required this.forbiddenFoods,
    required this.suitableFor,
  });
}

/// 预设减肥方法列表
class DietMethods {
  DietMethods._();

  static const all = <DietMethod>[
    DietMethod(
      id: 'keto',
      name: '生酮饮食',
      description: '高脂肪(70%)、适量蛋白质(25%)、极低碳水(5%),通过燃烧脂肪供能',
      allowedFoods: ['肉类', '鱼类', '蛋类', '奶酪', '坚果', '牛油果', '橄榄油', '椰子油', '绿叶蔬菜'],
      forbiddenFoods: ['米饭', '面条', '面包', '糖类', '薯类', '水果(少量莓果除外)', '含糖饮料', '糕点'],
      suitableFor: '需快速减脂、无肝肾疾病的人群',
    ),
    DietMethod(
      id: 'low_carb',
      name: '低碳水饮食',
      description: '减少碳水摄入,增加蛋白质和健康脂肪,适度控制总热量',
      allowedFoods: ['鸡胸肉', '鱼虾', '鸡蛋', '豆腐', '蔬菜', '坚果', '全谷物(少量)', '橄榄油'],
      forbiddenFoods: ['精制米面', '含糖饮料', '甜食', '油炸食品', '加工肉类', '糕点'],
      suitableFor: '一般减脂人群,容易坚持',
    ),
    DietMethod(
      id: 'intermittent_fasting',
      name: '轻断食(16:8)',
      description: '每日16小时禁食,8小时进食窗口,促进脂肪燃烧和细胞自噬',
      allowedFoods: ['进食窗口内:正常均衡饮食', '优质蛋白', '蔬菜', '全谷物', '健康脂肪'],
      forbiddenFoods: ['禁食窗口内:任何含热量食物', '含糖饮料', '可喝水和无糖茶/黑咖啡'],
      suitableFor: '作息规律、无低血糖问题的人群',
    ),
    DietMethod(
      id: 'mediterranean',
      name: '地中海饮食',
      description: '以植物性食物为主,富含橄榄油、鱼类、坚果,心血管友好',
      allowedFoods: ['深海鱼', '橄榄油', '全谷物', '豆类', '坚果', '蔬菜水果', '适量红酒'],
      forbiddenFoods: ['红肉(少量)', '加工食品', '黄油', '甜食', '油炸食品'],
      suitableFor: '追求健康长期饮食、心血管保养',
    ),
    DietMethod(
      id: 'dash',
      name: 'DASH饮食',
      description: '得舒饮食,高钾高钙高纤维,低钠低饱和脂肪,降压减脂',
      allowedFoods: ['全谷物', '蔬菜', '水果', '低脂乳制品', '瘦肉', '鱼类', '豆类', '坚果'],
      forbiddenFoods: ['高盐食品', '腌制食品', '肥肉', '全脂乳制品(适量)', '含糖饮料', '加工食品'],
      suitableFor: '高血压人群、需控盐减脂',
    ),
    DietMethod(
      id: 'high_protein',
      name: '高蛋白饮食',
      description: '蛋白质占比30%以上,增强饱腹感,保肌肉促减脂',
      allowedFoods: ['鸡胸肉', '牛肉', '鱼虾', '蛋白', '希腊酸奶', '豆腐', '蛋白粉', '蔬菜'],
      forbiddenFoods: ['精制碳水', '含糖饮料', '油炸食品', '高脂零食', '酒精'],
      suitableFor: '健身增肌减脂人群、无肾脏疾病',
    ),
  ];

  /// 按 id 查找
  static DietMethod? findById(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// 增肌方案预设列表(用户目标为增肌时展示)
  static const muscleGain = <DietMethod>[
    DietMethod(
      id: 'gain_high_protein',
      name: '增肌高蛋白饮食',
      description: '热量盈余约10%,蛋白质约2g/kg体重,高蛋白高碳水配合力量训练增肌',
      allowedFoods: ['鸡胸肉', '牛肉', '三文鱼', '鸡蛋', '牛奶', '希腊酸奶', '燕麦', '糙米', '香蕉', '花生酱', '豆腐', '西蓝花'],
      forbiddenFoods: ['含糖饮料', '油炸食品', '酒精', '精制甜点', '速食食品', '高糖零食'],
      suitableFor: '增肌人群、无肾脏疾病',
    ),
    DietMethod(
      id: 'gain_clean_bulk',
      name: '干净增肌(少增脂)',
      description: '热量盈余5-8%,优先高蛋白+慢碳,控制额外脂肪,增肌同时减少脂肪堆积',
      allowedFoods: ['鸡胸肉', '鱼虾', '鸡蛋', '燕麦', '糙米', '红薯', '西蓝花', '牛油果', '橄榄油', '全麦面包'],
      forbiddenFoods: ['油炸食品', '含糖饮料', '精制米面', '甜食', '酒精', '高脂零食'],
      suitableFor: '希望在增肌期控制体脂增长的人群',
    ),
  ];

  /// 根据目标返回可选方案:增肌 -> 增肌方案;其余 -> 减肥方法
  static List<DietMethod> allFor(UserGoal goal) =>
      goal == UserGoal.gainMuscle ? muscleGain : all;

  /// 按目标 + id 查找方案
  static DietMethod? findByIdFor(UserGoal goal, String id) {
    for (final m in allFor(goal)) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// 判断某食材在当前方案下的匹配状态(避免吃优先于推荐吃)
  static DietFoodStatus classify(String foodName, DietMethod? method) {
    if (method == null) return DietFoodStatus.neutral;
    for (final f in method.forbiddenFoods) {
      if (_matches(f, foodName)) return DietFoodStatus.forbidden;
    }
    for (final a in method.allowedFoods) {
      if (_matches(a, foodName)) return DietFoodStatus.allowed;
    }
    return DietFoodStatus.neutral;
  }

  /// 计算一次记录中「避免吃」食材的总克数(用于红色摄入过多提醒)
  ///
  /// [totalRatio] 为食材占比总和(用户编辑后可能≠1),>0 时按此归一化,
  /// 保证红色克数与营养计算口径一致;为 null 或 <=0 时直接用原始占比。
  static double forbiddenGramsOf(List<FoodIngredient> ings, double amount,
      DietMethod? method,
      {double? totalRatio}) {
    final sum = (totalRatio != null && totalRatio > 0) ? totalRatio : 1.0;
    double grams = 0;
    for (final ing in ings) {
      if (classify(ing.name, method) == DietFoodStatus.forbidden) {
        grams += amount * ing.ratio / sum;
      }
    }
    return grams;
  }

  /// 去除括号说明后取主体,如「水果(少量莓果除外)」->「水果」
  static String _normalizeTerm(String s) {
    var t = s.trim();
    final paren = t.indexOf('(');
    if (paren >= 0) t = t.substring(0, paren);
    return t.trim();
  }

  /// 类别关键词表:把「蔬菜」「肉类」等类别词展开为常见代表食材
  /// 用于把菜名与方案里的类别词做模糊匹配(避免误伤,使用具体词汇)
  static const Map<String, List<String>> _categoryKeywords = {
    '蔬菜': ['菜', '瓜', '萝卜', '番茄', '茄子', '青椒', '彩椒', '笋', '豆芽', '菠菜', '生菜', '芹菜', '西兰花', '芦笋', '秋葵', '葱', '蒜', '藕', '菇', '菌'],
    '绿叶蔬菜': ['菠菜', '生菜', '芹菜', '苋菜', '茼蒿', '芥菜', '油菜', '白菜', '空心菜', '油麦菜', '西兰花', '韭菜'],
    '蔬菜水果': ['菜', '瓜', '萝卜', '番茄', '茄子', '青椒', '彩椒', '笋', '豆芽', '菠菜', '生菜', '芹菜', '西兰花', '芦笋', '秋葵', '葱', '蒜', '藕', '菇', '菌', '莓', '香蕉', '苹果', '橙子', '梨', '桃子', '葡萄', '西瓜', '柚子', '猕猴桃', '牛油果'],
    '水果': ['莓', '香蕉', '苹果', '橙', '梨', '桃', '杏', '李', '枣', '葡萄', '西瓜', '柚子', '猕猴桃', '芒果', '菠萝', '樱桃', '柠檬', '石榴', '山楂'],
    '薯类': ['薯', '土豆', '山药', '芋头', '芋'],
    '蛋类': ['蛋'],
    '肉类': ['肉', '鸡腿', '牛腩', '羊排', '排骨', '培根', '火腿', '香肠'],
    '鱼类': ['鱼'],
    '鱼虾': ['鱼', '虾', '贝', '蟹', '鱿鱼', '章鱼', '扇贝'],
    '深海鱼': ['三文鱼', '金枪鱼', '鳕鱼', '沙丁鱼', '鲭鱼', '鲈鱼', '带鱼'],
    '坚果': ['坚果', '核桃', '杏仁', '花生', '瓜子', '腰果', '开心果', '榛子', '碧根果'],
    '豆类': ['豆'],
    '乳制品': ['奶', '酸奶', '奶酪', '芝士'],
    '低脂乳制品': ['低脂', '脱脂', '酸奶'],
    '全脂乳制品': ['全脂', '奶油', '黄油', '芝士'],
    '奶酪': ['奶酪', '芝士', '起司'],
    '黄油': ['黄油', '奶油'],
    '橄榄油': ['橄榄油', '橄榄'],
    '椰子油': ['椰子油'],
    '健康脂肪': ['橄榄油', '牛油果', '坚果', '鱼油', '亚麻籽'],
    '优质蛋白': ['鸡胸', '鱼', '虾', '牛肉', '瘦肉', '豆腐', '蛋白'],
    '全谷物': ['全麦', '燕麦', '糙米', '藜麦', '荞麦', '玉米', '小米', '高粱', '黑米', '薏米'],
    '精制米面': ['白米', '精米', '面粉', '馒头', '面条', '面包', '白面', '米饭', '米粉', '米线', '饺子', '馄饨'],
    '精制碳水': ['白米', '精米', '面粉', '馒头', '面条', '面包', '白面', '米饭', '米粉', '米线', '饺子', '馄饨'],
    '含糖饮料': ['饮料', '可乐', '奶茶', '汽水', '果汁', '雪碧'],
    '油炸食品': ['炸', '油条', '薯条', '天妇罗', '油饼', '油炸'],
    '甜食': ['甜点', '甜食', '蛋糕', '饼干', '巧克力', '冰淇淋', '糖果', '甜品'],
    '糖类': ['糖', '蜂蜜', '巧克力', '糖果'],
    '糕点': ['糕', '饼', '酥', '曲奇', '派', '挞', '面包', '吐司'],
    '酒精': ['酒', '啤酒', '白酒', '红酒', '葡萄酒', '威士忌'],
    '高盐食品': ['腌', '咸菜', '腊', '泡菜', '酱', '腐乳', '榨菜'],
    '腌制食品': ['腌', '咸菜', '泡菜', '酱', '腐乳', '榨菜'],
    '加工食品': ['火腿', '培根', '香肠', '罐头', '方便面', '薯片', '火腿肠', '速冻'],
    '加工肉类': ['火腿', '培根', '香肠', '腊肉', '火腿肠', '午餐肉'],
    '红肉': ['牛肉', '牛腩', '牛排', '羊肉', '羊排', '猪肉', '五花肉', '培根', '火腿', '猪排'],
    '瘦肉': ['鸡胸', '里脊', '牛腱', '去皮', '瘦肉'],
    '肥肉': ['肥肉', '五花肉', '肥肠', '猪蹄'],
    '鸡胸肉': ['鸡胸'],
    '牛肉': ['牛肉', '牛腩', '牛排'],
    '三文鱼': ['三文鱼'],
    '鸡蛋': ['鸡蛋'],
    '牛奶': ['牛奶'],
    '希腊酸奶': ['酸奶'],
    '蛋白粉': ['蛋白粉', '乳清'],
    '豆腐': ['豆腐', '豆干', '千张', '腐竹'],
    '燕麦': ['燕麦'],
    '糙米': ['糙米'],
    '香蕉': ['香蕉'],
    '花生酱': ['花生酱'],
    '西蓝花': ['西蓝花', '西兰花'],
    '红薯': ['红薯', '地瓜'],
    '牛油果': ['牛油果', '鳄梨'],
    '全麦面包': ['全麦'],
    '高脂零食': ['薯片', '辣条', '饼干', '巧克力', '油炸'],
    '精制甜点': ['蛋糕', '饼干', '甜点', '甜品', '马卡龙'],
    '速食食品': ['方便面', '自热', '速食', '快餐', '汉堡'],
    '高糖零食': ['糖果', '巧克力', '饼干', '蜜饯', '果脯'],
  };

  /// 全谷物成分标记:含这些成分的食物不判为精制碳水
  static const List<String> _wholeGrainMarkers = [
    '糙米', '全麦', '燕麦', '杂粮', '粗粮', '藜麦', '荞麦',
    '玉米', '小米', '高粱', '黑米', '薏米', '全谷物',
  ];

  static bool _matches(String term, String food) {
    final t = _normalizeTerm(term);
    final f = food.trim();
    if (t.isEmpty || f.isEmpty) return false;
    final isRefined = t == '精制米面' || t == '精制碳水';
    // 含全谷物成分的食物不判为精制碳水(如"糙米饭""燕麦粥")
    bool wholeGrain() => _wholeGrainMarkers.any(f.contains);
    if (t == f) return true;
    if (t.contains(f) || f.contains(t)) {
      if (isRefined && wholeGrain()) return false;
      return true;
    }
    final keywords = _categoryKeywords[t];
    if (keywords != null) {
      for (final k in keywords) {
        if (f.contains(k)) {
          if (isRefined && wholeGrain()) return false;
          return true;
        }
      }
    }
    // 类别词兜底:如「肉类」->「肉」,再尝试匹配
    if (t.length > 2 && t.endsWith('类')) {
      final base = t.substring(0, t.length - 1);
      if (base.isNotEmpty && (base.contains(f) || f.contains(base))) {
        return true;
      }
    }
    return false;
  }
}
