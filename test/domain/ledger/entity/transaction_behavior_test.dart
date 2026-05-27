import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';

Transaction _build({
  int id = 1,
  BusinessPurpose businessPurpose = BusinessPurpose.dailyExpense,
  BusinessState businessState = BusinessState.current,
  String? note,
  bool isExcludedFromStats = false,
  bool isExcludedFromBudget = false,
  TransactionOwnership? ownership,
  DateTime? occurredAt,
}) {
  return Transaction(
    id: id,
    rootTransactionId: id,
    businessPurpose: businessPurpose,
    occurredAt: occurredAt ?? DateTime(2026, 5, 26),
    primaryAmount: const Money(minorUnits: 1000),
    mutationKind: MutationKind.original,
    businessState: businessState,
    isExcludedFromStats: isExcludedFromStats,
    isExcludedFromBudget: isExcludedFromBudget,
    sourceKind: SourceKind.manual,
    createdAt: DateTime(2026, 5, 26),
    note: note,
    ownership: ownership,
  );
}

void main() {
  group('Transaction.assertCanBeDeleted', () {
    test('passes for current', () {
      expect(_build().assertCanBeDeleted(), isNull);
    });

    test('rejects replaced', () {
      expect(
        _build(businessState: BusinessState.replaced)
            .assertCanBeDeleted()
            ?.code,
        'transaction_not_current',
      );
    });

    test('rejects canceled', () {
      expect(
        _build(businessState: BusinessState.canceled)
            .assertCanBeDeleted()
            ?.code,
        'transaction_not_current',
      );
    });
  });

  group('Transaction.assertCanBeCorrectedAs', () {
    test('passes for current + matching purpose + no children', () {
      expect(
        _build().assertCanBeCorrectedAs(
          BusinessPurpose.dailyExpense,
          hasActiveChildren: false,
        ),
        isNull,
      );
    });

    test('rejects non-current', () {
      expect(
        _build(businessState: BusinessState.replaced)
            .assertCanBeCorrectedAs(
              BusinessPurpose.dailyExpense,
              hasActiveChildren: false,
            )
            ?.code,
        'transaction_not_current',
      );
    });

    test('rejects purpose mismatch', () {
      expect(
        _build()
            .assertCanBeCorrectedAs(
              BusinessPurpose.dailyIncome,
              hasActiveChildren: false,
            )
            ?.code,
        'transaction_correction_purpose_mismatch',
      );
    });

    test('rejects when has active children', () {
      expect(
        _build()
            .assertCanBeCorrectedAs(
              BusinessPurpose.dailyExpense,
              hasActiveChildren: true,
            )
            ?.code,
        'transaction_has_children',
      );
    });
  });

  group('Transaction.assertCanBeBasicsUpdated', () {
    test('passes for current', () {
      expect(_build().assertCanBeBasicsUpdated(), isNull);
    });

    test('rejects non-current', () {
      expect(
        _build(businessState: BusinessState.canceled)
            .assertCanBeBasicsUpdated()
            ?.code,
        'transaction_not_current',
      );
    });
  });

  group('Transaction.updatedMetadata', () {
    test('null patch keeps current note and flags', () {
      final updated = _build(note: 'hello').updatedMetadata();
      expect(updated.note, 'hello');
      expect(updated.isExcludedFromStats, isFalse);
      expect(updated.isExcludedFromBudget, isFalse);
    });

    test('Patch.set replaces note', () {
      final updated = _build(
        note: 'old',
      ).updatedMetadata(note: const Patch.set('new'));
      expect(updated.note, 'new');
    });

    test('Patch.set with empty string clears note', () {
      final updated = _build(
        note: 'old',
      ).updatedMetadata(note: const Patch.set(''));
      expect(updated.note, isNull);
    });

    test('Patch.clear clears note', () {
      final updated = _build(
        note: 'old',
      ).updatedMetadata(note: const Patch.clear());
      expect(updated.note, isNull);
    });

    test('bool flags only replace when non-null', () {
      final updated = _build().updatedMetadata(
        isExcludedFromStats: true,
        isExcludedFromBudget: true,
      );
      expect(updated.isExcludedFromStats, isTrue);
      expect(updated.isExcludedFromBudget, isTrue);
    });
  });

  group('Transaction.updatedOwnership', () {
    test('replaces ownership', () {
      const newOwnership = TransactionOwnership(
        ownerType: 'credit_installment',
        ownerId: '7',
        ownerRole: 'schedule_repayment',
      );
      final updated = _build().updatedOwnership(newOwnership);
      expect(updated.ownership, newOwnership);
    });
  });

  group('Transaction.withOccurredAt', () {
    test('replaces occurredAt', () {
      final updated = _build().withOccurredAt(DateTime(2027, 1, 1));
      expect(updated.occurredAt, DateTime(2027, 1, 1));
    });
  });
}
