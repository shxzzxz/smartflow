import '../../../../core/money/money.dart';
import '../../../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';

class CreateAmortizationPlanCommand {
  CreateAmortizationPlanCommand({
    required this.kind,
    required this.total,
    required List<AccountAmountAllocation> fundingAllocations,
    required this.deferralAccountId,
    required List<AccountAmountAllocation> recognitionAllocations,
    required this.firstRecognitionAt,
    required this.cadenceUnit,
    required this.cadenceInterval,
    required this.recognitionCount,
    required this.occurredAt,
    this.initialIsExcludedFromStats = false,
    this.initialIsExcludedFromBudget = false,
    this.feeAmount,
    this.initialCounterpartyId,
    this.initialNote,
    this.tagIds = const {},
  }) : fundingAllocations = List.unmodifiable(fundingAllocations),
       recognitionAllocations = List.unmodifiable(recognitionAllocations);

  final AmortizationKind kind;
  final Money total;
  final List<AccountAmountAllocation> fundingAllocations;
  final String deferralAccountId;
  final List<AccountAmountAllocation> recognitionAllocations;
  final DateTime firstRecognitionAt;
  final AmortizationCadenceUnit cadenceUnit;
  final int cadenceInterval;
  final int recognitionCount;
  final DateTime occurredAt;
  final bool initialIsExcludedFromStats;
  final bool initialIsExcludedFromBudget;
  final Money? feeAmount;
  final String? initialCounterpartyId;
  final String? initialNote;
  final Set<String> tagIds;
}

class CreateAmortizationRefundCommand {
  CreateAmortizationRefundCommand({
    required this.planId,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required this.occurredAt,
    this.postedAt,
  }) : categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final String planId;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final DateTime occurredAt;
  final DateTime? postedAt;
}

class TerminateAmortizationPlanCommand {
  TerminateAmortizationPlanCommand({
    required this.planId,
    required this.terminatedAt,
    required List<AccountAmountAllocation> categoryReturnAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
  }) : categoryReturnAllocations = List.unmodifiable(categoryReturnAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  final String planId;
  final DateTime terminatedAt;
  final List<AccountAmountAllocation> categoryReturnAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
}
