import '../../../core/money/money.dart';

/// One ordered account allocation within an independent transaction dimension.
class AccountAmountAllocation {
  const AccountAmountAllocation({
    required this.accountId,
    required this.amount,
  });

  final String accountId;
  final Money amount;

  AccountAmountAllocation copyWith({String? accountId, Money? amount}) {
    return AccountAmountAllocation(
      accountId: accountId ?? this.accountId,
      amount: amount ?? this.amount,
    );
  }
}

Money sumAllocations(Iterable<AccountAmountAllocation> allocations) {
  return allocations.fold(
    Money.zero(),
    (total, allocation) => total + allocation.amount,
  );
}

List<AccountAmountAllocation> singleAllocation({
  required String accountId,
  required Money amount,
}) {
  return [AccountAmountAllocation(accountId: accountId, amount: amount)];
}

List<AccountAmountAllocation> patchAllocations({
  required List<AccountAmountAllocation> current,
  required Money total,
  List<AccountAmountAllocation>? explicit,
}) {
  if (explicit != null) return explicit;
  if (current.length == 1 && current.single.amount != total) {
    return [current.single.copyWith(amount: total)];
  }
  return current;
}

List<AccountAmountAllocation> subtractAllocations({
  required Iterable<AccountAmountAllocation> base,
  required Iterable<AccountAmountAllocation> reductions,
}) {
  final remainingByAccount = <String, int>{};
  final order = <String>[];
  for (final allocation in base) {
    if (!remainingByAccount.containsKey(allocation.accountId)) {
      order.add(allocation.accountId);
    }
    remainingByAccount[allocation.accountId] =
        (remainingByAccount[allocation.accountId] ?? 0) +
        allocation.amount.minorUnits;
  }
  for (final allocation in reductions) {
    remainingByAccount[allocation.accountId] =
        (remainingByAccount[allocation.accountId] ?? 0) -
        allocation.amount.minorUnits;
  }
  return [
    for (final accountId in order)
      if ((remainingByAccount[accountId] ?? 0) > 0)
        AccountAmountAllocation(
          accountId: accountId,
          amount: Money(minorUnits: remainingByAccount[accountId]!),
        ),
  ];
}

bool allocationsFitAvailable({
  required Iterable<AccountAmountAllocation> requested,
  required Iterable<AccountAmountAllocation> available,
}) {
  final availableByAccount = <String, int>{};
  for (final allocation in available) {
    availableByAccount[allocation.accountId] =
        (availableByAccount[allocation.accountId] ?? 0) +
        allocation.amount.minorUnits;
  }
  final requestedByAccount = <String, int>{};
  for (final allocation in requested) {
    requestedByAccount[allocation.accountId] =
        (requestedByAccount[allocation.accountId] ?? 0) +
        allocation.amount.minorUnits;
  }
  return requestedByAccount.entries.every(
    (entry) => entry.value <= (availableByAccount[entry.key] ?? 0),
  );
}

List<AccountAmountAllocation> replaceAllocationAccount({
  required Iterable<AccountAmountAllocation> allocations,
  required String sourceAccountId,
  required String targetAccountId,
}) {
  final amountByAccount = <String, Money>{};
  final order = <String>[];
  for (final allocation in allocations) {
    final accountId = allocation.accountId == sourceAccountId
        ? targetAccountId
        : allocation.accountId;
    if (!amountByAccount.containsKey(accountId)) order.add(accountId);
    amountByAccount[accountId] =
        (amountByAccount[accountId] ?? Money.zero()) + allocation.amount;
  }
  return [
    for (final accountId in order)
      AccountAmountAllocation(
        accountId: accountId,
        amount: amountByAccount[accountId]!,
      ),
  ];
}
