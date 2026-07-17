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
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
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
      chart1: AppColors.categoryFood,
      chart2: AppColors.categoryDining,
      chart3: AppColors.categoryShopping,
      chart4: AppColors.categoryTransport,
      chart5: AppColors.categorySalary,
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
      chart1: AppColors.chart1Dark,
      chart2: AppColors.chart2Dark,
      chart3: AppColors.chart3Dark,
      chart4: AppColors.chart4Dark,
      chart5: AppColors.chart5Dark,
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
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;

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
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
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
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chart5: chart5 ?? this.chart5,
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
      chart1: Color.lerp(chart1, other.chart1, t)!,
      chart2: Color.lerp(chart2, other.chart2, t)!,
      chart3: Color.lerp(chart3, other.chart3, t)!,
      chart4: Color.lerp(chart4, other.chart4, t)!,
      chart5: Color.lerp(chart5, other.chart5, t)!,
    );
  }
}
