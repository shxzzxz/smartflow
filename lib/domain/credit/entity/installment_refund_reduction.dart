import '../../../core/money/money.dart';

/// A refund amount applied to the remaining principal of a PURCHASE contract.
class InstallmentRefundReduction {
  const InstallmentRefundReduction({
    required this.id,
    required this.contractId,
    required this.refundTransactionId,
    required this.principal,
    required this.occurredAt,
    required this.createdAt,
  });

  final String id;
  final String contractId;
  final String refundTransactionId;
  final Money principal;

  /// Business time read from the linked ledger refund transaction.
  final DateTime occurredAt;
  final DateTime createdAt;
}
