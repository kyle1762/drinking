# drinking

本项目代码仓

一个 Flutter 喝水提醒应用，采用奶油治愈风设计。

## Getting Started

This project is a starting point for a Flutter application.

## 功能特性

- **提醒设置**: 循环定时提醒、通知权限管理、音效选择、飞书推送
- **喝水统计**: 今日/本周/本月图表展示、徽章系统、简易版/专业版快速打卡
- **账号管理**: 游客/登录/飞书绑定三态、用户资料管理
- **数据持久化**: 基于 SharedPreferences 的本地存储

## 技术栈

- Flutter 3.44.4
- Dart 3.12
- Provider (状态管理)
- flutter_local_notifications (通知)
- android_alarm_manager_plus (闹钟)
- audioplayers (音效)
- shared_preferences (持久化)

## 运行方式

```bash
flutter pub get
flutter run
```

## 打包方式

```bash
flutter build apk --release
```