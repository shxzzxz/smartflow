import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/page/installment_form_page.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  testWidgets(
    'can choose to create contract without disbursement transaction',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          accountsForSelectionPurposeProvider.overrideWith(
            (ref, purpose) => Stream.value(switch (purpose) {
              AccountSelectionPurpose.repaymentTarget => [_loanAccount()],
              AccountSelectionPurpose.fund => [_fundAccount()],
              _ => const <Account>[],
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: InstallmentFormPage(liabilityAccountId: 'loan'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('创建放款交易'), findsOneWidget);
      expect(find.text('到账账户'), findsOneWidget);
      expect(find.text('末期还款日'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('到账账户'), findsNothing);
    },
  );
}

Account _loanAccount() {
  return Account(
    id: 'loan',
    name: '贷款账户',
    type: AccountType.liability,
    profileKey: AccountProfileKind.loan.key,
    balance: Money.zero(),
  );
}

Account _fundAccount() {
  return Account(
    id: 'cash',
    name: '现金',
    type: AccountType.asset,
    balance: Money.zero(),
  );
}
