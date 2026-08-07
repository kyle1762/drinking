import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../data/food_nutrition.dart';
import 'storage_service.dart';

/// AI 识别服务
/// - 对接智谱 GLM-4V-Flash(免费图片理解模型)
/// - 食物识别:AI 识别菜品名+食材列表+比例,营养数据从本地营养表查询
/// - 运动识别:AI 识别运动类型和单次消耗
/// - 管理 API Key 的读写
class AiService {
  AiService._();

  // ========== 智谱 API 配置 ==========

  /// 智谱 API Endpoint
  static const _endpoint =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  /// 图片理解模型(免费)
  static const _model = 'glm-4v-flash';

  /// 文本模型(免费,用于食材营养查询和运动卡路里估算)
  static const _textModel = 'glm-4-flash';

  // ========== API Key 管理 ==========

  /// 获取已保存的 API Key(直接读取单 key,避免反序列化全部配置)
  static String get apiKey => StorageService.getAiApiKey();

  /// 保存 API Key
  static Future<void> saveApiKey(String key) async {
    await StorageService.saveAiApiKey(key);
  }

  /// 是否已配置 API Key
  static bool get hasApiKey => apiKey.isNotEmpty;

  // ========== 图片选择 ==========

  static final ImagePicker _picker = ImagePicker();

  /// 调起相机拍照
  static Future<XFile?> pickFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
    } catch (e) {
      debugPrint('[AiService] 相机调用失败: $e');
      return null;
    }
  }

  /// 调起相册选图
  static Future<XFile?> pickFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    } catch (e) {
      debugPrint('[AiService] 相册调用失败: $e');
      return null;
    }
  }

  // ========== AI 识别 ==========

  /// 识别图片(食物或运动)
  /// [type] 指定识别类型:食物/运动
  /// [imagePath] 本地图片路径
  /// 返回 AiRecognitionResult,失败返回 null
  static Future<AiRecognitionResult?> recognize({
    required AiRecognitionType type,
    required String imagePath,
  }) async {
    // 如果没有配置 API Key,返回 Mock 数据用于演示
    if (!hasApiKey) {
      return _mockRecognize(type, imagePath);
    }
    try {
      return await _callAiApi(type: type, imagePath: imagePath);
    } catch (e) {
      debugPrint('[AiService] AI 识别失败: $e');
      return null;
    }
  }

  /// 调用智谱 GLM-4V-Flash API 进行图片识别
  /// 食物:要求 AI 识别菜品中的食材及占比,营养数据从本地营养表查询
  /// 运动:要求 AI 识别运动类型和单次消耗
  static Future<AiRecognitionResult> _callAiApi({
    required AiRecognitionType type,
    required String imagePath,
  }) async {
    final key = apiKey;

    // 读取图片并转 base64
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);
    final imageUrl = 'data:image/jpeg;base64,$base64Image';

    // 构造提示词
    final prompt = type == AiRecognitionType.food
        ? _buildFoodPrompt()
        : '请识别这张图片中的运动类型。返回纯JSON格式(不要markdown标记),包含以下字段:\n'
            '{"name":"运动名称","calories_per_rep":每次动作消耗热量(kcal,可为小数),"confidence":0到1之间的信心度}\n'
            '例如: {"name":"俯卧撑","calories_per_rep":0.5,"confidence":0.85}';

    // 构造智谱 chat/completions 请求
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': prompt},
              {
                'type': 'image_url',
                'image_url': {'url': imageUrl}
              },
            ],
          },
        ],
        'temperature': 0.1,
        'max_tokens': 400,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('[AiService] API 返回 ${response.statusCode}: ${response.body}');
      throw Exception('智谱 API 返回 ${response.statusCode}');
    }

    // 解析智谱响应
    final respData = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = respData['choices'] as List;
    if (choices.isEmpty) {
      throw Exception('AI 未返回识别结果');
    }

    final content = choices[0]['message']['content'] as String;
    debugPrint('[AiService] AI 返回: $content');

    // 从 AI 回复中提取 JSON
    final json = _extractJson(content);
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;

    if (type == AiRecognitionType.food) {
      final jsonType = json['type'] as String? ?? 'dish';
      // 情况A:营养成分表
      if (jsonType == 'label') {
        final name = json['name'] as String? ?? '未知食品';
        final nut = _normalizeLabelNutrition(json);
        final energy = nut.energy;
        return AiRecognitionResult(
          type: type,
          name: name,
          value: energy, // kcal/100g
          confidence: confidence,
          imagePath: imagePath,
          fromLabel: true,
          labelNutrition: nut,
        );
      }

      // 情况B:菜品/普通食物
      final dishName = json['dish'] as String? ?? json['name'] as String? ?? '未知菜品';
      var ingredients = <FoodIngredient>[];

      final ingredientsList = json['ingredients'] as List? ?? [];
      for (final e in ingredientsList) {
        final ingName = e['name'] as String? ?? '';
        final ratio = (e['ratio'] as num?)?.toDouble() ?? 0;
        if (ingName.isEmpty || ratio <= 0) continue;
        ingredients.add(FoodIngredient(name: ingName, ratio: ratio));
      }

      // 若图片识别未返回食材,调用文本 AI 补充把菜品分解成食材,
      // 避免把整道菜当作单一食材导致营养与红色判断失真
      if (ingredients.isEmpty && dishName != '未知菜品') {
        debugPrint('[AiService] 图片识别未返回食材,调用 AI 补充分解: $dishName');
        final decomposed = await recognizeIngredientsFromDish(dishName);
        if (decomposed != null && decomposed.isNotEmpty) {
          ingredients = decomposed;
        }
      }

      double totalEnergy = 0;
      double matchedRatio = 0;

      for (final ing in ingredients) {
        final ingName = ing.name;
        // 查询本地营养表(内置+自定义)
        var nut = FoodNutritionDB.lookup(ingName);
        if (nut == null) {
          // 本地未匹配,调用 AI 评判该食材每100g营养(仅用于本次计算,不持久化)
          debugPrint('[AiService] 食材未匹配,调用 AI 评判: $ingName');
          nut = await lookupIngredientNutrition(ingName);
          if (nut != null) {
            debugPrint('[AiService] AI 评判食材: $ingName -> ${nut.energy}kcal/100g (不记录)');
          }
        }
        if (nut != null) {
          totalEnergy += nut.energy * ing.ratio;
          matchedRatio += ing.ratio;
        }
      }

      // 如果没匹配到任何食材,用一个合理默认值
      double kcalPer100g;
      if (ingredients.isEmpty || matchedRatio < 0.1) {
        kcalPer100g = 150; // 默认混合菜品
        if (ingredients.isEmpty) {
          ingredients.add(FoodIngredient(name: dishName, ratio: 1));
        }
      } else {
        // 按匹配到的比例归一化(未匹配的食材按平均 150 kcal/100g 补)
        final unmatchedRatio = (1 - matchedRatio).clamp(0, 1);
        totalEnergy += 150 * unmatchedRatio;
        kcalPer100g = totalEnergy;
      }

      // AI 结合餐具估算的食物重量(g),0 表示未估算
      final estimatedWeight =
          (json['estimated_weight'] as num?)?.toDouble() ?? 0;

      return AiRecognitionResult(
        type: type,
        name: dishName,
        value: kcalPer100g,
        confidence: confidence,
        imagePath: imagePath,
        ingredients: ingredients,
        estimatedWeight: estimatedWeight,
      );
    } else {
      // 运动
      final name = json['name'] as String? ?? '未知运动';
      final value = (json['calories_per_rep'] as num?)?.toDouble() ?? 0.5;
      return AiRecognitionResult(
        type: type,
        name: name,
        value: value,
        confidence: confidence,
        imagePath: imagePath,
      );
    }
  }

  /// 将 AI 返回的营养成分表原始数据统一换算为「每100g + kcal」格式
  ///
  /// 表上单位可能是每100g/每100ml/每份,能量单位可能是 kcal/kJ。
  /// 为避免 AI 心算出错,提示词要求 AI 原样上报数值与单位,由本方法确定性换算。
  static FoodNutrition _normalizeLabelNutrition(Map<String, dynamic> json) {
    var energy = (json['energy'] as num?)?.toDouble() ?? 0;
    var protein = (json['protein'] as num?)?.toDouble() ?? 0;
    var fat = (json['fat'] as num?)?.toDouble() ?? 0;
    var carbs = (json['carbs'] as num?)?.toDouble() ?? 0;
    var fiber = (json['fiber'] as num?)?.toDouble() ?? 0;

    // 1) 能量单位 kJ -> kcal(1 kcal = 4.184 kJ)
    final energyUnit =
        (json['energy_unit'] as String?)?.toLowerCase() ?? 'kcal';
    if (energyUnit == 'kj') {
      energy /= 4.184;
    }

    // 2) 基准单位换算到「每100g」:得到把原始数值换算成每100g的倍率
    double scale = 1.0;
    final baseUnit = (json['base_unit'] as String?) ?? '100g';
    switch (baseUnit) {
      case '100ml':
        // 每100ml -> 每100g:按密度(g/ml)换算,液体默认 1.0
        final density = (json['density'] as num?)?.toDouble() ?? 1.0;
        if (density > 0) scale = density;
        break;
      case 'per_serving':
      case '每份':
      case 'per':
      case 'serving':
        // 每份 -> 每100g:每份重量未知时无法换算,按每100g处理
        final servingGrams = (json['serving_size'] as num?)?.toDouble() ?? 0;
        if (servingGrams > 0) {
          scale = 100 / servingGrams;
        } else {
          debugPrint('[AiService] label 为「每份」但缺少 serving_size,按每100g处理');
        }
        break;
      case '100g':
      default:
        scale = 1.0;
    }

    energy *= scale;
    protein *= scale;
    fat *= scale;
    carbs *= scale;
    fiber *= scale;

    return FoodNutrition(
      name: json['name'] as String? ?? '未知食品',
      energy: energy,
      protein: protein,
      fat: fat,
      carbs: carbs,
      fiber: fiber,
    );
  }

  /// 构造食物识别提示词
  static String _buildFoodPrompt() {
    return '请识别这张食物图片。首先判断图片是否为预包装食品的"营养成分表"(通常含表格,列出每100g或每100ml或每份的能量/蛋白质/脂肪/碳水化合物/钠等)。\n'
        '情况A:若图片是营养成分表,返回纯JSON(不要markdown标记),各项数值请按表上原样填写、不要自行换算:\n'
        '{"type":"label","name":"食品名称(从表上或包装上识别)","base_unit":"表上基准单位,只能是 100g / 100ml / per_serving 之一","serving_size":"若 base_unit 为 per_serving,填每份重量(克);否则填0","energy":"能量数值(原样)","energy_unit":"能量单位,只能是 kcal 或 kJ","protein":"蛋白质数值(原样)","fat":"脂肪数值(原样)","carbs":"碳水化合物数值(原样)","fiber":"膳食纤维数值(原样,表上无则填0)","confidence":0到1}\n'
        '注意:1)能量若表上标 kJ,energy 填原始 kJ 数值、energy_unit 填 "kJ",不要除以4.184 2)表上是每100ml 就 base_unit 填 "100ml"、每份填 "per_serving" 并填 serving_size(每份克数),不要换算 3)所有换算由程序完成,你只需如实抄录数值与单位\n'
        '标签示例: {"type":"label","name":"某饼干","base_unit":"100g","serving_size":0,"energy":480,"energy_unit":"kcal","protein":7,"fat":20,"carbs":65,"fiber":2.5,"confidence":0.95}\n'
        '情况B:若图片是菜品或普通食物(非营养成分表),返回纯JSON(不要markdown标记):\n'
        '注意:1)食材名必须使用中文常见名(如:番茄、土豆、猪肉、牛肉、鸡肉、白菜、胡萝卜、鸡蛋、米饭) 2)所有食材占比之和应接近1 3)最多5个主要食材 4)estimated_weight 为本次图片中食物的总重量(g),视觉估算(食物密度约1g/ml,汤汁较多可略高)\n'
        '菜品示例: {"type":"dish","dish":"番茄炒蛋","ingredients":[{"name":"番茄","ratio":0.4},{"name":"鸡蛋","ratio":0.6}],"estimated_weight":200,"confidence":0.9}';
  }

  /// 调用纯文本 AI 接口,查询某个食材每100g的营养成分
  /// 用于食材未匹配时补全自定义营养表(公开方法,页面也可调用)
  /// 无 API Key 或失败时返回 null
  static Future<FoodNutrition?> lookupIngredientNutrition(String name) async {
    if (!hasApiKey) return null;
    try {
      final prompt = '请返回食材"$name"每100克的营养成分。只需返回纯JSON(不要markdown标记):\n'
          '{"name":"$name","energy":每100g能量kcal数值,"protein":蛋白质g数值,"fat":脂肪g数值,"carbs":碳水g数值,"fiber":膳食纤维g数值}\n'
          '注意:所有数值为合理平均值,保留1位小数;若该食材无法明确营养,energy 填 100。';

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _textModel,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 200,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('[AiService] 食材查询 API 返回 ${response.statusCode}');
        return null;
      }
      final respData = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = respData['choices'] as List;
      if (choices.isEmpty) return null;
      final content = choices[0]['message']['content'] as String;
      final json = _extractJson(content);
      return FoodNutrition(
        name: name,
        energy: (json['energy'] as num?)?.toDouble() ?? 100,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      );
    } catch (e) {
      debugPrint('[AiService] 食材营养查询失败: $e');
      return null;
    }
  }

  /// AI 从菜品名识别食材及占比(纯文本输入,无图片)
  /// 用于「手动输入饮食」时,用户输入菜名后自动拆解食材并估算占比
  /// 返回食材列表(含 name + ratio),失败返回 null
  /// 注意:仅返回识别结果,不持久化营养数据(营养数据仍从本地表查询)
  static Future<List<FoodIngredient>?> recognizeIngredientsFromDish(
      String dishName) async {
    if (!hasApiKey) return null;
    try {
      final prompt = '请分析菜品或食物"$dishName"的主要食材及重量占比。\n'
          '返回纯JSON(不要markdown标记):\n'
          '{"dish":"菜品名","ingredients":[{"name":"食材中文常见名","ratio":0到1之间占比}]}\n'
          '注意:\n'
          '1)食材名必须使用中文常见名(如:番茄、土豆、猪肉、牛肉、鸡肉、白菜、胡萝卜、鸡蛋、米饭、面条)\n'
          '2)所有食材占比之和应接近1\n'
          '3)最多5个主要食材,忽略用量极少的调料(如盐、味精)\n'
          '4)若输入本身就是单一食材(如"苹果"),返回单条占比1.0\n'
          '示例: {"dish":"番茄炒蛋","ingredients":[{"name":"番茄","ratio":0.4},{"name":"鸡蛋","ratio":0.6}]}';

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _textModel,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 300,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('[AiService] 菜品食材识别 API 返回 ${response.statusCode}');
        return null;
      }
      final respData = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = respData['choices'] as List;
      if (choices.isEmpty) return null;
      final content = choices[0]['message']['content'] as String;
      debugPrint('[AiService] 菜品食材识别 AI 返回: $content');
      final json = _extractJson(content);
      final list = json['ingredients'] as List? ?? [];
      final result = <FoodIngredient>[];
      for (final e in list) {
        final name = e['name'] as String? ?? '';
        final ratio = (e['ratio'] as num?)?.toDouble() ?? 0;
        if (name.isEmpty || ratio <= 0) continue;
        result.add(FoodIngredient(name: name, ratio: ratio));
      }
      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('[AiService] 菜品食材识别失败: $e');
      return null;
    }
  }

  /// AI 运动卡路里估算结果
  /// name: 解析出的运动名称
  /// count: 解析出的数量
  /// unit: 单位(步/层/次/分钟/公里等)
  /// kcalPerUnit: 每单位消耗 kcal
  /// totalKcal: 总消耗 kcal
  static Future<({String name, int count, String unit, double kcalPerUnit, double totalKcal})?>
      estimateExerciseCalories({
    required String exerciseName,
    required int gender,
    required int age,
    required int height,
    required int weight,
  }) async {
    if (!hasApiKey) return null;
    try {
      final genderStr = gender == 0 ? '男' : gender == 1 ? '女' : '未指定';
      final prompt = '请估算一位用户的运动消耗。用户信息:性别=$genderStr,年龄=$age 岁,身高=$height cm,体重=$weight kg。\n'
          '用户输入的运动内容:"$exerciseName"\n\n'
          '请解析运动名称和数量(若输入中包含数字和单位则提取,若不包含则默认数量为1),并计算总消耗热量。\n\n'
          '参考热量消耗(以65kg成年人为例,请根据用户实际体重按比例调整):\n'
          '- 散步/慢走:约0.04 kcal/步,或约3-4 kcal/分钟\n'
          '- 快走:约0.06 kcal/步,或约5-6 kcal/分钟\n'
          '- 慢跑/跑步:约0.08 kcal/步,或约8-12 kcal/分钟\n'
          '- 爬楼梯/爬楼:约0.3 kcal/步(一层约15-20步),或约7-10 kcal/分钟,或约4-6 kcal/层\n'
          '- 骑自行车:约7-10 kcal/分钟\n'
          '- 游泳:约8-12 kcal/分钟\n'
          '- 跳绳:约10-13 kcal/分钟\n'
          '- 瑜伽:约3-5 kcal/分钟\n'
          '- 俯卧撑:约0.5 kcal/次\n'
          '- 深蹲:约0.4 kcal/次\n'
          '- 仰卧起坐:约0.3 kcal/次\n'
          '- 引体向上:约1 kcal/次\n'
          '- 羽毛球/乒乓球:约5-7 kcal/分钟\n'
          '- 篮球:约8-10 kcal/分钟\n\n'
          '返回纯JSON(不要markdown标记):\n'
          '{"name":"解析出的运动名称","count":数量整数,"unit":"单位(步/层/次/分钟/公里等)","kcal_per_unit":每单位消耗kcal数值,"total_kcal":总消耗kcal数值}\n\n'
          '示例:\n'
          '输入"散步10000步" → {"name":"散步","count":10000,"unit":"步","kcal_per_unit":0.04,"total_kcal":400}\n'
          '输入"爬楼30层" → {"name":"爬楼","count":30,"unit":"层","kcal_per_unit":5,"total_kcal":150}\n'
          '输入"俯卧撑50个" → {"name":"俯卧撑","count":50,"unit":"次","kcal_per_unit":0.5,"total_kcal":25}\n'
          '输入"跑步30分钟" → {"name":"跑步","count":30,"unit":"分钟","kcal_per_unit":10,"total_kcal":300}\n'
          '输入"爬楼" → {"name":"爬楼","count":1,"unit":"层","kcal_per_unit":5,"total_kcal":5}';

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _textModel,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.1,
          'max_tokens': 300,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('[AiService] 运动估算 API 返回 ${response.statusCode}');
        return null;
      }
      final respData = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = respData['choices'] as List;
      if (choices.isEmpty) return null;
      final content = choices[0]['message']['content'] as String;
      debugPrint('[AiService] 运动估算 AI 返回: $content');
      final json = _extractJson(content);
      final name = json['name'] as String? ?? exerciseName;
      final count = (json['count'] as num?)?.toInt() ?? 1;
      final unit = json['unit'] as String? ?? '次';
      final kcalPerUnit = (json['kcal_per_unit'] as num?)?.toDouble() ?? 0;
      final totalKcal = (json['total_kcal'] as num?)?.toDouble() ??
          (kcalPerUnit * count);
      return (
        name: name,
        count: count,
        unit: unit,
        kcalPerUnit: kcalPerUnit,
        totalKcal: totalKcal,
      );
    } catch (e) {
      debugPrint('[AiService] 运动卡路里估算失败: $e');
      return null;
    }
  }

  /// 从 AI 回复文本中提取 JSON 对象
  /// 处理 AI 可能返回 markdown 代码块包裹的情况
  static Map<String, dynamic> _extractJson(String text) {
    // 尝试直接解析
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {}

    // 尝试提取 ```json ... ``` 中的内容
    final regex = RegExp(r'\{[\s\S]*\}', dotAll: true);
    final match = regex.firstMatch(text);
    if (match != null) {
      try {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      } catch (_) {}
    }

    debugPrint('[AiService] 无法解析 JSON: $text');
    return {'name': '未知', 'confidence': 0.3};
  }

  /// Mock 识别数据 - 用于无 API Key 时的演示
  static Future<AiRecognitionResult> _mockRecognize(
      AiRecognitionType type, String imagePath) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (type == AiRecognitionType.food) {
      return AiRecognitionResult(
        type: AiRecognitionType.food,
        name: '番茄炒蛋',
        value: 110, // 加权平均后约 110 kcal/100g
        confidence: 0.85,
        imagePath: imagePath,
        ingredients: [
          const FoodIngredient(name: '番茄', ratio: 0.4),
          const FoodIngredient(name: '鸡蛋', ratio: 0.6),
        ],
      );
    } else {
      return AiRecognitionResult(
        type: AiRecognitionType.exercise,
        name: '俯卧撑',
        value: 0.5,
        confidence: 0.78,
        imagePath: imagePath,
      );
    }
  }

  // ========== 饮食分析与建议 ==========

  /// AI 从体测报告/体脂秤图片识别身体数据
  /// 读取图片中的身高、体重、肌肉量等信息
  /// 返回 ({double? height, double? weight, double? muscle}),失败返回 null
  static Future<({double? height, double? weight, double? muscle})?>
      recognizeBodyMetrics(String imagePath) async {
    if (!hasApiKey) return null;
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      final imageUrl = 'data:image/jpeg;base64,$base64Image';

      const prompt = '请识别这张图片中的身体数据(体测报告/体脂秤屏幕/健康报告等)。'
          '返回纯JSON格式(不要markdown标记):\n'
          '{"height":身高cm数值,"weight":体重kg数值,"muscle":肌肉量kg数值}\n'
          '注意:所有数值为纯数字(可为小数);若图片中某项数据无法识别,该项填0。';

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': imageUrl}
                },
              ],
            },
          ],
          'temperature': 0.1,
          'max_tokens': 200,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('[AiService] 体测识别 API 返回 ${response.statusCode}');
        return null;
      }
      final respData = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = respData['choices'] as List;
      if (choices.isEmpty) return null;
      final content = choices[0]['message']['content'] as String;
      final json = _extractJson(content);
      final height = (json['height'] as num?)?.toDouble();
      final weight = (json['weight'] as num?)?.toDouble();
      final muscle = (json['muscle'] as num?)?.toDouble();
      return (
        height: height != null && height > 0 ? height : null,
        weight: weight != null && weight > 0 ? weight : null,
        muscle: muscle != null && muscle > 0 ? muscle : null,
      );
    } catch (e) {
      debugPrint('[AiService] 体测识别失败: $e');
      return null;
    }
  }

  /// AI 饮食分析:根据用户近期饮食记录 + 目标,生成个性化建议
  /// [recentSummaries] 最近 N 天的每日饮食摘要
  /// [todayFoodNames] 今天已吃的食物名称列表(供 AI 参考当前饮食)
  /// [goal] 用户目标(增肌/减脂/保持)
  /// [profile] 用户资料(性别/年龄/身高/体重/BMR)
  /// 返回 DietAdvice,失败返回 null
  static Future<DietAdvice?> analyzeDietAndAdvise({
    required List<DailyDietSummary> recentSummaries,
    required DailyDietSummary todaySummary,
    required UserGoal goal,
    required UserProfile profile,
  }) async {
    if (!hasApiKey) {
      return _mockDietAdvice(recentSummaries, goal, profile);
    }
    try {
      final goalStr = switch (goal) {
        UserGoal.loseFat => '减脂(降低体脂率,需热量缺口)',
        UserGoal.gainMuscle => '增肌(增加肌肉量,需热量盈余+高蛋白)',
        UserGoal.maintain => '保持身材(维持当前体重和体型)',
      };
      final genderStr = switch (profile.gender) {
        Gender.male => '男',
        Gender.female => '女',
        Gender.unspecified => '未指定',
      };
      final bmr = profile.bmr;

      // 构造近期饮食摘要描述(含运动消耗)
      final recentDesc = recentSummaries.isEmpty
          ? '暂无历史饮食记录(可能是首次分析)'
          : recentSummaries.map((s) {
              return '${s.date.month}-${s.date.day}: 摄入${s.calories}kcal, 运动${s.exerciseCalories}kcal, 蛋白${s.protein.toStringAsFixed(1)}g, 脂肪${s.fat.toStringAsFixed(1)}g, 碳水${s.carbs.toStringAsFixed(1)}g, 纤维${s.fiber.toStringAsFixed(1)}g, 食物[${s.foodNames.join('/')}]';
            }).join('\n');

      // 构造今日实时描述(含完整营养数据 + 运动消耗)
      final todayDesc = todaySummary.calories == 0 && todaySummary.exerciseCalories == 0
          ? '今日暂无饮食和运动记录'
          : '今日实时: 摄入${todaySummary.calories}kcal, 运动${todaySummary.exerciseCalories}kcal, '
              '蛋白${todaySummary.protein.toStringAsFixed(1)}g, 脂肪${todaySummary.fat.toStringAsFixed(1)}g, '
              '碳水${todaySummary.carbs.toStringAsFixed(1)}g, 纤维${todaySummary.fiber.toStringAsFixed(1)}g, '
              '已吃[${todaySummary.foodNames.join('/')}]';

      // 构造建议摄入量参考(基于公式计算,供 AI 参考)
      final baseCal = bmr == null
          ? null
          : switch (goal) {
              UserGoal.loseFat => (bmr * 0.8).round(),
              UserGoal.gainMuscle => (bmr * 1.1).round(),
              UserGoal.maintain => bmr,
            };
      final baseProtein = profile.weight <= 0
          ? null
          : switch (goal) {
              UserGoal.loseFat => profile.weight * 1.5,
              UserGoal.gainMuscle => profile.weight * 2.0,
              UserGoal.maintain => profile.weight * 1.2,
            };
      final baseFat = profile.weight <= 0
          ? null
          : switch (goal) {
              UserGoal.loseFat => profile.weight * 0.6,
              UserGoal.gainMuscle => profile.weight * 0.8,
              UserGoal.maintain => profile.weight * 0.7,
            };
      final baseCarbs = profile.weight <= 0
          ? null
          : switch (goal) {
              UserGoal.loseFat => profile.weight * 2.0,
              UserGoal.gainMuscle => profile.weight * 4.0,
              UserGoal.maintain => profile.weight * 3.0,
            };

      final prompt = '请作为专业营养师,根据用户的近期饮食记录和目标,给出个性化饮食建议。\n\n'
          '【用户信息】\n'
          '性别: $genderStr\n'
          '年龄: ${profile.age} 岁\n'
          '身高: ${profile.height} cm\n'
          '体重: ${profile.weight} kg\n'
          '目标体重: ${profile.targetWeight > 0 ? "${profile.targetWeight} kg" : "未设置"}\n'
          '肌肉量: ${profile.muscle} kg\n'
          '基础代谢(BMR): ${bmr ?? "未知"} kcal\n'
          '目标: $goalStr\n\n'
          '【近三天饮食与运动记录】\n$recentDesc\n\n'
          '【今日饮食与运动】\n$todayDesc\n\n'
          '【参考建议摄入量(基于公式)】\n'
          '热量: ${baseCal ?? "未知"} kcal/天\n'
          '蛋白质: ${baseProtein?.toStringAsFixed(1) ?? "未知"} g/天\n'
          '脂肪: ${baseFat?.toStringAsFixed(1) ?? "未知"} g/天\n'
          '碳水: ${baseCarbs?.toStringAsFixed(1) ?? "未知"} g/天\n'
          '膳食纤维: 25 g/天\n\n'
          '请根据以上信息分析用户当前饮食结构,给出:\n'
          '1. 建议多吃的食物种类(2-5条,具体食物名,如"鸡胸肉""燕麦""西蓝花")\n'
          '2. 建议少吃的食物种类(2-5条,从用户近期饮食中找出需要减少的)\n'
          '3. 建议摄入量(根据用户目标、目标体重和当前情况微调参考值)\n'
          '4. 简短总结(50字以内)\n\n'
          '返回纯JSON(不要markdown标记):\n'
          '{"eat_more":["食物1","食物2"],"eat_less":["食物1","食物2"],"suggested_calories":数值,"suggested_protein":数值,"suggested_fat":数值,"suggested_carbs":数值,"suggested_fiber":数值,"summary":"总结"}\n\n'
          '注意:\n'
          '- 减脂目标:热量缺口约20%,高蛋白保肌肉,控碳水控脂肪\n'
          '- 增肌目标:热量盈余约10%,高蛋白高碳水\n'
          '- 保持目标:维持当前摄入量\n'
          '- 若设置了目标体重,需考虑当前体重与目标体重的差距,合理安排减重/增重速度\n'
          '- 结合近三天饮食和运动数据判断用户实际执行情况,动态调整建议\n'
          '- 所有数值为合理整数或保留1位小数\n'
          '- 若用户饮食记录不足,基于目标和体重给出标准建议\n'
          '- 重要:建议热量(suggested_calories)不得低于最低安全值,男性不低于1500kcal,女性不低于1200kcal';

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _textModel,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 600,
        }),
      );
      if (response.statusCode != 200) {
        debugPrint('[AiService] 饮食分析 API 返回 ${response.statusCode}: ${response.body}');
        return null;
      }
      final respData = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = respData['choices'] as List;
      if (choices.isEmpty) return null;
      final content = choices[0]['message']['content'] as String;
      debugPrint('[AiService] 饮食分析 AI 返回: $content');
      final json = _extractJson(content);

      final now = DateTime.now();
      return DietAdvice(
        createdAt: now,
        goal: goal,
        eatMore: (json['eat_more'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        eatLess: (json['eat_less'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        summary: (json['summary'] as String?) ?? '已生成个性化饮食建议',
        suggestedCalories:
            (json['suggested_calories'] as num?)?.toInt() ?? (baseCal ?? 1800),
        suggestedProtein:
            (json['suggested_protein'] as num?)?.toDouble() ??
                (baseProtein ?? 60.0),
        suggestedFat:
            (json['suggested_fat'] as num?)?.toDouble() ?? (baseFat ?? 50.0),
        suggestedCarbs:
            (json['suggested_carbs'] as num?)?.toDouble() ??
                (baseCarbs ?? 200.0),
        suggestedFiber:
            (json['suggested_fiber'] as num?)?.toDouble() ?? 25.0,
        validUntil: now.add(const Duration(days: 3)),
      );
    } catch (e) {
      debugPrint('[AiService] 饮食分析失败: $e');
      return null;
    }
  }

  /// Mock 饮食建议 - 用于无 API Key 时的演示
  static Future<DietAdvice> _mockDietAdvice(
    List<DailyDietSummary> recentSummaries,
    UserGoal goal,
    UserProfile profile,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final now = DateTime.now();
    final bmr = profile.bmr;
    final baseCal = bmr == null
        ? 1800
        : switch (goal) {
            UserGoal.loseFat => (bmr * 0.8).round(),
            UserGoal.gainMuscle => (bmr * 1.1).round(),
            UserGoal.maintain => bmr,
          };
    final baseProtein = profile.weight <= 0
        ? 60.0
        : switch (goal) {
            UserGoal.loseFat => profile.weight * 1.5,
            UserGoal.gainMuscle => profile.weight * 2.0,
            UserGoal.maintain => profile.weight * 1.2,
          };
    final baseFat = profile.weight <= 0
        ? 50.0
        : switch (goal) {
            UserGoal.loseFat => profile.weight * 0.6,
            UserGoal.gainMuscle => profile.weight * 0.8,
            UserGoal.maintain => profile.weight * 0.7,
          };
    final baseCarbs = profile.weight <= 0
        ? 200.0
        : switch (goal) {
            UserGoal.loseFat => profile.weight * 2.0,
            UserGoal.gainMuscle => profile.weight * 4.0,
            UserGoal.maintain => profile.weight * 3.0,
          };

    final eatMore = switch (goal) {
      UserGoal.loseFat => ['鸡胸肉', '西蓝花', '番茄', '鸡蛋'],
      UserGoal.gainMuscle => ['牛肉', '鸡蛋', '牛奶', '燕麦'],
      UserGoal.maintain => ['蔬菜', '水果', '全谷物'],
    };
    final eatLess = switch (goal) {
      UserGoal.loseFat => ['油炸食品', '甜饮料', '白米饭'],
      UserGoal.gainMuscle => ['含糖零食', '油炸食品'],
      UserGoal.maintain => ['油炸食品', '高糖饮料'],
    };
    final summary = switch (goal) {
      UserGoal.loseFat => '减脂期建议高蛋白低脂饮食,控制总热量摄入',
      UserGoal.gainMuscle => '增肌期建议高蛋白高碳水饮食,保证热量盈余',
      UserGoal.maintain => '保持期建议均衡饮食,维持当前摄入量',
    };

    return DietAdvice(
      createdAt: now,
      goal: goal,
      eatMore: eatMore,
      eatLess: eatLess,
      summary: summary,
      suggestedCalories: baseCal,
      suggestedProtein: baseProtein,
      suggestedFat: baseFat,
      suggestedCarbs: baseCarbs,
      suggestedFiber: 25.0,
      validUntil: now.add(const Duration(days: 3)),
    );
  }
}
