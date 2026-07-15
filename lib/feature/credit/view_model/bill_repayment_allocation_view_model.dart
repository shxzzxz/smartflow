import 'dart:math' as math;

import '../../../application/credit/credit_command_api.dart' as credit;
import '../../../core/money/money.dart';

enum BillRepaymentAllocationMode { fifo, equal, manual }

class BillRepaymentAllocationLine {
  const BillRepaymentAllocationLine({
    required this.billItemId,
    required this.itemType,
    required this.expected,
    this.alreadyAllocated = credit.RepaymentAmountDto.zero,
    this.label = '',
  });

  final String billItemId;
  final credit.BillItemType itemType;
  final credit.RepaymentAmountBreakdown expected;
  final credit.RepaymentAmountDto alreadyAllocated;
  final String label;

  int get remainingPrincipal => _remaining(
    expected.principal.minorUnits,
    alreadyAllocated.principal.minorUnits,
  );

  int get remainingInterest => _remaining(
    expected.interest.minorUnits,
    alreadyAllocated.interest.minorUnits,
  );

  int get remainingFee =>
      _remaining(expected.fee.minorUnits, alreadyAllocated.fee.minorUnits);

  static int _remaining(int expected, int allocated) {
    return math.max(0, expected - allocated);
  }
}

class BillRepaymentAllocationViewModel {
  const BillRepaymentAllocationViewModel({required this.lines});

  final List<BillRepaymentAllocationLine> lines;

  BillRepaymentAllocationReview suggest({
    required BillRepaymentAllocationMode mode,
    required credit.RepaymentAmountBreakdown amount,
    List<credit.BillRepaymentAllocation> manualAllocations = const [],
  }) {
    return switch (mode) {
      BillRepaymentAllocationMode.fifo => _fifo(amount),
      BillRepaymentAllocationMode.equal => _equal(amount),
      BillRepaymentAllocationMode.manual => reviewManual(
        amount: amount,
        allocations: manualAllocations,
      ),
    };
  }

  BillRepaymentAllocationReview reviewManual({
    required credit.RepaymentAmountBreakdown amount,
    required List<credit.BillRepaymentAllocation> allocations,
  }) {
    return _review(requested: amount, allocations: allocations);
  }

  BillRepaymentAllocationReview _fifo(credit.RepaymentAmountBreakdown amount) {
    final draft = _MutableAllocationDraft(lines);
    final ordered = _orderedLines();
    _allocateCapped(
      lines: ordered,
      amountMinor: amount.fee.minorUnits,
      remainingFor: (line) => line.remainingFee,
      add: (line, value) => draft.addFee(line.billItemId, value),
    );
    _allocateCapped(
      lines: ordered,
      amountMinor: amount.interest.minorUnits,
      remainingFor: (line) => line.remainingInterest,
      add: (line, value) => draft.addInterest(line.billItemId, value),
    );
    _allocateCapped(
      lines: ordered,
      amountMinor: amount.principal.minorUnits,
      remainingFor: (line) => line.remainingPrincipal,
      add: (line, value) => draft.addPrincipal(line.billItemId, value),
    );
    _allocateUncappedFifo(
      lines: ordered,
      amountMinor: amount.discount.minorUnits,
      add: (line, value) => draft.addDiscount(line.billItemId, value),
    );
    return _review(requested: amount, allocations: draft.toAllocations());
  }

  BillRepaymentAllocationReview _equal(credit.RepaymentAmountBreakdown amount) {
    final draft = _MutableAllocationDraft(lines);
    final ordered = _orderedLines();
    _allocateEqualCapped(
      lines: ordered,
      amountMinor: amount.fee.minorUnits,
      remainingFor: (line) => line.remainingFee,
      add: (line, value) => draft.addFee(line.billItemId, value),
    );
    _allocateEqualCapped(
      lines: ordered,
      amountMinor: amount.interest.minorUnits,
      remainingFor: (line) => line.remainingInterest,
      add: (line, value) => draft.addInterest(line.billItemId, value),
    );
    _allocateEqualCapped(
      lines: ordered,
      amountMinor: amount.principal.minorUnits,
      remainingFor: (line) => line.remainingPrincipal,
      add: (line, value) => draft.addPrincipal(line.billItemId, value),
    );
    _allocateEqualUncapped(
      lines: ordered,
      amountMinor: amount.discount.minorUnits,
      add: (line, value) => draft.addDiscount(line.billItemId, value),
    );
    return _review(requested: amount, allocations: draft.toAllocations());
  }

  List<BillRepaymentAllocationLine> _orderedLines() {
    final indexed = [
      for (var i = 0; i < lines.length; i++) (index: i, line: lines[i]),
    ];
    indexed.sort((left, right) {
      final typeCompare = _itemTypeOrder(
        left.line.itemType,
      ).compareTo(_itemTypeOrder(right.line.itemType));
      if (typeCompare != 0) return typeCompare;
      return left.index.compareTo(right.index);
    });
    return [for (final item in indexed) item.line];
  }

  int _itemTypeOrder(credit.BillItemType type) {
    return switch (type) {
      credit.BillItemType.installment => 0,
      credit.BillItemType.consumption => 1,
    };
  }

  BillRepaymentAllocationReview _review({
    required credit.RepaymentAmountBreakdown requested,
    required List<credit.BillRepaymentAllocation> allocations,
  }) {
    final byId = {for (final line in lines) line.billItemId: line};
    var hasOverAllocation = false;
    for (final allocation in allocations) {
      final line = byId[allocation.billItemId];
      final allocated = allocation.allocated;
      if (line == null || _hasNegativeAmount(allocated)) {
        hasOverAllocation = true;
        continue;
      }
      hasOverAllocation =
          hasOverAllocation ||
          allocated.principal.minorUnits > line.remainingPrincipal ||
          allocated.interest.minorUnits > line.remainingInterest ||
          allocated.fee.minorUnits > line.remainingFee;
    }

    final totalAllocated = _total(allocations);
    return BillRepaymentAllocationReview(
      allocations: List.unmodifiable(allocations),
      requested: requested,
      totalAllocated: totalAllocated,
      unallocated: _subtract(requested, totalAllocated),
      hasOverAllocation: hasOverAllocation,
      warningMessage: hasOverAllocation ? '分摊金额超过应还金额，保存后多还部分会进入溢缴。' : null,
    );
  }
}

class BillRepaymentAllocationReview {
  const BillRepaymentAllocationReview({
    required this.allocations,
    required this.requested,
    required this.totalAllocated,
    required this.unallocated,
    required this.hasOverAllocation,
    this.warningMessage,
  });

  final List<credit.BillRepaymentAllocation> allocations;
  final credit.RepaymentAmountBreakdown requested;
  final credit.RepaymentAmountBreakdown totalAllocated;
  final credit.RepaymentAmountBreakdown unallocated;
  final bool hasOverAllocation;
  final String? warningMessage;
}

class _MutableAllocationDraft {
  _MutableAllocationDraft(List<BillRepaymentAllocationLine> lines)
    : _items = {for (final line in lines) line.billItemId: _MutableBreakdown()},
      _order = [for (final line in lines) line.billItemId];

  final Map<String, _MutableBreakdown> _items;
  final List<String> _order;

  void addPrincipal(String billItemId, int minor) {
    _items[billItemId]!.principal += minor;
  }

  void addInterest(String billItemId, int minor) {
    _items[billItemId]!.interest += minor;
  }

  void addFee(String billItemId, int minor) {
    _items[billItemId]!.fee += minor;
  }

  void addDiscount(String billItemId, int minor) {
    _items[billItemId]!.discount += minor;
  }

  List<credit.BillRepaymentAllocation> toAllocations() {
    return [
      for (final id in _order)
        if (!_items[id]!.isZero)
          credit.BillRepaymentAllocation(
            billItemId: id,
            allocated: _items[id]!.toDto(),
          ),
    ];
  }
}

class _MutableBreakdown {
  int principal = 0;
  int interest = 0;
  int fee = 0;
  int discount = 0;

  bool get isZero =>
      principal == 0 && interest == 0 && fee == 0 && discount == 0;

  credit.RepaymentAmountDto toDto() {
    return credit.RepaymentAmountDto(
      principal: Money(minorUnits: principal),
      interest: Money(minorUnits: interest),
      fee: Money(minorUnits: fee),
      discount: Money(minorUnits: discount),
    );
  }
}

void _allocateCapped({
  required List<BillRepaymentAllocationLine> lines,
  required int amountMinor,
  required int Function(BillRepaymentAllocationLine line) remainingFor,
  required void Function(BillRepaymentAllocationLine line, int minor) add,
}) {
  var remaining = math.max(0, amountMinor);
  for (final line in lines) {
    if (remaining == 0) break;
    final allocation = math.min(remaining, remainingFor(line));
    if (allocation <= 0) continue;
    add(line, allocation);
    remaining -= allocation;
  }
}

void _allocateEqualCapped({
  required List<BillRepaymentAllocationLine> lines,
  required int amountMinor,
  required int Function(BillRepaymentAllocationLine line) remainingFor,
  required void Function(BillRepaymentAllocationLine line, int minor) add,
}) {
  var remaining = math.max(0, amountMinor);
  final capacities = {
    for (final line in lines)
      if (remainingFor(line) > 0) line: remainingFor(line),
  };
  while (remaining > 0 && capacities.isNotEmpty) {
    final active = capacities.keys.toList();
    var distributed = 0;
    for (var i = 0; i < active.length; i++) {
      final line = active[i];
      final share =
          remaining ~/ active.length + (i < remaining % active.length ? 1 : 0);
      if (share <= 0) continue;
      final allocation = math.min(capacities[line]!, share);
      if (allocation <= 0) continue;
      add(line, allocation);
      capacities[line] = capacities[line]! - allocation;
      distributed += allocation;
      if (capacities[line] == 0) {
        capacities.remove(line);
      }
    }
    if (distributed == 0) break;
    remaining -= distributed;
  }
}

void _allocateUncappedFifo({
  required List<BillRepaymentAllocationLine> lines,
  required int amountMinor,
  required void Function(BillRepaymentAllocationLine line, int minor) add,
}) {
  if (amountMinor <= 0 || lines.isEmpty) return;
  add(lines.first, amountMinor);
}

void _allocateEqualUncapped({
  required List<BillRepaymentAllocationLine> lines,
  required int amountMinor,
  required void Function(BillRepaymentAllocationLine line, int minor) add,
}) {
  if (amountMinor <= 0 || lines.isEmpty) return;
  for (var i = 0; i < lines.length; i++) {
    final share =
        amountMinor ~/ lines.length + (i < amountMinor % lines.length ? 1 : 0);
    if (share > 0) add(lines[i], share);
  }
}

credit.RepaymentAmountBreakdown _total(
  List<credit.BillRepaymentAllocation> allocations,
) {
  return allocations.fold(
    credit.RepaymentAmountBreakdown.zero,
    (sum, allocation) =>
        sum +
        credit.RepaymentAmountBreakdown(
          principal: allocation.allocated.principal,
          interest: allocation.allocated.interest,
          fee: allocation.allocated.fee,
          discount: allocation.allocated.discount,
        ),
  );
}

credit.RepaymentAmountBreakdown _subtract(
  credit.RepaymentAmountBreakdown left,
  credit.RepaymentAmountBreakdown right,
) {
  return credit.RepaymentAmountBreakdown(
    principal: left.principal - right.principal,
    interest: left.interest - right.interest,
    fee: left.fee - right.fee,
    discount: left.discount - right.discount,
  );
}

bool _hasNegativeAmount(credit.RepaymentAmountDto amount) {
  return amount.principal.minorUnits < 0 ||
      amount.interest.minorUnits < 0 ||
      amount.fee.minorUnits < 0 ||
      amount.discount.minorUnits < 0;
}
