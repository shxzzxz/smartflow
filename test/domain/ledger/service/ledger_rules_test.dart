import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';
import 'package:smartflow/domain/ledger/service/ledger_rule.dart';
import 'package:smartflow/domain/ledger/valobj/post_receipt.dart';

void main() {
  group('ledger rules', () {
    test('calculates balance deltas for debit and credit directions', () {
      expect(
        balanceDeltaMinor(
          accountType: AccountType.asset,
          direction: EntryDirection.debit,
          amountMinor: 100,
        ),
        100,
      );
      expect(
        balanceDeltaMinor(
          accountType: AccountType.asset,
          direction: EntryDirection.credit,
          amountMinor: 100,
        ),
        -100,
      );
      expect(
        balanceDeltaMinor(
          accountType: AccountType.expense,
          direction: EntryDirection.debit,
          amountMinor: 100,
        ),
        100,
      );
      expect(
        balanceDeltaMinor(
          accountType: AccountType.liability,
          direction: EntryDirection.credit,
          amountMinor: 100,
        ),
        100,
      );
      expect(
        balanceDeltaMinor(
          accountType: AccountType.income,
          direction: EntryDirection.debit,
          amountMinor: 100,
        ),
        -100,
      );
      expect(
        balanceDeltaMinor(
          accountType: AccountType.equity,
          direction: EntryDirection.credit,
          amountMinor: 100,
        ),
        100,
      );
    });

    test('validates balanced entries', () {
      final balanced = [
        ReceiptEntry(
          accountId: '1',
          direction: EntryDirection.debit,
          amount: const Money(minorUnits: 1200),
        ),
        ReceiptEntry(
          accountId: '2',
          direction: EntryDirection.credit,
          amount: const Money(minorUnits: 1000),
        ),
        ReceiptEntry(
          accountId: '3',
          direction: EntryDirection.credit,
          amount: const Money(minorUnits: 200),
        ),
      ];

      final unbalanced = [
        ReceiptEntry(
          accountId: '1',
          direction: EntryDirection.debit,
          amount: const Money(minorUnits: 1200),
        ),
        ReceiptEntry(
          accountId: '2',
          direction: EntryDirection.credit,
          amount: const Money(minorUnits: 1000),
        ),
      ];

      expect(entriesAreBalanced(balanced), isTrue);
      expect(entriesAreBalanced(unbalanced), isFalse);
    });

    test('restricts detail types by business purpose', () {
      expect(
        detailTypeAllowedForPurpose(
          detailType: TransactionDetailType.primaryExpense,
          businessPurpose: BusinessPurpose.dailyExpense,
        ),
        isTrue,
      );
      expect(
        detailTypeAllowedForPurpose(
          detailType: TransactionDetailType.primaryIncome,
          businessPurpose: BusinessPurpose.dailyExpense,
        ),
        isFalse,
      );
    });
  });
}
