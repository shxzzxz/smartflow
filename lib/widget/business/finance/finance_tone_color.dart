import 'package:flutter/material.dart';

import 'package:smartflow/design_system/theme/app_theme_extension.dart';

import 'finance_tone.dart';

Color financeToneColor(
  ColorScheme colors,
  AppThemeExtension financeColors,
  FinanceTone tone,
) {
  return switch (tone) {
    FinanceTone.income => financeColors.income,
    FinanceTone.expense => financeColors.expense,
    FinanceTone.neutral => colors.onSurface,
    FinanceTone.info => financeColors.info,
    FinanceTone.equity => financeColors.equity,
    FinanceTone.primary => colors.primary,
  };
}
