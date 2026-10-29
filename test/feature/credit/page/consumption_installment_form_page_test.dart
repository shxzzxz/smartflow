import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/page/consumption_installment_form_page.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  testWidgets('renders the consumption installment expense scenario', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryTreeProvider(AccountType.expense).overrideWith(
            (ref) => Stream.value([
              CategoryNode(
                account: _account(
                  'phone',
                  AccountType.expense,
                  profileKey: 'expense',
                ),
              ),
            ]),
          ),
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.fund,
          ).overrideWith(
            (ref) => Stream.value([
              _account(
                'cash',
                AccountType.asset,
                profileKey: AccountProfileKind.fund.key,
              ),
            ]),
          ),
          accountsForSelectionPurposeProvider(
            AccountSelectionPurpose.repaymentTarget,
          ).overrideWith(
            (ref) => Stream.value([
              _account(
                'credit',
                AccountType.liability,
                profileKey: AccountProfileKind.credit.key,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: ConsumptionInstallmentFormPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('消费分期'), findsOneWidget);
    expect(find.text('成交价'), findsOneWidget);
    expect(find.text('首付款'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('信用账户'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('信用账户'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('创建消费分期'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('创建消费分期'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Account _account(String id, AccountType type, {required String profileKey}) {
  return Account(
    id: id,
    name: id,
    type: type,
    profileKey: profileKey,
    balance: const Money(minorUnits: 0),
  );
}
