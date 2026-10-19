import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_list_divider.dart';

void main() {
  testWidgets('renders the inset list divider geometry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AppListDivider()),
      ),
    );

    final context = tester.element(find.byType(AppListDivider));
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppListDivider),
        matching: find.byType(Container),
      ),
    );
    final colors = Theme.of(context).colorScheme;
    final decorationColor = container.color;

    expect(container.margin, const EdgeInsets.symmetric(horizontal: 16));
    expect(container.constraints?.maxHeight, 1);
    expect(decorationColor, colors.outlineVariant.withValues(alpha: 0.45));
    expect(tester.takeException(), isNull);
  });
}
