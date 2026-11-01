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
    this.defaultIsExcludedFromStats = false,
    this.defaultIsExcludedFromBudget = false,
    this.feeAmount,
    this.counterpartyId,
    this.note,
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
  final bool defaultIsExcludedFromStats;
  final bool defaultIsExcludedFromBudget;
  final Money? feeAmount;
  final String? counterpartyId;
  final String? note;
  final Set<String> tagIds;
}

class TerminateAmortizationPlanCommand {
  const TerminateAmortizationPlanCommand({
    required this.planId,
    required this.terminatedAt,
    required this.refundAccountId,
    required this.refundAmount,
    this.recognitionCategoryAccountId,
    this.refundFeeAmount,
    this.note,
  });

  final String planId;
  final DateTime terminatedAt;
  final String refundAccountId;
  final Money refundAmount;
  final String? recognitionCategoryAccountId;
  final Money? refundFeeAmount;
  final String? note;
}

class UpdateAmortizationReportingDefaultsCommand {
  const UpdateAmortizationReportingDefaultsCommand({
    required this.planId,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
    required this.scope,
  });

  final String planId;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
  final AmortizationReportingScope scope;
}

class UpdateAmortizationTransactionReportingCommand {
  const UpdateAmortizationTransactionReportingCommand({
    required this.planId,
    required this.transactionId,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
  });

  final String planId;
  final String transactionId;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}
