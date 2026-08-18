import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/widget/business/finance/bill_item_row.dart';
import 'package:smartflow/widget/business/finance/bill_status_badge.dart';

void main() {
  testWidgets('renders the status badge below the item amount', (tester) async {
    var tapped = false;
    const presentation = BillItemRowPresentation(
      id: 'item-1',
      leadingIcon: Icons.receipt_long,
      title: '消费',
      supportingTexts: ['还款 2026-07-20'],
      amount: Money(minorUnits: 7550),
      status: BillStatusBadgePresentation(
        label: '部分已还',
        tone: BillStatusTone.warning,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BillItemRow(
            presentation: presentation,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('消费'), findsOneWidget);
    expect(find.text('还款 2026-07-20'), findsOneWidget);
    expect(find.text('75.50'), findsOneWidget);
    expect(find.text('部分已还'), findsOneWidget);

    final amountRect = tester.getRect(find.text('75.50'));
    final statusRect = tester.getRect(find.text('部分已还'));
    expect(statusRect.top, greaterThan(amountRect.bottom));

    await tester.tap(find.text('消费'));
    expect(tapped, isTrue);
  });
}
