// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/feature/amortization/provider/amortization_providers.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/transaction/page/refund_form_page.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';

void main() {
  testWidgets('refund page places remaining balance in a top-level card', (
    tester,
  ) async {
    final plan = _plan();

    await tester.pumpWidget(_app(plan: plan, termination: false));
    await tester.pumpAndSettle();

    expect(find.text('摊销退款'), findsOneWidget);
    expect(find.text('可退余额：300'), findsOneWidget);
    expect(find.text('退款分类'), findsOneWidget);
    expect(find.text('到账账户'), findsOneWidget);
    expect(find.text('终止确认：300'), findsNothing);

    final remainingCard = find.byKey(
      const ValueKey('refund-remaining-summary'),
    );
    expect(
      find.descendant(of: remainingCard, matching: find.byType(AppFormSection)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: remainingCard, matching: find.text('可退余额：300')),
      findsOneWidget,
    );
  });

  testWidgets('termination page uses shared copy and a confirmation card', (
    tester,
  ) async {
    final plan = _plan();

    await tester.pumpWidget(_app(plan: plan, termination: true));
    await tester.pumpAndSettle();

    expect(find.text('摊销终止'), findsOneWidget);
    expect(find.text('剩余待摊：300'), findsOneWidget);
    expect(find.text('退还金额'), findsOneWidget);
    expect(find.text('退还分类'), findsOneWidget);
    expect(find.text('到账账户'), findsOneWidget);
    expect(find.text('终止退还金额'), findsNothing);
    expect(find.text('终止分类退还'), findsNothing);
    expect(find.text('终止账户退还'), findsNothing);
    expect(find.text('终止确认：300'), findsOneWidget);

    final confirmationCard = find.byKey(
      const ValueKey('refund-termination-confirmation'),
    );
    expect(
      find.descendant(
        of: confirmationCard,
        matching: find.byType(AppFormSection),
      ),
      findsOneWidget,
    );

    final amountField = find.descendant(
      of: find.byType(MoneyPlainFormRow),
      matching: find.byType(TextField),
    );
    await tester.enterText(amountField, '100');
    await tester.pump();

    expect(find.text('终止确认：200'), findsOneWidget);
  });
}

Widget _app({required AmortizationPlan plan, required bool termination}) {
  final cash = _account('cash');
  final prepaid = _account('prepaid');
  final expense = _account('expense', type: AccountType.expense);
  final accounts = {cash.id: cash, prepaid.id: prepaid, expense.id: expense};
  return ProviderScope(
    overrides: [
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.settlement,
      ).overrideWithValue(AsyncData([cash])),
      accountsByIdProvider.overrideWithValue(AsyncData(accounts)),
      transactionDetailProvider(
        'amortization-tx',
      ).overrideWithValue(AsyncData(_detail(plan))),
      amortizationPlanProvider(
        plan.id,
      ).overrideWith((ref) => Stream.value(plan)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: termination
          ? RefundFormPage.amortizationTermination(
              transactionId: 'amortization-tx',
            )
          : RefundFormPage(parentTransactionId: 'amortization-tx'),
    ),
  );
}

AmortizationPlan _plan() {
  return AmortizationPlan.create(
    id: 'plan',
    kind: AmortizationKind.prepaidExpense,
    deferralAccountId: 'prepaid',
    fundingAllocations: singleAllocation(
      accountId: 'cash',
      amount: const Money(minorUnits: 30000),
    ),
    categoryAllocations: singleAllocation(
      accountId: 'expense',
      amount: const Money(minorUnits: 30000),
    ),
    originalAmount: const Money(minorUnits: 30000),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    firstRecognitionAt: DateTime(2026, 1, 31),
    recognitionCount: 3,
    initialTransactionId: 'amortization-tx',
  );
}

TransactionReadModel _detail(AmortizationPlan plan) {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: 'amortization-tx',
      businessPurpose: BusinessPurpose.transfer,
      occurredAt: DateTime(2026, 1, 1),
      primaryAmount: plan.originalAmount,
      sourceKind: SourceKind.manual,
      ownership: TransactionOwnership(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: plan.id,
      ),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
    ),
    lines: [
      TransactionLine(
        id: 'amortization-tx-out',
        transactionId: 'amortization-tx',
        lineNo: 1,
        role: TransactionRole.settlementOut,
        accountId: plan.deferralAccountId,
        amount: plan.originalAmount,
      ),
      TransactionLine(
        id: 'amortization-tx-in',
        transactionId: 'amortization-tx',
        lineNo: 2,
        role: TransactionRole.settlementIn,
        accountId: 'cash',
        amount: plan.originalAmount,
      ),
    ],
  );
}

Account _account(
  String id, {
  AccountType type = AccountType.asset,
  AccountSubtype? subtype,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    subtype: subtype,
    balance: Money.zero(),
  );
}
