import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/import/presentation/import_presentation.dart';
import 'package:smartflow/feature/import/widget/import_source_icon.dart';

void main() {
  testWidgets('maps every import source to its circle icon and palette', (
    tester,
  ) async {
    for (final source in ImportEntrySource.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: ImportSourceIcon(source: source, size: 48)),
        ),
      );

      final context = tester.element(find.byType(ImportSourceIcon));
      final colors = Theme.of(context).colorScheme;
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(ImportSourceIcon),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      final icon = tester.widget<Icon>(find.byType(Icon));
      final expected = switch (source) {
        ImportEntrySource.yimu => (
          icon: Icons.energy_savings_leaf_rounded,
          background: colors.primaryContainer,
          foreground: colors.onPrimaryContainer,
        ),
        ImportEntrySource.unionPay => (
          icon: RemixIcons.bank_card_line,
          background: colors.secondaryContainer,
          foreground: colors.onSecondaryContainer,
        ),
        ImportEntrySource.generic => (
          icon: RemixIcons.file_excel_2_line,
          background: colors.tertiaryContainer,
          foreground: colors.onTertiaryContainer,
        ),
      };

      expect(container.constraints?.maxWidth, 48);
      expect(container.constraints?.maxHeight, 48);
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, expected.background);
      expect(icon.icon, expected.icon);
      expect(icon.color, expected.foreground);
    }
  });
}
