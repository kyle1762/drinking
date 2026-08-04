# 喝水小精灵 (drinking)

一个治愈奶油风的 Flutter 喝水提醒 + AI 饮食/运动热量追踪 App。

## 功能特性

三 Tab 结构(热量追踪 / 喝水提醒 / ai&飞书):

- **热量追踪**:拍照识别菜品并拆食材营养、营养成分表(label)直读、运动识别/手动记录、热量表盘(摄入 vs 消耗)、营养素建议(增肌/减脂/保持)、6 种减肥方法选择、体测报告识别(身高/体重/肌肉量)、周记录、营养库 JSON/CSV 导出
- **喝水提醒**:循环闹钟(绝对时间 + 自续重注册)、单次提醒、夜间/午休免打扰、日历批量事件 + 系统闹钟、通知横幅、今日打卡与记录
- **ai&飞书**:智谱 AI API Key 配置、飞书机器人 OAuth/手机号登录、提醒推送、测试推送、个人资料(目标体重/作息)

## 技术栈

- Flutter 3.44.4 / Dart 3.12
- Provider(状态管理)、shared_preferences(本地持久化)
- flutter_local_notifications + android_alarm_manager_plus(提醒/闹钟)
- device_calendar + android_intent_plus(日历/系统闹钟)
- 智谱 GLM-4V-Flash / GLM-4-Flash(图片识别 + 营养/卡路里估算)
- 飞书 OpenAPI(OAuth 授权 + 消息推送)

## 代码结构

```
lib/
├─ main.dart                 入口:初始化存储→通知→闹钟→AppState
├─ state/app_state.dart      全局状态源(Provider)
├─ models/models.dart        数据模型 + BMI/BMR 计算 + JSON 序列化
├─ data/                     food_nutrition.dart(内置营养表+自定义表) / diet_methods.dart(减肥方法预设)
├─ services/                 ai_service / alarm_service / notification_service /
│                             feishu_service / calendar_alarm_service / audio_service / storage_service
├─ pages/                    home(三Tab) / ai(卡片/Sheet/记录流拆分为 cards.dart、sheets.dart、records.dart)
│                             reminder / account / stats(被 reminder 复用的组件)
├─ widgets/  dialogs.dart  theme/
test/                        models_test.dart(核心计算与序列化单测)
tools/                       开发辅助脚本与数据源(gen_dart.py、营养 xlsx、上传/内网穿透工具等)
```

## 运行方式

```bash
flutter pub get
flutter run
```

## 测试与打包

```bash
flutter analyze        # 静态检查
flutter test           # 运行单元测试
flutter build apk --release
```
