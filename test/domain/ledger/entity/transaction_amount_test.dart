import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/entity/transaction_line.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

void main() {
  test('amountOf sums every line for the role', () {
    final transaction = Transaction(
      id: 'receipt',
      businessPurpose: BusinessPurpose.reimbursementReceipt,
      occurredAt: DateTime(2026, 7, 23),
      primaryAmount: const Money(minorUnits: 9999),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.manual,
      lines: [_line(1, 1200, 'cash'), _line(2, 800, 'bank')],
    );

    expect(
      transaction.amountOf(TransactionRole.settlementIn),
      const Money(minorUnits: 2000),
    );
  });

  test(
    'transaction group totals use settlement lines instead of child headers',
    () {
      final parent = _transaction(
        id: 'parent',
        purpose: BusinessPurpose.reimbursementAdvance,
        primaryAmount: 10000,
      );
      final refund = _transaction(
        id: 'refund',
        purpose: BusinessPurpose.refund,
        primaryAmount: 9999,
        parentId: parent.id,
        settlementAmounts: const [1200, 800],
      );
      final receipt = _transaction(
        id: 'receipt',
        purpose: BusinessPurpose.reimbursementReceipt,
        primaryAmount: 8888,
        parentId: parent.id,
        settlementAmounts: const [2500, 3500],
      );
      final group = TransactionGroup(
        parentTransaction: parent,
        childTransactions: [refund, receipt],
      );

      expect(group.refundedTotal(), const Money(minorUnits: 2000));
      expect(group.reimbursementReceivedTotal(), const Money(minorUnits: 6000));
      expect(group.refundSummary?.refundedTotal, const Money(minorUnits: 2000));
      expect(
        group.reimbursementSummary?.refundedAmount,
        const Money(minorUnits: 2000),
      );
      expect(
        group.reimbursementSummary?.receivedAmount,
        const Money(minorUnits: 6000),
      );
      expect(
        group.reimbursementSummary?.outstanding,
        const Money(minorUnits: 2000),
      );
    },
  );
}

TransactionLine _line(
  int lineNo,
  int amount,
  String accountId, {
  String transactionId = 'receipt',
}) => TransactionLine(
  id: '$transactionId-$lineNo',
  transactionId: transactionId,
  lineNo: lineNo,
  role: TransactionRole.settlementIn,
  accountId: accountId,
  amount: Money(minorUnits: amount),
);

Transaction _transaction({
  required String id,
  required BusinessPurpose purpose,
  required int primaryAmount,
  String? parentId,
  List<int> settlementAmounts = const [],
}) => Transaction(
  id: id,
  parentTransactionId: parentId,
  businessPurpose: purpose,
  occurredAt: DateTime(2026, 7, 23),
  primaryAmount: Money(minorUnits: primaryAmount),
  isExcludedFromStats: false,
  isExcludedFromBudget: false,
  sourceKind: SourceKind.manual,
  lines: [
    for (var index = 0; index < settlementAmounts.length; index++)
      _line(
        index + 1,
        settlementAmounts[index],
        'account-$index',
        transactionId: id,
      ),
  ],
);
