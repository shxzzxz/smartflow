import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/post_receipt.dart';

void main() {
  group('PostReceipt.validate', () {
    test('accepts a balanced receipt', () {
      final receipt = PostReceipt(
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: DateTime(2026, 5, 26),
        primaryAmount: const Money(minorUnits: 2000),
        details: const [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.primaryExpense,
            amount: Money(minorUnits: 2000),
          ),
        ],
        entries: const [
          ReceiptEntry(
            accountId: '1',
            direction: EntryDirection.debit,
            amount: Money(minorUnits: 2000),
          ),
          ReceiptEntry(
            accountId: '2',
            direction: EntryDirection.credit,
            amount: Money(minorUnits: 2000),
          ),
        ],
      );
      expect(receipt.validate(), isNull);
    });

    test('rejects unbalanced entries', () {
      final receipt = PostReceipt(
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: DateTime(2026, 5, 26),
        primaryAmount: const Money(minorUnits: 2000),
        details: const [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.primaryExpense,
            amount: Money(minorUnits: 2000),
          ),
        ],
        entries: const [
          ReceiptEntry(
            accountId: '1',
            direction: EntryDirection.debit,
            amount: Money(minorUnits: 2000),
          ),
          ReceiptEntry(
            accountId: '2',
            direction: EntryDirection.credit,
            amount: Money(minorUnits: 1000),
          ),
        ],
      );
      expect(receipt.validate()?.code, 'entries_not_balanced');
    });
  });

  group('Transaction.fromReceipt', () {
    test('builds an unpersisted transaction from a receipt', () {
      final receipt = PostReceipt(
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: DateTime(2026, 5, 26),
        primaryAmount: const Money(minorUnits: 2000),
        details: const [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.primaryExpense,
            amount: Money(minorUnits: 2000),
          ),
        ],
        entries: const [
          ReceiptEntry(
            accountId: '1',
            direction: EntryDirection.debit,
            amount: Money(minorUnits: 2000),
          ),
          ReceiptEntry(
            accountId: '2',
            direction: EntryDirection.credit,
            amount: Money(minorUnits: 2000),
          ),
        ],
      );
      final transaction = Transaction.fromReceipt(receipt);
      expect(transaction.persistedId, isNull);
      expect(transaction.accountIds, {1, 2});
    });
  });

  group('Account aggregate', () {
    test('applies transaction entries according to account type', () {
      const expense = Account(
        id: '1',
        name: 'Food',
        type: AccountType.expense,
        balance: Money(minorUnits: 0),
      );
      const wallet = Account(
        id: '2',
        name: 'Wallet',
        type: AccountType.asset,
        balance: Money(minorUnits: 10000),
      );
      final receipt = PostReceipt(
        businessPurpose: BusinessPurpose.dailyExpense,
        occurredAt: DateTime(2026, 5, 26),
        primaryAmount: const Money(minorUnits: 2000),
        details: const [
          ReceiptDetail(
            lineNo: 1,
            type: TransactionDetailType.primaryExpense,
            amount: Money(minorUnits: 2000),
          ),
        ],
        entries: const [
          ReceiptEntry(
            accountId: '1',
            direction: EntryDirection.debit,
            amount: Money(minorUnits: 2000),
          ),
          ReceiptEntry(
            accountId: '2',
            direction: EntryDirection.credit,
            amount: Money(minorUnits: 2000),
          ),
        ],
      );
      final transaction = Transaction.fromReceipt(receipt);

      expect(
        expense.applyTransaction(transaction).balance,
        const Money(minorUnits: 2000),
      );
      expect(
        wallet.applyTransaction(transaction).balance,
        const Money(minorUnits: 8000),
      );
    });
  });
}
