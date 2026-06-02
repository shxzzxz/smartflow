import 'package:flutter/material.dart';

import '../token/typography.dart';

extension AppTextStyleContext on BuildContext {
  AppTextStyles get appTextStyles => AppTextStyles.of(this);
}

class AppTextStyles {
  AppTextStyles._(this._textTheme, this._colors);

  factory AppTextStyles.of(BuildContext context) {
    final theme = Theme.of(context);
    return AppTextStyles._(theme.textTheme, theme.colorScheme);
  }

  final TextTheme _textTheme;
  final ColorScheme _colors;

  TextStyle get pageTitle => _headlineSmall.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeXl,
    fontWeight: AppTypography.strongWeight,
  );

  TextStyle get pageSubtitle => _bodySmall.copyWith(
    color: _colors.onSurfaceVariant,
    fontSize: AppTypography.fontSizeSm,
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get sectionTitle => _titleLarge.copyWith(
    color: _colors.onSurface,
    fontWeight: AppTypography.titleWeight,
  );

  TextStyle get sectionTitleStrong =>
      sectionTitle.copyWith(fontWeight: AppTypography.strongWeight);

  TextStyle get groupTitle => _titleMedium.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeMd,
    fontWeight: AppTypography.titleWeight,
  );

  TextStyle get subsectionTitle => _titleMedium.copyWith(
    color: _colors.onSurface,
    fontWeight: AppTypography.titleWeight,
  );

  TextStyle get subsectionTitleStrong =>
      subsectionTitle.copyWith(fontWeight: AppTypography.strongWeight);

  TextStyle get listTitle => _titleSmall.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeMd,
    fontWeight: AppTypography.emphasisWeight,
  );

  TextStyle get listSupporting => _bodySmall.copyWith(
    color: _colors.onSurfaceVariant,
    fontSize: AppTypography.fontSizeXs,
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get formLabel => _labelMedium.copyWith(
    color: _colors.onSurfaceVariant,
    fontSize: AppTypography.fontSizeXs,
    fontWeight: AppTypography.emphasisWeight,
  );

  TextStyle get formValue => _titleSmall.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeMd,
    fontWeight: AppTypography.titleWeight,
  );

  TextStyle get formPlainValue => _bodyLarge.copyWith(
    color: _colors.onSurface,
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get detailLabel => _bodyMedium.copyWith(
    color: _colors.onSurfaceVariant,
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get detailValue => _bodyMedium.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeMd,
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get inputText => _bodyMedium.copyWith(
    color: _colors.onSurface,
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get metricLabel => _bodySmall.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeXs,
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get metricValue => _titleMedium.copyWith(
    fontSize: AppTypography.fontSizeLgCompact,
    fontWeight: AppTypography.emphasisWeight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get metricSupporting => _bodySmall.copyWith(
    color: _colors.onSurfaceVariant,
    fontSize: AppTypography.fontSizeCompact,
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get dateSectionTitle => _titleSmall.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeMd,
    fontWeight: AppTypography.emphasisWeight,
  );

  TextStyle get dateNavigationTitle => _titleLarge.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeLg,
    fontWeight: AppTypography.emphasisWeight,
  );

  TextStyle get calendarDayNumber => _titleSmall.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeMd,
    fontWeight: AppTypography.titleWeight,
  );

  TextStyle get calendarBadgeLabel => _labelSmall.copyWith(
    fontSize: AppTypography.fontSizeMicro,
    fontWeight: AppTypography.titleWeight,
    height: 1,
  );

  TextStyle get calendarCellAmount => _bodySmall.copyWith(
    fontSize: AppTypography.fontSizeMicro,
    fontWeight: AppTypography.emphasisWeight,
  );

  TextStyle get amountHero => _headlineSmall.copyWith(
    fontSize: AppTypography.fontSize2xl,
    fontWeight: AppTypography.strongWeight,
    height: 1,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get amountPrimary => _titleLarge.copyWith(
    fontWeight: AppTypography.titleWeight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get amountDisplay => _headlineMedium.copyWith(
    fontWeight: AppTypography.strongWeight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get amountList => _titleSmall.copyWith(
    fontSize: AppTypography.fontSizeMd,
    fontWeight: AppTypography.emphasisWeight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get amountCompact => _bodySmall.copyWith(
    fontSize: AppTypography.fontSizeXs,
    fontWeight: AppTypography.emphasisWeight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get calendarSummaryAmount => _bodySmall.copyWith(
    fontSize: AppTypography.fontSizeSm,
    fontWeight: AppTypography.titleWeight,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  TextStyle get badgeLabel => _labelSmall.copyWith(
    fontSize: AppTypography.fontSizeTiny,
    fontWeight: AppTypography.emphasisWeight,
  );

  TextStyle get iconGridLabel => _bodyMedium.copyWith(
    color: _colors.onSurface,
    fontSize: AppTypography.fontSizeXs,
    fontWeight: AppTypography.titleWeight,
    height: 1.15,
  );

  TextStyle get navigationLabel => _labelSmall.copyWith(
    fontSize: AppTypography.fontSizeTiny,
    fontWeight: AppTypography.emphasisWeight,
  );

  TextStyle quickActionLabel({required bool selected}) => _labelSmall.copyWith(
    fontSize: AppTypography.fontSizeCompact,
    fontWeight:
        selected ? AppTypography.titleWeight : AppTypography.emphasisWeight,
  );

  TextStyle segmentedControlLabel({required bool selected}) =>
      _titleMedium.copyWith(
        fontSize: AppTypography.fontSizeMd,
        fontWeight:
            selected
                ? AppTypography.strongWeight
                : AppTypography.emphasisWeight,
      );

  TextStyle largeTabLabel({required bool selected}) => _titleLarge.copyWith(
    fontSize: AppTypography.fontSizeLg,
    fontWeight:
        selected ? AppTypography.titleWeight : AppTypography.emphasisWeight,
  );

  TextStyle get onPrimaryLabel => _bodyMedium.copyWith(
    color: _colors.onPrimary,
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get onPrimarySupporting => _bodyMedium.copyWith(
    color: _colors.onPrimary.withValues(alpha: 0.86),
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get onPrimaryTiny => _bodySmall.copyWith(
    color: _colors.onPrimary.withValues(alpha: 0.84),
    fontWeight: AppTypography.bodyWeight,
  );

  TextStyle get onPrimaryTinyStrong => onPrimaryTiny.copyWith(
    color: _colors.onPrimary,
    fontWeight: AppTypography.titleWeight,
  );

  TextStyle get keypadPrimary =>
      _titleLarge.copyWith(fontWeight: AppTypography.titleWeight);

  TextStyle get keypadSecondary =>
      _titleMedium.copyWith(fontWeight: AppTypography.titleWeight);

  TextStyle get _headlineSmall =>
      _textTheme.headlineSmall ??
      const TextStyle(
        fontSize: AppTypography.fontSizeXl,
        fontWeight: AppTypography.strongWeight,
      );

  TextStyle get _headlineMedium =>
      _textTheme.headlineMedium ??
      const TextStyle(
        fontSize: AppTypography.fontSize2xl,
        fontWeight: AppTypography.strongWeight,
      );

  TextStyle get _titleLarge =>
      _textTheme.titleLarge ??
      const TextStyle(
        fontSize: AppTypography.fontSizeLg,
        fontWeight: AppTypography.titleWeight,
      );

  TextStyle get _titleMedium =>
      _textTheme.titleMedium ??
      const TextStyle(
        fontSize: AppTypography.fontSizeMd,
        fontWeight: AppTypography.titleWeight,
      );

  TextStyle get _titleSmall =>
      _textTheme.titleSmall ??
      const TextStyle(
        fontSize: AppTypography.fontSizeMd,
        fontWeight: AppTypography.emphasisWeight,
      );

  TextStyle get _bodyMedium =>
      _textTheme.bodyMedium ??
      const TextStyle(
        fontSize: AppTypography.fontSizeSm,
        fontWeight: AppTypography.bodyWeight,
      );

  TextStyle get _bodyLarge =>
      _textTheme.bodyLarge ??
      const TextStyle(
        fontSize: AppTypography.fontSizeMd,
        fontWeight: AppTypography.bodyWeight,
      );

  TextStyle get _bodySmall =>
      _textTheme.bodySmall ??
      const TextStyle(
        fontSize: AppTypography.fontSizeXs,
        fontWeight: AppTypography.bodyWeight,
      );

  TextStyle get _labelMedium =>
      _textTheme.labelMedium ??
      const TextStyle(
        fontSize: AppTypography.fontSizeXs,
        fontWeight: AppTypography.emphasisWeight,
      );

  TextStyle get _labelSmall =>
      _textTheme.labelSmall ??
      const TextStyle(
        fontSize: AppTypography.fontSizeTiny,
        fontWeight: AppTypography.emphasisWeight,
      );
}
