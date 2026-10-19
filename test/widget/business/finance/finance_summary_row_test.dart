import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remixicon/remixicon.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
import 'package:smartflow/design_system/widget/app_supporting_items.dart';
import 'package:smartflow/widget/business/finance/finance_summary_row.dart';

void main() {
  testWidgets('renders status badge below the financial amount', (
    tester,
  ) async {
    var tapped = false;
    const presentation = FinanceSummaryRowPresentation(
      id: 'bill-1',
      title: '信用卡',
      amount: Money(minorUnits: 320000),
      supportingTexts: [AppSupportingText('2 条明细')],
      status: AppStatusBadgePresentation(
        label: '已出账',
        tone: AppStatusTone.warning,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FinanceSummaryRow(
            presentation: presentation,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('信用卡'), findsOneWidget);
    expect(find.text('2 条明细'), findsOneWidget);
    expect(find.text('3200.00'), findsOneWidget);
    expect(find.text('已出账'), findsOneWidget);

    final amountRect = tester.getRect(find.text('3200.00'));
    final statusRect = tester.getRect(find.text('已出账'));
    expect(statusRect.top, greaterThan(amountRect.bottom));

    final context = tester.element(find.text('已出账'));
    final warning = Theme.of(context).extension<AppThemeExtension>()!.warning;
    expect(tester.widget<Text>(find.text('已出账')).style?.color, warning);

    await tester.tap(find.text('信用卡'));
    expect(tapped, isTrue);
  });

  testWidgets('supports amount label and optional chevron', (tester) async {
    var tapped = false;
    const presentation = FinanceSummaryRowPresentation(
      id: 'bill-2',
      title: '招商银行',
      amount: Money(minorUnits: 0),
      amountLabel: '待计算',
      supportingTexts: [AppSupportingText('3 条明细')],
      status: AppStatusBadgePresentation(
        label: '未出账',
        tone: AppStatusTone.neutral,
      ),
      showChevron: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FinanceSummaryRow(
            presentation: presentation,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('待计算'), findsOneWidget);
    expect(find.byIcon(RemixIcons.arrow_right_s_line), findsOneWidget);

    await tester.tap(find.text('招商银行'));
    expect(tapped, isTrue);
  });
}
