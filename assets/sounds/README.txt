# 此目录存放提醒音效文件
# 已包含 4 个 WAV 音效(16-bit PCM / 44.1kHz / mono / 3秒):
#   flow.wav        - 流水声(粉红噪声 + 低通滤波 + 振幅调制)
#   wind_chime.wav  - 风铃声(当前为旧 wind.wav 的占位符,请替换为更清脆悦耳的风铃 mp3/wav)
#   rain.wav        - 雨滴声(背景雨幕 + 随机水滴)
#   piano.wav       - 轻钢琴(C-E-G 和弦 + ADSR 包络)
#
# 风铃音效替换:将新的风铃音频文件命名为 wind_chime.wav 放入本目录即可覆盖。
# 支持 WAV 或 MP3 格式。建议使用清脆的金属风铃录音,时长 2~5 秒。
#
# 文件名与 lib/models/models.dart 中 SoundType 枚举一致,
# AudioService 会自动播放。
