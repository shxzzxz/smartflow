import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart'
    as credit_query;
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/page/bill_repayment_form_page.dart';
import 'package:smartflow/feature/credit/provider/bill_query_providers.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  testWidgets('shows allocation review before saving and removes extra rows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billDetailProvider.overrideWith(
            (ref, id) async => _billDetailWithTwoConsumptionItems(),
          ),
          accountsForSelectionPurposeProvider.overrideWith(
            (ref, purpose) => Stream.value(switch (purpose) {
              AccountSelectionPurpose.repaymentSource => [
                _account('cash', AccountType.asset),
                _account('loan', AccountType.liability),
              ],
              _ => const <Account>[],
            }),
          ),
        ],
        child: const MaterialApp(home: BillRepaymentFormPage(billId: 'bill')),
      ),
    );
    await tester.pump();

    expect(find.text('分摊结果'), findsOneWidget);
    expect(find.text('计算分摊'), findsOneWidget);
    expect(find.text('生成交易'), findsOneWidget);
    expect(find.text('生成流水'), findsNothing);
    expect(find.text('明细'), findsOneWidget);
    expect(find.text('本'), findsOneWidget);
    expect(find.text('息'), findsOneWidget);
    expect(find.text('费'), findsOneWidget);
    expect(find.text('优'), findsOneWidget);
    expect(find.text('消费 A'), findsOneWidget);
    expect(find.text('消费 B'), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-item-1-principal')), findsOneWidget);
    expect(find.text('账单'), findsNothing);
    expect(find.text('剩余本金'), findsNothing);
    expect(find.text('实付'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bill-item-1-principal')));
    await tester.pump();
    final editingCell = find.descendant(
      of: find.byKey(const ValueKey('bill-item-1-principal')),
      matching: find.byType(TextField),
    );
    await tester.enterText(editingCell, '30');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('30.00'), findsWidgets);
  });
}

Account _account(String id, AccountType type) {
  return Account(id: id, name: id, type: type, balance: Money.zero());
}

credit_query.BillDetailReadModel _billDetailWithTwoConsumptionItems() {
  final period = credit_query.BillPeriod(year: 2026, month: 6);
  final summary = credit_query.BillSummaryReadModel(
    id: 'bill',
    accountId: 'loan',
    period: period,
    status: credit_query.BillStatus.billed,
    expectedPrincipal: const Money(minorUnits: 10000),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    pendingPrincipal: const Money(minorUnits: 10000),
    itemCount: 2,
    overdueItemCount: 0,
  );
  return credit_query.BillDetailReadModel(
    summary: summary,
    items: [
      credit_query.BillItemReadModel(
        id: 'bill-item-1',
        itemType: credit_query.BillItemType.consumption,
        label: '消费 A',
        status: credit_query.BillItemStatus.pending,
        repaymentDate: DateTime(2026, 6, 20),
        expectedPrincipal: const Money(minorUnits: 5000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        allocated: credit_query.RepaymentAmountBreakdown.zero,
        isOverdue: false,
      ),
      credit_query.BillItemReadModel(
        id: 'bill-item-2',
        itemType: credit_query.BillItemType.consumption,
        label: '消费 B',
        status: credit_query.BillItemStatus.pending,
        repaymentDate: DateTime(2026, 6, 20),
        expectedPrincipal: const Money(minorUnits: 5000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        allocated: credit_query.RepaymentAmountBreakdown.zero,
        isOverdue: false,
      ),
    ],
    repayments: const [],
  );
}
