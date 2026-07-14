import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import 'storage_service.dart';

/// AI 识别服务
/// - 对接智谱 GLM-4V-Flash(免费图片理解模型)
/// - 负责调用 AI 接口识别食物/运动图片
/// - 管理 API Key 的读写
class AiService {
  AiService._();

  // ========== 智谱 API 配置 ==========

  /// 智谱 API Endpoint
  static const _endpoint =
      'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  /// 图片理解模型(免费)
  static const _model = 'glm-4v-flash';

  // ========== API Key 管理 ==========

  /// 获取已保存的 API Key
  static String get apiKey {
    final d = StorageService.loadAll();
    return d.aiApiKey;
  }

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
  static Future<AiRecognitionResult> _callAiApi({
    required AiRecognitionType type,
    required String imagePath,
  }) async {
    final key = apiKey;

    // 读取图片并转 base64
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);
    final imageUrl = 'data:image/jpeg;base64,$base64Image';

    // 构造提示词:要求 AI 返回 JSON 格式的识别结果
    final prompt = type == AiRecognitionType.food
        ? '请识别这张图片中的食物。返回纯JSON格式(不要markdown标记),包含以下字段:\n'
            '{"name":"食物名称","calories_per_100g":每100克热量(kcal整数),"confidence":0到1之间的信心度}\n'
            '例如: {"name":"苹果","calories_per_100g":52,"confidence":0.9}'
        : '请识别这张图片中的运动类型。返回纯JSON格式(不要markdown标记),包含以下字段:\n'
            '{"name":"运动名称","calories_per_minute":每分钟消耗热量(kcal整数),"confidence":0到1之间的信心度}\n'
            '例如: {"name":"跑步","calories_per_minute":10,"confidence":0.85}';

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
              {'type': 'image_url', 'image_url': {'url': imageUrl}},
            ],
          },
        ],
        'temperature': 0.1,
        'max_tokens': 200,
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

    final name = json['name'] as String? ?? '未知';
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;
    final value = type == AiRecognitionType.food
        ? (json['calories_per_100g'] as num?)?.toDouble() ?? 100
        : (json['calories_per_minute'] as num?)?.toDouble() ?? 8;

    return AiRecognitionResult(
      type: type,
      name: name,
      value: value,
      confidence: confidence,
      imagePath: imagePath,
    );
  }

  /// 从 AI 回复文本中提取 JSON 对象
  /// 处理 AI 可能返回 markdown 代码块包裹的情况
  static Map<String, dynamic> _extractJson(String text) {
    // 尝试直接解析
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {}

    // 尝试提取 ```json ... ``` 中的内容
    final regex = RegExp(r'\{[^}]+\}', dotAll: true);
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
        name: '苹果',
        value: 52, // 52 kcal / 100g
        confidence: 0.85,
        imagePath: imagePath,
      );
    } else {
      return AiRecognitionResult(
        type: AiRecognitionType.exercise,
        name: '跑步',
        value: 10, // 10 kcal / 分钟
        confidence: 0.78,
        imagePath: imagePath,
      );
    }
  }
}
