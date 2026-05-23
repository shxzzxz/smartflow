import '../../../core/money/money.dart';
import 'transaction_scope.dart';

class TransactionListQuery {
  const TransactionListQuery({
    this.accountId,
    this.occurredFrom,
    this.occurredUntil,
    this.topLevelOnly = true,
    this.limit = 50,
    this.offset = 0,
    this.scope = TransactionScopeFilter.assetLiability,
  });

  final int? accountId;
  final DateTime? occurredFrom;
  final DateTime? occurredUntil;
  final bool topLevelOnly;
  final int limit;
  final int offset;
  final TransactionScopeFilter scope;
}

class CashflowSummaryQuery {
  const CashflowSummaryQuery({
    required this.occurredFrom,
    required this.occurredUntil,
    this.currencyCode = Money.defaultCurrency,
  });

  final DateTime occurredFrom;
  final DateTime occurredUntil;
  final String currencyCode;
}
