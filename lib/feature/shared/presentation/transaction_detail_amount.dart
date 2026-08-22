import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';

Money sumTransactionDetailAmount(
  TransactionDetail detail,
  TransactionDetailType type,
) {
  var amountMinor = 0;
  for (final line in detail.details) {
    if (line.type == type) amountMinor += line.amount.minorUnits;
  }
  return Money(minorUnits: amountMinor);
}
