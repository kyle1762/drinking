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
}
