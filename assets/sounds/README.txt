# 此目录存放提醒音效文件
# 已包含 4 个 WAV 音效(16-bit PCM / 44.1kHz / mono / 3秒):
#   flow.wav  - 流水声(粉红噪声 + 低通滤波 + 振幅调制)
#   wind.wav  - 风铃声(多频正弦波 + 指数衰减)
#   rain.wav  - 雨滴声(背景雨幕 + 随机水滴)
#   piano.wav - 轻钢琴(C-E-G 和弦 + ADSR 包络)
#
# 文件名与 lib/models/models.dart 中 SoundType 枚举一致,
# AudioService 会自动播放。
#
# 如需重新生成,运行:
#   python tools/gen_sounds.py
