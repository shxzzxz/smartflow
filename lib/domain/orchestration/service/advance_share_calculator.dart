import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_violation_reason.dart';

import '../valobj/advance_enums.dart';

abstract interface class AdvanceSharePolicy {
  AdvanceShareSplit splitForEntry({
    required AdvanceScenario scenario,
    required Money total,
    required int aaPeopleCount,
    required List<AccountAmountAllocation> categoryAllocations,
  });

  AdvanceRefundSplit splitForRefund({
    required AdvanceScenario scenario,
    required TransactionGroup group,
    required Money refundAmount,
    required List<AccountAmountAllocation> refundCategoryAllocations,
    Money? parentTotal,
    Money? advanceAmount,
    int? aaPeopleCount,
    String? excludingRefundTransactionId,
  });

  int inferAaPeopleCount({required Money total, required Money advanceAmount});
}

class AdvanceShareCalculator implements AdvanceSharePolicy {
  const AdvanceShareCalculator();

  @override
  AdvanceShareSplit splitForEntry({
    required AdvanceScenario scenario,
    required Money total,
    required int aaPeopleCount,
    required List<AccountAmountAllocation> categoryAllocations,
  }) {
    final participants = scenario == AdvanceScenario.aa
        ? aaPeopleCount.clamp(2, 99).toInt()
        : null;
    final advanceAmount = participants == null
        ? total
        : _aaAdvanceAmount(total: total, peopleCount: participants);
    final selfBorneAmount = total - advanceAmount;
    return AdvanceShareSplit(
      advanceAmount: advanceAmount,
      selfBorneAmount: selfBorneAmount,
      selfBorneAllocations: _allocateProportionally(
        amount: selfBorneAmount,
        allocations: categoryAllocations,
      ),
      aaPeopleCount: participants,
    );
  }

  @override
  AdvanceRefundSplit splitForRefund({
    required AdvanceScenario scenario,
    required TransactionGroup group,
    required Money refundAmount,
    required List<AccountAmountAllocation> refundCategoryAllocations,
    Money? parentTotal,
    Money? advanceAmount,
    int? aaPeopleCount,
    String? excludingRefundTransactionId,
  }) {
    final parent = group.parentTransaction;
    if (parent.businessPurpose != BusinessPurpose.advance) {
      return AdvanceRefundSplit(
        selfBorneAmount: Money.zero(),
        advanceAmount: refundAmount,
        selfBorneAllocations: const [],
      );
    }

    final previouslyRefundedTotal = group.refundedTotal(
      excludingTransactionId: excludingRefundTransactionId,
    );
    final previouslyRefundedSelfBorne = group.childTransactions
        .where(
          (child) =>
              child.businessPurpose == BusinessPurpose.refund &&
              child.id != excludingRefundTransactionId,
        )
        .fold(
          Money.zero(),
          (total, child) =>
              total +
              (child.amountOf(TransactionRole.advanceSelfBorne) ??
                  Money.zero()),
        );
    final total = parentTotal ?? parent.primaryAmount;
    final remainingTotal = total - previouslyRefundedTotal;
    if (refundAmount.minorUnits > remainingTotal.minorUnits) {
      LedgerViolationReason.refundExceedsRemaining.throwException();
    }

    final receivableAmount =
        advanceAmount ??
        parent.amountOf(TransactionRole.receivable) ??
        parent.primaryAmount;
    final originalSelfBorne = total - receivableAmount;
    final participants = scenario == AdvanceScenario.aa
        ? aaPeopleCount ??
              inferAaPeopleCount(total: total, advanceAmount: receivableAmount)
        : null;
    final currentSelfBorne = participants == null
        ? _nonNegative(originalSelfBorne - previouslyRefundedSelfBorne)
        : _aaSelfBorneAmount(total: remainingTotal, peopleCount: participants);
    final remainingAfterRefund = remainingTotal - refundAmount;
    final nextSelfBorne = participants == null
        ? _nonNegative(currentSelfBorne - refundAmount)
        : _aaSelfBorneAmount(
            total: remainingAfterRefund,
            peopleCount: participants,
          );
    final aaSelfBorneRefund = _nonNegative(currentSelfBorne - nextSelfBorne);
    final proportionalSelfBorneRefund = remainingTotal.minorUnits <= 0
        ? Money.zero()
        : Money(
            minorUnits:
                refundAmount.minorUnits *
                currentSelfBorne.minorUnits ~/
                remainingTotal.minorUnits,
          );
    final selfBorneAmount = _clampMoney(
      participants == null ? proportionalSelfBorneRefund : aaSelfBorneRefund,
      min: Money.zero(),
      max: refundAmount,
    );
    return AdvanceRefundSplit(
      selfBorneAmount: selfBorneAmount,
      advanceAmount: refundAmount - selfBorneAmount,
      selfBorneAllocations: _allocateProportionally(
        amount: selfBorneAmount,
        allocations: refundCategoryAllocations,
      ),
      aaPeopleCount: participants,
    );
  }

  @override
  int inferAaPeopleCount({required Money total, required Money advanceAmount}) {
    for (var people = 2; people <= 99; people++) {
      if (_aaAdvanceAmount(total: total, peopleCount: people) ==
          advanceAmount) {
        return people;
      }
    }
    final selfBorne = total - advanceAmount;
    if (selfBorne.minorUnits <= 0 || total.minorUnits <= 0) return 2;
    return (total.minorUnits / selfBorne.minorUnits)
        .round()
        .clamp(2, 99)
        .toInt();
  }

  Money _aaAdvanceAmount({required Money total, required int peopleCount}) {
    final people = peopleCount.clamp(2, 99).toInt();
    final perPersonMinorUnits = (total.minorUnits + people - 1) ~/ people;
    return Money(minorUnits: perPersonMinorUnits * (people - 1));
  }

  Money _aaSelfBorneAmount({required Money total, required int peopleCount}) {
    return _nonNegative(
      total - _aaAdvanceAmount(total: total, peopleCount: peopleCount),
    );
  }

  List<AccountAmountAllocation> _allocateProportionally({
    required Money amount,
    required List<AccountAmountAllocation> allocations,
  }) {
    if (amount.minorUnits <= 0 || allocations.isEmpty) return const [];
    final baseTotal = sumAllocations(allocations);
    if (baseTotal.minorUnits <= 0) return const [];

    final result = <AccountAmountAllocation>[];
    var remaining = amount.minorUnits;
    for (var index = 0; index < allocations.length; index++) {
      final allocation = allocations[index];
      final isLast = index == allocations.length - 1;
      final allocated = isLast
          ? remaining
          : (amount.minorUnits *
                    allocation.amount.minorUnits ~/
                    baseTotal.minorUnits)
                .clamp(0, remaining);
      if (allocated > 0) {
        result.add(
          AccountAmountAllocation(
            accountId: allocation.accountId,
            amount: Money(minorUnits: allocated),
          ),
        );
      }
      remaining -= allocated;
    }
    return result;
  }

  Money _nonNegative(Money value) {
    return value.minorUnits < 0 ? Money.zero() : value;
  }

  Money _clampMoney(Money value, {required Money min, required Money max}) {
    if (value.minorUnits < min.minorUnits) return min;
    if (value.minorUnits > max.minorUnits) return max;
    return value;
  }
}

class AdvanceShareSplit {
  const AdvanceShareSplit({
    required this.advanceAmount,
    required this.selfBorneAmount,
    required this.selfBorneAllocations,
    this.aaPeopleCount,
  });

  final Money advanceAmount;
  final Money selfBorneAmount;
  final List<AccountAmountAllocation> selfBorneAllocations;
  final int? aaPeopleCount;
}

class AdvanceRefundSplit {
  const AdvanceRefundSplit({
    required this.selfBorneAmount,
    required this.advanceAmount,
    required this.selfBorneAllocations,
    this.aaPeopleCount,
  });

  final Money selfBorneAmount;
  final Money advanceAmount;
  final List<AccountAmountAllocation> selfBorneAllocations;
  final int? aaPeopleCount;
}
