import '../../../../core/money/money.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';

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
    this.owner,
  });

  /// The transaction referenced by `/transaction/:transactionId`.
  final TransactionReadModel transaction;

  /// The parent when [transaction] is a child.
  final TransactionReadModel? parentTransaction;

  /// The group containing [transaction].
  final TransactionDetailGroup currentGroup;

  /// The group containing the business-item anchor transaction.
  ///
  /// This differs from [currentGroup] for amortization recognition entries:
  /// the anchor remains the plan's initial transaction.
  final TransactionDetailGroup anchorGroup;

  final TransactionDetailOwnerContext? owner;

  TransactionReadModel get anchorTransaction => anchorGroup.anchor;

  bool get isChild => transaction.parentTransactionId != null;
}

/// Business facts associated with the transaction owner.
///
/// Feature code selects a concrete module by this type instead of combining
/// advance, installment, repayment and amortization query providers itself.
sealed class TransactionDetailOwnerContext {
  const TransactionDetailOwnerContext({
    required this.ownerType,
    required this.ownerId,
  });

  final String ownerType;
  final String ownerId;
}

final class AdvanceTransactionDetailOwnerContext
    extends TransactionDetailOwnerContext {
  const AdvanceTransactionDetailOwnerContext({
    required super.ownerType,
    required super.ownerId,
    required this.scenario,
    required this.trackingMode,
    required this.advanceAmount,
    required this.receivedAmount,
    required this.outstanding,
    required this.isClosed,
    this.aaPeopleCount,
  });

  final AdvanceScenario scenario;
  final AdvanceTrackingMode trackingMode;
  final Money advanceAmount;
  final Money receivedAmount;
  final Money outstanding;
  final bool isClosed;
  final int? aaPeopleCount;
}

final class InstallmentTransactionDetailOwnerContext
    extends TransactionDetailOwnerContext {
  const InstallmentTransactionDetailOwnerContext({
    required super.ownerType,
    required super.ownerId,
    required this.installmentType,
    required this.status,
    required this.principal,
    required this.remainingPrincipal,
    required this.paidPeriodCount,
    required this.totalPeriodCount,
  });

  final InstallmentType installmentType;
  final InstallmentContractStatus status;
  final Money principal;
  final Money remainingPrincipal;
  final int paidPeriodCount;
  final int totalPeriodCount;
}

final class RepaymentTransactionDetailOwnerContext
    extends TransactionDetailOwnerContext {
  const RepaymentTransactionDetailOwnerContext({
    required super.ownerType,
    required super.ownerId,
    required this.repaymentType,
    required this.targetType,
    required this.targetId,
  });

  final RepaymentType repaymentType;
  final RepaymentTargetType targetType;
  final String targetId;
}

final class AmortizationTransactionDetailOwnerContext
    extends TransactionDetailOwnerContext {
  const AmortizationTransactionDetailOwnerContext({
    required super.ownerType,
    required super.ownerId,
    required this.initialTransactionId,
    required this.kind,
    required this.status,
    required this.originalAmount,
    required this.recognizedAmount,
    required this.remainingAmount,
    required this.postedPeriodCount,
    required this.totalPeriodCount,
    this.currentPeriodSequence,
    this.currentPeriodDueAt,
    this.currentPeriodAmount,
  });

  final String initialTransactionId;
  final AmortizationKind kind;
  final AmortizationStatus status;
  final Money originalAmount;
  final Money recognizedAmount;
  final Money remainingAmount;
  final int postedPeriodCount;
  final int totalPeriodCount;
  final int? currentPeriodSequence;
  final DateTime? currentPeriodDueAt;
  final Money? currentPeriodAmount;
}

final class UnknownTransactionDetailOwnerContext
    extends TransactionDetailOwnerContext {
  const UnknownTransactionDetailOwnerContext({
    required super.ownerType,
    required super.ownerId,
  });
}
