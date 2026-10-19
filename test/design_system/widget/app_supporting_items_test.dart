import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/design_system/widget/app_supporting_items.dart';

void main() {
  testWidgets('renders supporting labels with semantic tone colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AppSupportingItems(
            items: [
              AppSupportingText('到期 07-25'),
              AppSupportingText('2 条逾期', tone: AppStatusTone.danger),
            ],
          ),
        ),
      ),
    );

    final context = tester.element(find.text('到期 07-25'));
    final colors = Theme.of(context).colorScheme;
    final extension = Theme.of(context).extension<AppThemeExtension>()!;
    final neutral = tester.widget<Text>(find.text('到期 07-25'));
    final danger = tester.widget<Text>(find.text('2 条逾期'));

    expect(neutral.style?.color, colors.onSurfaceVariant);
    expect(danger.style?.color, extension.danger);
    expect(danger.maxLines, 1);
    expect(danger.overflow, TextOverflow.ellipsis);
    expect(find.byType(Wrap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
