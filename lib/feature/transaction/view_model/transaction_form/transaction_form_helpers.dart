import '../../../../application/ledger/ledger_query_api.dart';
import '../../../../core/money/money.dart';

String? effectiveAccountId(String? selectedId, List<Account> options) {
  if (selectedId != null &&
      options.any((account) => account.id == selectedId)) {
    return selectedId;
  }
  return options.isEmpty ? null : options.first.id;
}

String? selectedAccountId(String? selectedId, List<Account> options) {
  if (selectedId != null &&
      options.any((account) => account.id == selectedId)) {
    return selectedId;
  }
  return null;
}

List<AccountAmountAllocation> fitAllocationsToTotal(
  List<AccountAmountAllocation> allocations,
  Money total,
) {
  if (allocations.isEmpty) return const [];
  if (allocations.length == 1) {
    return [allocations.single.copyWith(amount: total)];
  }
  final currentTotal = sumAllocations(allocations);
  final difference = total.minorUnits - currentTotal.minorUnits;
  final adjusted = [...allocations];
  if (difference >= 0) {
    final last = adjusted.last;
    adjusted[adjusted.length - 1] = last.copyWith(
      amount: Money(minorUnits: last.amount.minorUnits + difference),
    );
    return adjusted;
  }
  var remaining = -difference;
  for (var index = adjusted.length - 1; index >= 0 && remaining > 0; index--) {
    final allocation = adjusted[index];
    final reduction = remaining < allocation.amount.minorUnits
        ? remaining
        : allocation.amount.minorUnits;
    adjusted[index] = allocation.copyWith(
      amount: Money(minorUnits: allocation.amount.minorUnits - reduction),
    );
    remaining -= reduction;
  }
  return [
    for (final allocation in adjusted)
      if (allocation.amount.minorUnits > 0) allocation,
  ];
}
