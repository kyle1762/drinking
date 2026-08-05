# 喝水小精灵 (drinking)

一个治愈奶油风的 Flutter 喝水记录 + 动一动提醒 + AI 饮食/运动热量追踪 App。

## 功能特性

三 Tab 结构(热量追踪 / 动一动 / ai&飞书):

- **热量追踪**:拍照识别菜品并拆食材营养、营养成分表(label)直读、运动识别/手动记录、热量表盘(摄入 vs 消耗)、营养素建议(增肌/减脂/保持)、6 种减肥方法选择、体测报告识别(身高/体重/肌肉量)、周记录、营养库 JSON/CSV 导出
- **动一动**:循环闹钟(绝对时间 + 自续重注册)、单次提醒、夜间/午休免打扰(期间完全不提醒不弹通知)、静默通知(无音效)、日历批量事件 + 系统闹钟、今日打卡与饮水记录
- **ai&飞书**:智谱 AI API Key 配置、飞书机器人 OAuth/手机号登录、提醒推送、测试推送、个人资料(目标体重/作息)

## 技术栈

- Flutter 3.44.4 / Dart 3.12
- Provider(状态管理)、shared_preferences(本地持久化)
- flutter_local_notifications + android_alarm_manager_plus(提醒/闹钟)
- device_calendar + android_intent_plus(日历/系统闹钟)
- 智谱 GLM-4V-Flash / GLM-4-Flash(图片识别 + 营养/卡路里估算)
- 飞书 OpenAPI(OAuth 授权 + 消息推送)

## 手机端数据存储位置

所有永久数据(设置、记录、AI 识别结果、自定义营养表等)通过 `shared_preferences` 持久化到应用私有目录的 SharedPreferences XML:

- 路径:`/data/data/com.drinking.drinking/shared_prefs/FlutterSharedPreferences.xml`
- 应用内键统一带 `flutter.` 前缀(如 `flutter.kForbiddenWarningText`)
- 属于应用私有目录,非 root 手机无法直接查看;可用 adb 导出:

```bash
adb exec-out run-as com.drinking.drinking cat /data/data/com.drinking.drinking/shared_prefs/FlutterSharedPreferences.xml
```

- 卸载应用或清除数据会删除全部数据;应用升级不会清掉

### 导出全部数据

「AI & 飞书」页面底部「数据备份」卡片可将全部数据(账号、记录、营养表等)导出为 JSON 文件:

- 文件保存到手机公共下载目录 `Download/drinking_export_YYYY-MM-DD.json`(Android 10+ 走 MediaStore,无需权限)
- Android 9 及以下需要存储权限(manifest 已声明,首次导出时系统会询问)
- 也可用 adb 直接导出存储文件(见上文)

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
