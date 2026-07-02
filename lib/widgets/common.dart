import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 安卓原生水波纹点击反馈按钮
class RippleButton extends StatelessWidget {
  const RippleButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.disabled = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: AppColors.softBlue.withAlpha(80),
        highlightColor: AppColors.softBlue.withAlpha(40),
        child: Padding(
          padding: padding,
          child: Opacity(opacity: disabled ? 0.4 : 1, child: child),
        ),
      ),
    );
  }
}

/// 奶油风卡片容器 - 大圆角、柔和阴影
class CreamCard extends StatelessWidget {
  const CreamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = AppThemeRadius.l,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      elevation: 0,
      shadowColor: AppColors.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: AppColors.softBlue.withAlpha(50),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 常驻浅色提示条 - 通知未开启/无耳机/游客模式
class SoftBanner extends StatelessWidget {
  const SoftBanner({
    super.key,
    required this.icon,
    required this.text,
    this.actionText,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.banner,
        borderRadius: BorderRadius.circular(AppThemeRadius.m),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12.5, height: 1.3)),
          ),
          if (actionText != null)
            RippleButton(
              onTap: onAction,
              borderRadius: 10,
              child: Text(actionText!, style: const TextStyle(
                  color: AppColors.softBlueDeep, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// 章节小标题
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Row(
        children: [
          Text(text, style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// 状态标签
class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.text, required this.active});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.softBlue : AppColors.paused,
        borderRadius: BorderRadius.circular(AppThemeRadius.s),
      ),
      child: Text(text, style: TextStyle(
        color: active ? AppColors.softBlueDeep : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      )),
    );
  }
}

class AppThemeRadius {
  AppThemeRadius._();
  static const double l = 24;
  static const double m = 16;
  static const double s = 12;
}
