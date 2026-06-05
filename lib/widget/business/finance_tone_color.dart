import 'package:flutter/material.dart';

import '../../design_system/theme/app_theme_extension.dart';
import 'transaction_list_presentation.dart';

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
