import '../../../core/money/money.dart';
import '../valobj/ledger_enum.dart';

class Entry {
  const Entry({
    required this.id,
    required this.transactionId,
    required this.accountId,
    required this.direction,
    required this.amount,
  });

  final String id;
  final String transactionId;
  final String accountId;
  final EntryDirection direction;
  final Money amount;
}
