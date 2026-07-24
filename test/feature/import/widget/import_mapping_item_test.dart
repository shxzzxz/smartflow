import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/import/widget/import_mapping_item.dart';

void main() {
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
