// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_month_picker.dart';
import 'package:smartflow/feature/account/page/account_bills_page.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/credit/provider/bill_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  testWidgets('shows all account bills and historical generation action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountViewProvider(
            'card',
          ).overrideWith((ref) => AsyncValue.data(_account())),
          billSummariesByAccountProvider(
            'card',
          ).overrideWith((ref) async => [_bill(7), _bill(6), _bill(5)]),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountBillsPage(accountId: 'card'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026年07月'), findsOneWidget);
    expect(find.text('2026年06月'), findsOneWidget);
    expect(find.text('2026年05月'), findsOneWidget);
    expect(find.byTooltip('生成历史账单'), findsOneWidget);

    await tester.tap(find.byTooltip('生成历史账单'));
    await tester.pumpAndSettle();

    expect(find.byType(AppMonthPickerDialog), findsOneWidget);
  });
}

AccountView _account() {
  return AccountView(
    id: 'card',
    name: '信用卡',
    kind: AccountProfileKind.credit,
    balance: Money.zero(),
    iconKey: 'card',
    isArchived: false,
  );
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
