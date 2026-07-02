import 'package:flutter/material.dart';
import 'theme/app_colors.dart';
import 'widgets/common.dart';

/// 安卓居中弹窗/时间选择器统一工具
class AppDialogs {
  AppDialogs._();

  /// 安卓原生时间选择器
  static Future<DateTime?> pickTime(BuildContext context, {String? initial}) {
    TimeOfDay? initialTime;
    if (initial != null) {
      final parts = initial.split(':');
      if (parts.length == 2) {
        initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    initialTime ??= TimeOfDay.now();
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.softBlueDeep,
                surface: AppColors.cream,
              ),
        ),
        child: child!,
      ),
    ).then((t) => t == null
        ? null
        : DateTime.now().copyWith(hour: t.hour, minute: t.minute, second: 0));
  }

  /// 二次确认弹窗
  static Future<void> confirm(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
    String confirmText = '确认',
    String cancelText = '取消',
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppThemeRadius.m)),
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(content, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(cancelText)),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(confirmText, style: const TextStyle(color: AppColors.softBlueDeep, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// 居中弹窗(自定义actions)
  static Future<void> centerDialog(
    BuildContext context, {
    required String title,
    required String content,
    required List<DialogAction> actions,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppThemeRadius.m)),
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(content, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
        actions: actions
            .map((a) => TextButton(
                  onPressed: a.onTap,
                  child: Text(a.label,
                      style: TextStyle(
                        color: a.primary ? AppColors.softBlueDeep : AppColors.textSecondary,
                        fontWeight: a.primary ? FontWeight.w600 : FontWeight.w500,
                      )),
                ))
            .toList(),
      ),
    );
  }

  /// 底部输入弹窗(手机号/验证码/昵称等)
  static Future<String?> inputDialog(
    BuildContext context, {
    required String title,
    String? hint,
    String? initial,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppThemeRadius.m)),
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: AppColors.cream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppThemeRadius.s),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定', style: TextStyle(color: AppColors.softBlueDeep, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result;
  }
}

class DialogAction {
  const DialogAction(this.label, this.onTap, {this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;
}
