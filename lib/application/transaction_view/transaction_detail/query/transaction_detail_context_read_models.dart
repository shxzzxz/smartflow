import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../business_activity/query/business_activity_read_models.dart';
import '../../business_activity_item/query/business_activity_item_read_models.dart';

export '../../business_activity_item/query/business_activity_item_read_models.dart';

/// Minimal parent facts needed by child detail presentation and operations.
final class TransactionParentFacts {
  const TransactionParentFacts({
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    this.isAdvanceClosed = false,
  });

  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final bool isAdvanceClosed;
}

/// Read-side facts for the concrete transaction opened by the detail route.
final class TransactionDetailContext {
  const TransactionDetailContext({
    required this.transaction,
    this.parentFacts,
    this.businessItem,
    this.isAmortizationTerminated = false,
  });

  /// The transaction referenced by `/transaction/:transactionId`.
  final TransactionReadModel transaction;

  /// Parent facts inherited by a child transaction.
  final TransactionParentFacts? parentFacts;

  /// Business meaning and local facts for the concrete transaction.
  final BusinessActivityItem? businessItem;

  /// The local projection for the transaction opened by the detail route.
  BusinessActivityItemProjection? get transactionProjection =>
      businessItem?.projectionFor(transaction.id);

  /// Minimal operation constraint for amortization transactions.
  final bool isAmortizationTerminated;

  bool get isChild => transaction.parentTransactionId != null;
}

/// Detail projection assembled after the local context has decided whether
/// an activity-level read model is required.
final class TransactionDetailReadModel {
  const TransactionDetailReadModel({
    required this.context,
    this.businessActivity,
  });

  final TransactionDetailContext context;
  final BusinessActivityReadModel? businessActivity;
}
