import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import 'storage_service.dart';

/// AI 识别服务
/// - 负责调用 AI 接口识别食物/运动图片
/// - 管理 API Key 的读写
/// - 对接真实 API 时,只需修改 _callAiApi 方法内部的 Endpoint 和请求格式
class AiService {
  AiService._();

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

  // ====================================================================
  //  TODO: 对接真实 AI API
  //  请在此方法内填入你的 AI 接口 Endpoint 和请求格式
  //  请求参数: type(食物/运动) + imagePath(本地图片路径)
  //  返回值: AiRecognitionResult(name, value, confidence)
  // ====================================================================
  static Future<AiRecognitionResult> _callAiApi({
    required AiRecognitionType type,
    required String imagePath,
  }) async {
    // ====== 在这里填入你的 API Endpoint ======
    const endpoint = ''; // 例如: 'https://your-api.example.com/recognize'
    // =========================================

    if (endpoint.isEmpty) {
      // 未配置 Endpoint,回退到 Mock
      return _mockRecognize(type, imagePath);
    }

    final key = apiKey;
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'type': type.name,
        'image': base64Image,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return AiRecognitionResult(
        type: type,
        name: data['name'] as String,
        value: (data['value'] as num).toDouble(),
        confidence: (data['confidence'] as num).toDouble(),
        imagePath: imagePath,
      );
    } else {
      throw Exception('AI 接口返回 ${response.statusCode}');
    }
  }

  /// Mock 识别数据 - 用于无 API Key 或无网络时的演示
  static Future<AiRecognitionResult> _mockRecognize(
      AiRecognitionType type, String imagePath) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (type == AiRecognitionType.food) {
      return const AiRecognitionResult(
        type: AiRecognitionType.food,
        name: '苹果',
        value: 52, // 52 kcal / 100g
        confidence: 0.85,
      );
    } else {
      return const AiRecognitionResult(
        type: AiRecognitionType.exercise,
        name: '跑步',
        value: 10, // 10 kcal / 分钟
        confidence: 0.78,
      );
    }
  }
}
