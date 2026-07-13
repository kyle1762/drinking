import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/models.dart';

/// 音效服务 - 基于 audioplayers
/// 播放 assets/sounds/ 下的治愈音效(流水/风铃/雨滴/钢琴,均为 WAV 格式)
/// 配置了混合模式(AudioContext),允许在后台与其他应用音频共存
/// 支持前台和后台闹钟 isolate 调用
class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _initialized = false;

  /// 混合模式 AudioContext
  /// Android: usageType=notification + audioFocus=gainTransientMayDuck(降低其他应用音量而非暂停)
  /// iOS: category=ambient(静音模式尊重 + 自动与其他应用混播)
  static AudioContext _buildMixContext() {
    return AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.notification,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
    );
  }

  /// 初始化音频播放器,配置混合模式 AudioContext
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await AudioPlayer.global.setAudioContext(_buildMixContext());
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('AudioContext 配置失败,使用默认配置: $e');
    }
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
      // 音效资源缺失时静默降级
      debugPrint('播放音效失败,请确认 assets/sounds/${sound.file} 已放入: $e');
    }
  }

  /// 后台闹钟触发时播放音效 - 在后台 isolate 中创建独立播放器
  /// 配置混合模式,等待播放完成后再释放,避免后台 isolate 提前结束截断音频
  static Future<void> playFromBackground(SoundType sound,
      {double volume = 0.6}) async {
    try {
      final player = AudioPlayer();
      await player.setAudioContext(_buildMixContext());
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.play(AssetSource('sounds/${sound.file}'));
      // 等待播放完成(最多 8 秒)再释放
      await Future.delayed(const Duration(seconds: 8));
      await player.dispose();
    } catch (e) {
      debugPrint('后台播放音效失败: $e');
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
