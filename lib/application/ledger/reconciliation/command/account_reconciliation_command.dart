class ConfirmAccountReconciliationCommand {
  ConfirmAccountReconciliationCommand({
    required this.accountId,
    required DateTime from,
    required DateTime untilInclusive,
  }) : from = DateTime(from.year, from.month, from.day),
       untilInclusive = DateTime(
         untilInclusive.year,
         untilInclusive.month,
         untilInclusive.day,
       );

  final String accountId;
  final DateTime from;
  final DateTime untilInclusive;
}
