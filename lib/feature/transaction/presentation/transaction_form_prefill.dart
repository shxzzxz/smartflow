import '../../../core/money/money.dart';

/// Prepared initial values, applied once when the transaction form opens.
class TransactionFormPrefill {
  const TransactionFormPrefill({
    this.amount,
    required this.occurredAt,
    required this.note,
    required this.reviewMessage,
    this.settlementAccountId,
    this.fromAccountId,
    this.toAccountId,
    this.categoryId,
    this.counterpartyId,
  });

  final Money? amount;
  final DateTime occurredAt;
  final String note;
  final String reviewMessage;
  final String? settlementAccountId;
  final String? fromAccountId;
  final String? toAccountId;
  final String? categoryId;
  final String? counterpartyId;
}
