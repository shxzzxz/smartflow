import 'package:flutter/material.dart';

import '../token/colors.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.asset,
    required this.liability,
    required this.equity,
  });

  factory AppThemeExtension.light() {
    return const AppThemeExtension(
      success: AppColors.success,
      warning: AppColors.warning,
      danger: AppColors.danger,
      info: AppColors.info,
      income: AppColors.income,
      expense: AppColors.expense,
      transfer: AppColors.transfer,
      asset: AppColors.income,
      liability: AppColors.expense,
      equity: AppColors.equity,
    );
  }

  factory AppThemeExtension.dark() {
    return const AppThemeExtension(
      success: Color(0xFF8BD88F),
      warning: Color(0xFFFFC266),
      danger: Color(0xFFFFB4AB),
      info: Color(0xFFA9C7FF),
      income: Color(0xFF8BD88F),
      expense: Color(0xFFFFB68A),
      transfer: Color(0xFFA9C7FF),
      asset: Color(0xFF8BD88F),
      liability: Color(0xFFFFB68A),
      equity: Color(0xFFD2BFFF),
    );
  }

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color income;
  final Color expense;
  final Color transfer;
  final Color asset;
  final Color liability;
  final Color equity;

  @override
  AppThemeExtension copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? income,
    Color? expense,
    Color? transfer,
    Color? asset,
    Color? liability,
    Color? equity,
  }) {
    return AppThemeExtension(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      asset: asset ?? this.asset,
      liability: liability ?? this.liability,
      equity: equity ?? this.equity,
    );
  }

  @override
  AppThemeExtension lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }

    return AppThemeExtension(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      asset: Color.lerp(asset, other.asset, t)!,
      liability: Color.lerp(liability, other.liability, t)!,
      equity: Color.lerp(equity, other.equity, t)!,
    );
  }
}
