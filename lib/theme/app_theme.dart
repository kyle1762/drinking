import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// 奶油治愈风主题
/// 大圆角、低饱和、安卓原生水波纹反馈
class AppTheme {
  AppTheme._();

  static const double radiusL = 24;
  static const double radiusM = 16;
  static const double radiusS = 12;

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.softBlueDeep,
        secondary: AppColors.mintDeep,
        surface: AppColors.cream,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(
            color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return AppColors.softBlueDeep;
          return AppColors.paused;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.softBlueDeep,
        inactiveTrackColor: AppColors.divider,
        thumbColor: AppColors.softBlueDeep,
        overlayColor: Color(0x229DD4E8),
        trackHeight: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
      ),
    );
  }
}
