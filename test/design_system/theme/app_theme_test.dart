import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';

void main() {
  for (final entry
      in <String, ThemeData>{
        'light': AppTheme.light(),
        'dark': AppTheme.dark(),
      }.entries) {
    test(
      '${entry.key} theme keeps Material behavior with SmartFlow visuals',
      () {
        final theme = entry.value;
        final colors = theme.colorScheme;

        expect(theme.useMaterial3, isTrue);
        expect(theme.scaffoldBackgroundColor, colors.surface);
        expect(
          theme.filledButtonTheme.style?.minimumSize?.resolve({}),
          const Size(64, 48),
        );
        expect(
          theme.searchBarTheme.backgroundColor?.resolve({}),
          colors.surfaceContainer,
        );
        expect(theme.searchBarTheme.elevation?.resolve({}), 0);
        expect(theme.inputDecorationTheme.filled, isTrue);
        expect(
          theme.inputDecorationTheme.fillColor,
          colors.surfaceContainerLowest,
        );
        expect(
          theme.inputDecorationTheme.enabledBorder,
          isA<OutlineInputBorder>(),
        );
        expect(theme.tabBarTheme.dividerColor, Colors.transparent);
        expect(
          theme.segmentedButtonTheme.style?.minimumSize?.resolve({}),
          const Size(48, 48),
        );
        expect(
          theme.switchTheme.trackColor?.resolve({WidgetState.selected}),
          colors.primary,
        );
        expect(
          theme.checkboxTheme.fillColor?.resolve({WidgetState.selected}),
          colors.primary,
        );
        expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
        expect(theme.bottomSheetTheme.showDragHandle, isTrue);
        expect(theme.navigationBarTheme.elevation, 0);
      },
    );
  }
}
