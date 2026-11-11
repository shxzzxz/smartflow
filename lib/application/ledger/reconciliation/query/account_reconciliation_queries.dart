/// Inclusive account reconciliation date range.
final class AccountReconciliationQuery {
  AccountReconciliationQuery({
    required this.accountId,
    required DateTime from,
    required DateTime untilInclusive,
  }) : from = _dateOnly(from),
       untilExclusive = _dateOnly(untilInclusive).add(const Duration(days: 1)) {
    if (accountId.isEmpty || !untilExclusive.isAfter(this.from)) {
      throw ArgumentError('Invalid account reconciliation range.');
    }
  }

  final String accountId;
  final DateTime from;

  /// Exclusive query boundary used by transaction date filtering.
  final DateTime untilExclusive;

  DateTime get untilInclusive =>
      untilExclusive.subtract(const Duration(days: 1));

  @override
  bool operator ==(Object other) {
    return other is AccountReconciliationQuery &&
        other.accountId == accountId &&
        other.from == from &&
        other.untilExclusive == untilExclusive;
  }

  @override
  int get hashCode => Object.hash(accountId, from, untilExclusive);
}

int reconciliationDateKey(DateTime value) {
  return value.year * 10000 + value.month * 100 + value.day;
}

DateTime reconciliationDateFromKey(int value) {
  return DateTime(value ~/ 10000, (value ~/ 100) % 100, value % 100);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
