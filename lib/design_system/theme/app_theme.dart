import 'package:flutter/material.dart';

import '../token/component.dart';
import '../token/radius.dart';
import '../token/spacing.dart';
import '../token/typography.dart';
import 'app_color_scheme.dart';
import 'app_text_theme.dart';
import 'app_theme_extension.dart';

abstract final class AppTheme {
  static ThemeData light() {
    final colors = AppColorSchemes.light();
    return _theme(colors, AppThemeExtension.light());
  }

  static ThemeData dark() {
    final colors = AppColorSchemes.dark();
    return _theme(colors, AppThemeExtension.dark());
  }

  static ThemeData _theme(ColorScheme colors, AppThemeExtension extension) {
    final textTheme = AppTextThemes.textTheme(colors);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      borderSide: BorderSide(color: colors.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      textTheme: textTheme,
      extensions: [extension],
      appBarTheme: AppBarThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.space32 * 2, AppComponentTokens.controlMinHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.space20),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.onSurface.withValues(
                alpha: AppComponentTokens.disabledContainerOpacity,
              );
            }
            return colors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.onSurface.withValues(
                alpha: AppComponentTokens.disabledContentOpacity,
              );
            }
            return colors.onPrimary;
          }),
          overlayColor: WidgetStatePropertyAll(
            colors.onPrimary.withValues(
              alpha: AppComponentTokens.strongOverlayOpacity,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: AppTypography.titleWeight,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.space32 * 2, AppComponentTokens.controlMinHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.space20),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          elevation: const WidgetStatePropertyAll(0),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.onSurface.withValues(
                alpha: AppComponentTokens.disabledContentOpacity,
              );
            }
            return colors.primary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                color: colors.outlineVariant.withValues(
                  alpha: AppComponentTokens.subduedOutlineOpacity,
                ),
              );
            }
            return BorderSide(color: colors.primary);
          }),
          overlayColor: WidgetStatePropertyAll(
            colors.primary.withValues(
              alpha: AppComponentTokens.controlOverlayOpacity,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: AppTypography.titleWeight,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(AppComponentTokens.controlMinHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.space16),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.onSurface.withValues(
                alpha: AppComponentTokens.disabledContentOpacity,
              );
            }
            return colors.primary;
          }),
          overlayColor: WidgetStatePropertyAll(
            colors.primary.withValues(
              alpha: AppComponentTokens.controlOverlayOpacity,
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: AppTypography.titleWeight,
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space14,
          vertical: AppSpacing.space12,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: colors.primary,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(
              alpha: AppComponentTokens.mutedOutlineOpacity,
            ),
          ),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: colors.primary,
            width: AppComponentTokens.focusedOutlineWidth,
          ),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: colors.error,
            width: AppComponentTokens.focusedOutlineWidth,
          ),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        overlayColor: WidgetStatePropertyAll(
          colors.primary.withValues(
            alpha: AppComponentTokens.subtleOverlayOpacity,
          ),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.space16),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
        hintStyle: WidgetStatePropertyAll(
          textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        constraints: const BoxConstraints(
          minHeight: AppSpacing.space48,
          maxHeight: AppSpacing.space48,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: colors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: AppTypography.strongWeight,
        ),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: AppTypography.emphasisWeight,
        ),
        overlayColor: WidgetStatePropertyAll(
          colors.primary.withValues(
            alpha: AppComponentTokens.subtleOverlayOpacity,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.padded,
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.space48, AppComponentTokens.controlMinHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.space10),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfaceContainerHighest;
          }
          return states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.surfaceContainerLowest;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.onSurface.withValues(
              alpha: AppComponentTokens.disabledSelectionOpacity,
            );
          }
          return states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return colors.outlineVariant;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        ),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.onSurface.withValues(
              alpha: AppComponentTokens.disabledSelectionOpacity,
            );
          }
          return states.contains(WidgetState.selected)
              ? colors.primary
              : Colors.transparent;
        }),
        side: BorderSide(color: colors.outlineVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceContainer,
        selectedColor: colors.primary.withValues(
          alpha: AppComponentTokens.selectedContainerOpacity,
        ),
        disabledColor: colors.onSurface.withValues(
          alpha: AppComponentTokens.subtleOverlayOpacity,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        linearMinHeight: AppSpacing.space6,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusXl),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: AppComponentTokens.menuElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
        position: PopupMenuPosition.under,
        iconColor: colors.onSurfaceVariant,
        iconSize: AppSpacing.space20,
        labelTextStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            colors.surfaceContainerLowest,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(
            AppComponentTokens.menuElevation,
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: AppSpacing.space8),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(
              AppComponentTokens.menuMinWidth,
              AppComponentTokens.controlMinHeight,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.space12),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.onSurface.withValues(
                alpha: AppComponentTokens.disabledContentOpacity,
              );
            }
            return colors.onSurface;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colors.onSurface.withValues(
                alpha: AppComponentTokens.disabledContentOpacity,
              );
            }
            return colors.onSurfaceVariant;
          }),
          iconSize: const WidgetStatePropertyAll(AppSpacing.space20),
          textStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLowest,
        modalBackgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.radiusXl),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppComponentTokens.navigationBarHeight,
        elevation: 0,
        backgroundColor: colors.surfaceContainerLowest,
        indicatorColor: colors.primary.withValues(
          alpha: AppComponentTokens.selectedContainerOpacity,
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color:
                states.contains(WidgetState.selected)
                    ? colors.primary
                    : colors.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelSmall?.copyWith(
            color:
                states.contains(WidgetState.selected)
                    ? colors.primary
                    : colors.onSurfaceVariant,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? AppTypography.titleWeight
                    : AppTypography.emphasisWeight,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: AppComponentTokens.outlineWidth,
        space: AppComponentTokens.outlineWidth,
      ),
    );
  }
}
