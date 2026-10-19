import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/widget/business/finance/finance_dot_label.dart';

void main() {
  testWidgets('renders a compact chip with the supplied dot color', (
    tester,
  ) async {
    const dotColor = Color(0xFF123456);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: FinanceDotLabel(label: '标签', dotColor: dotColor),
        ),
      ),
    );

    final context = tester.element(find.byType(FinanceDotLabel));
    final colors = Theme.of(context).colorScheme;
    final chip = tester.widget<Chip>(find.byType(Chip));
    final avatar = chip.avatar! as Icon;

    expect(find.text('标签'), findsOneWidget);
    expect(chip.visualDensity, VisualDensity.compact);
    expect(chip.backgroundColor, colors.surfaceContainerHighest);
    expect(chip.side, BorderSide(color: colors.outlineVariant));
    expect(avatar.icon, Icons.circle);
    expect(avatar.color, dotColor);
    expect(avatar.size, AppSpacing.space10);
  });
}
