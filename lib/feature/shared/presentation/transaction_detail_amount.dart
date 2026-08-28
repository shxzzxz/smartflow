import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';

Money sumTransactionLineAmount(
  TransactionReadModel detail,
  TransactionRole role,
) {
  var amountMinor = 0;
  for (final line in detail.lines) {
    if (line.role == role) amountMinor += line.amount.minorUnits;
  }
  return Money(minorUnits: amountMinor);
}
