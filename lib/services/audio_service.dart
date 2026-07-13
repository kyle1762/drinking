import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/models.dart';

/// 音效服务 - 基于 audioplayers
/// 播放 assets/sounds/ 下的治愈音效(流水/风铃/雨滴/钢琴,均为 WAV 格式)
/// 需要在 pubspec.yaml 中声明 assets 资源,WAV 文件已放入 assets/sounds/
class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    _initialized = true;
  }

  /// 播放指定音效
  /// [volume] 0.0~1.0
  static Future<void> playSound(SoundType sound, {double volume = 0.6}) async {
    if (!_initialized) await init();
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
      await _player.play(AssetSource('sounds/${sound.file}'));
    } catch (e) {
      // 音效资源缺失时静默降级(assets/sounds/ 下可能还没有 mp3 文件)
      debugPrint('播放音效失败,请确认 assets/sounds/${sound.file} 已放入: $e');
    }
  }

  /// 停止播放
  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// 释放资源
  static Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
