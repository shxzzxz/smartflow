import '../../../../core/money/money.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';

/// Business facts associated with the transaction owner.
///
/// Feature code selects a concrete module by this type instead of combining
/// advance, installment, repayment and amortization query providers itself.
sealed class TransactionBusinessContext {
  const TransactionBusinessContext({
    required this.ownerType,
    required this.ownerId,
  });

  final String ownerType;
  final String ownerId;
}

final class AdvanceTransactionBusinessContext
    extends TransactionBusinessContext {
  const AdvanceTransactionBusinessContext({
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

final class InstallmentTransactionBusinessContext
    extends TransactionBusinessContext {
  const InstallmentTransactionBusinessContext({
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

final class RepaymentTransactionBusinessContext
    extends TransactionBusinessContext {
  const RepaymentTransactionBusinessContext({
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

final class AmortizationTransactionBusinessContext
    extends TransactionBusinessContext {
  const AmortizationTransactionBusinessContext({
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
    this.categoryAccountIds = const [],
    this.occurrencePeriodSequence,
    this.occurrencePeriodDueAt,
    this.currentPeriodSequence,
    this.currentPeriodDueAt,
    this.currentPeriodAmount,
    this.factKind,
    this.refundId,
    this.terminationId,
  });

  final String initialTransactionId;
  final AmortizationKind kind;
  final AmortizationStatus status;
  final Money originalAmount;
  final Money recognizedAmount;
  final Money remainingAmount;
  final int postedPeriodCount;
  final int totalPeriodCount;
  final List<String> categoryAccountIds;
  final int? occurrencePeriodSequence;
  final DateTime? occurrencePeriodDueAt;
  final int? currentPeriodSequence;
  final DateTime? currentPeriodDueAt;
  final Money? currentPeriodAmount;
  final AmortizationTransactionFactKind? factKind;
  final String? refundId;
  final String? terminationId;
}

final class UnknownTransactionBusinessContext
    extends TransactionBusinessContext {
  const UnknownTransactionBusinessContext({
    required super.ownerType,
    required super.ownerId,
  });
}
