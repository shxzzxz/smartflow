import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../business_context/query/transaction_business_context_read_models.dart';

export '../../business_context/query/transaction_business_context_read_models.dart';

/// The current transaction group used by one detail entry.
///
/// [anchor] is always the top-level transaction. For a child entry the group is
/// loaded through its parent, so child transactions never masquerade as anchors.
final class TransactionDetailGroup {
  TransactionDetailGroup({
    required this.anchor,
    Iterable<TransactionReadModel> children = const [],
  }) : children = List.unmodifiable(children);

  final TransactionReadModel anchor;
  final List<TransactionReadModel> children;

  List<TransactionReadModel> get transactions => [anchor, ...children];
}

/// Read-side facts for the concrete transaction opened by the detail route.
final class TransactionDetailContext {
  const TransactionDetailContext({
    required this.transaction,
    required this.currentGroup,
    required this.anchorGroup,
    this.parentTransaction,
    this.businessContext,
  });

  /// The transaction referenced by `/transaction/:transactionId`.
  final TransactionReadModel transaction;

  /// The parent when [transaction] is a child.
  final TransactionReadModel? parentTransaction;

  /// The group containing [transaction].
  final TransactionDetailGroup currentGroup;

  /// The group containing the business-activity anchor transaction.
  ///
  /// This differs from [currentGroup] for amortization recognition entries:
  /// the anchor remains the plan's initial transaction.
  final TransactionDetailGroup anchorGroup;

  final TransactionBusinessContext? businessContext;

  TransactionReadModel get anchorTransaction => anchorGroup.anchor;

  bool get isChild => transaction.parentTransactionId != null;

  Iterable<String> get categoryAccountIds => switch (businessContext) {
    AmortizationTransactionBusinessContext(:final categoryAccountIds) =>
      categoryAccountIds,
    _ => const [],
  };
}
