import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/import/widget/import_mapping_item.dart';

void main() {
  testWidgets('renders source operation and target as three mapping columns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ImportMappingItem(
            sourceLabel: '花呗',
            sourceKindLabel: '账户',
            targetLabel: '花呗账户',
            targetKindLabel: '信用账户',
            action: ImportMappingItemAction.map,
          ),
        ),
      ),
    );

    expect(find.text('花呗'), findsOneWidget);
    expect(find.text('账户'), findsOneWidget);
    expect(find.text('映射'), findsOneWidget);
    expect(find.text('花呗账户'), findsOneWidget);
    expect(find.text('信用账户'), findsOneWidget);
  });

  testWidgets('places the create marker after the mapping target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ImportMappingItem(
            sourceLabel: '来源账户',
            sourceKindLabel: '来源账户',
            targetLabel: '新账户',
            action: ImportMappingItemAction.create,
          ),
        ),
      ),
    );

    final targetCenter = tester.getCenter(find.text('新账户'));
    final markerCenter = tester.getCenter(
      find.byIcon(RemixIcons.add_circle_line),
    );
    expect(markerCenter.dx, greaterThan(targetCenter.dx));
  });
}
