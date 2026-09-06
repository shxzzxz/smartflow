import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/feature/credit/page/installment_form_page.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  testWidgets('groups the workflow and uses design-system choice controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    expect(find.byType(AppFormSection), findsWidgets);
    expect(find.text('贷款'), findsOneWidget);
    expect(find.text('放款信息'), findsOneWidget);
    expect(find.text('分期设置'), findsNothing);
    expect(find.text('计算约定'), findsOneWidget);
    expect(find.text('阶段 1 · 还款阶段'), findsOneWidget);
    expect(
      find.byType(AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>),
      findsOneWidget,
    );
    expect(
      find.byType(AppPlainSelectMenuFormRow<InterestAccrualMethod>),
      findsOneWidget,
    );
    expect(
      find.byType(DropdownButton<InstallmentRepaymentMethod>),
      findsNothing,
    );
    expect(find.text('%'), findsOneWidget);
    expect(find.text('按期数与间隔生成'), findsOneWidget);

    expect(tester.getTopLeft(find.byType(AppFormSection).first).dx, 16);
  });

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

      await tester.tap(find.byType(Switch).first);
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
