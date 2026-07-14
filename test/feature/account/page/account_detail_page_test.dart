// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/widget/app_month_picker.dart';
import 'package:smartflow/feature/account/page/account_detail_page.dart';
import 'package:smartflow/feature/account/view_model/account_detail_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  testWidgets(
    'shows a discoverable historical bill action for credit accounts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _app(
          account: _account(kind: AccountProfileKind.credit),
          canGenerateHistoricalBill: true,
        ),
      );

      expect(find.text('合同未来欠款'), findsNothing);
      expect(find.text('生成历史账单'), findsOneWidget);

      await tester.tap(find.text('生成历史账单'));
      await tester.pumpAndSettle();

      expect(find.byType(AppMonthPickerDialog), findsOneWidget);
    },
  );

  testWidgets('hides historical bill action when the view model disallows it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        account: _account(kind: AccountProfileKind.fund),
        canGenerateHistoricalBill: false,
      ),
    );

    expect(find.text('生成历史账单'), findsNothing);
  });
}

Widget _app({
  required AccountView account,
  required bool canGenerateHistoricalBill,
}) {
  final state = AccountDetailPageState.loaded(
    account: account,
    canGenerateHistoricalBill: canGenerateHistoricalBill,
    transactionGroups: const [],
    contracts: const AccountContractsState.loaded(contracts: []),
    bills: const AccountBillsState.loaded(bills: []),
    creditOverview: const AccountCreditOverviewState.notApplicable(),
  );
  return ProviderScope(
    overrides: [
      accountDetailViewModelProvider(account.id).overrideWith((ref) => state),
    ],
    child: MaterialApp(home: AccountDetailPage(accountId: account.id)),
  );
}

AccountView _account({required AccountProfileKind kind}) {
  return AccountView(
    id: 'account',
    name: '测试账户',
    kind: kind,
    balance: Money.zero(),
    iconKey: kind.iconKey,
    isArchived: false,
    creditLimit:
        kind == AccountProfileKind.credit
            ? const Money(minorUnits: 100000)
            : null,
    billingDay: kind == AccountProfileKind.credit ? 5 : null,
    repaymentDay: kind == AccountProfileKind.credit ? 25 : null,
    billingDayToNext: kind == AccountProfileKind.credit ? true : null,
  );
}
