// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/credit/page/unattributed_repayment_form_page.dart';
import 'package:smartflow/feature/credit/view_model/unattributed_repayment_form_view_model.dart';

void main() {
  testWidgets('requires a ledger transaction without showing a toggle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final overview = CreditAccountOverviewReadModel(
      creditAccount: const CreditLiabilityAccountReadModel(
        id: 'credit-extension',
        accountId: 'credit',
        kind: CreditLiabilityAccountKind.credit,
        billingDayToNext: true,
      ),
      liabilityBalance: const Money(minorUnits: 2500),
      buckets: const CreditDebtBucketsReadModel(
        billDebt: Money(minorUnits: 0),
        futureContractDebt: Money(minorUnits: 0),
        unattributedDebt: Money(minorUnits: 2500),
      ),
    );
    final state = UnattributedRepaymentFormState.loaded(
      overview: overview,
      repaymentSourceAccounts: [
        Account(
          id: 'cash',
          name: '现金',
          type: AccountType.asset,
          balance: Money(minorUnits: 10000),
        ),
      ],
      occurredAt: DateTime(2026, 7, 15),
      paidFromAccountId: 'cash',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unattributedRepaymentFormViewModelProvider(
            'credit',
          ).overrideWith(() => _FixedUnattributedRepaymentFormViewModel(state)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const UnattributedRepaymentFormPage(accountId: 'credit'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('生成交易'), findsNothing);
    expect(find.text('还款日期'), findsOneWidget);
    expect(find.text('还款账户'), findsOneWidget);
  });
}

class _FixedUnattributedRepaymentFormViewModel
    extends UnattributedRepaymentFormViewModel {
  _FixedUnattributedRepaymentFormViewModel(this.fixedState);

  final UnattributedRepaymentFormState fixedState;

  @override
  Future<UnattributedRepaymentFormState> build(String accountId) async {
    return fixedState;
  }
}
