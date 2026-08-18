import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/theme/app_theme_extension.dart';
import 'package:smartflow/widget/business/finance/bill_status_badge.dart';
import 'package:smartflow/widget/business/finance/bill_summary_row.dart';

void main() {
  testWidgets('renders status badge below the bill amount', (tester) async {
    var tapped = false;
    const presentation = BillSummaryRowPresentation(
      id: 'bill-1',
      title: '信用卡',
      amount: Money(minorUnits: 320000),
      supportingTexts: [BillSummarySupportingText(text: '2 条明细')],
      status: BillStatusBadgePresentation(
        label: '已出账',
        tone: BillStatusTone.warning,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BillSummaryRow(
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
}
