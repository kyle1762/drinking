import 'package:flutter/material.dart';

/// 奶油治愈风配色常量
/// 低饱和、大圆角、无强警示色
class AppColors {
  AppColors._();

  /// 奶油白 - 主背景
  static const Color cream = Color(0xFFFCF9F4);

  /// 主浅蓝 - 主题色/提醒态
  static const Color softBlue = Color(0xFFC7E6F2);

  /// 浅蓝深一档 - 选中态/进度
  static const Color softBlueDeep = Color(0xFF9DD4E8);

  /// 薄荷绿 - 完成/统计态
  static const Color mint = Color(0xFFD6F2E4);

  /// 薄荷深一档 - 强调完成
  static const Color mintDeep = Color(0xFFA8E0C6);

  /// 文字柔灰 - 主文字
  static const Color textPrimary = Color(0xFF5A5A68);

  /// 文字浅灰 - 副文字
  static const Color textSecondary = Color(0xFF9A9AA8);

  /// 文字极浅 - 占位/禁用
  static const Color textDisabled = Color(0xFFC4C4CC);

  /// 卡片底色 - 略带暖意
  static const Color card = Color(0xFFFFFFFF);

  /// 卡片阴影色
  static const Color shadow = Color(0x14000000);

  /// 分隔线
  static const Color divider = Color(0xFFF0EDE6);

  /// 浅提示条底色 - 通知未开启/无耳机
  static const Color banner = Color(0xFFFFF6E0);

  /// 暂停态浅灰
  static const Color paused = Color(0xFFE8E6E0);

  /// 水滴蓝 - 打卡按钮
  static const Color waterDrop = Color(0xFF8FD0E8);

  /// 雨滴/进度填充
  static const Color rain = Color(0xFFB8E0F0);

  /// 飞书品牌浅色
  static const Color feishu = Color(0xFFD6E4FF);
}
