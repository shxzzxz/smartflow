// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_month_picker.dart';
import 'package:smartflow/feature/account/page/account_bills_page.dart';
import 'package:smartflow/feature/account/view_model/account_bills_view_model.dart';

void main() {
  testWidgets('shows all account bills and historical generation action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountBillsViewModelProvider('card').overrideWith(
            (ref) => AccountBillsPageState.loaded(
              bills: [_bill(7), _bill(6), _bill(5)],
              canGenerateHistoricalBill: true,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountBillsPage(accountId: 'card'),
        ),
      ),
    );

    expect(find.text('2026年07月'), findsOneWidget);
    expect(find.text('2026年06月'), findsOneWidget);
    expect(find.text('2026年05月'), findsOneWidget);
    expect(find.text('生成历史账单'), findsOneWidget);

    await tester.tap(find.text('生成历史账单'));
    await tester.pumpAndSettle();

    expect(find.byType(AppMonthPickerDialog), findsOneWidget);
  });
}

BillSummaryReadModel _bill(int month) {
  return BillSummaryReadModel(
    id: 'bill-$month',
    accountId: 'card',
    period: BillPeriod(year: 2026, month: month),
    status: BillStatus.billed,
    expectedPrincipal: Money.zero(),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    pendingPrincipal: Money.zero(),
    itemCount: 0,
    overdueItemCount: 0,
  );
}
