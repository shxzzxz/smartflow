import '../../../../core/money/money.dart';
import '../../../../domain/credit/valobj/floating_rate.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/installment_plan_operation.dart';
import '../../../../domain/credit/valobj/rate_change.dart';
import '../../../../domain/credit/valobj/repayment_amount_breakdown.dart';

class InstallmentDTO {
  const InstallmentDTO({
    required this.id,
    required this.name,
    required this.liabilityAccountId,
    required this.installmentType,
    this.sourceRefId,
    required this.principal,
    required this.borrowingDate,
    required this.status,
    required this.createdAt,
    this.disbursementAccountId,
    this.note,
    required this.stageTerms,
    required this.repaymentProgress,
  });

  final String id;
  final String name;
  final String liabilityAccountId;
  final InstallmentType installmentType;
  final String? sourceRefId;

  /// Derived from the source borrowing transaction; never persisted on the
  /// installment.
  final String? disbursementAccountId;
  final Money principal;
  final DateTime borrowingDate;
  final InstallmentContractStatus status;
  final String? note;
  final DateTime createdAt;
  final InstallmentContractTerms stageTerms;
  final InstallmentRepaymentProgressDTO repaymentProgress;
}

class InstallmentDetailDTO {
  InstallmentDetailDTO({
    required this.installment,
    required Iterable<InstallmentScheduleDTO> schedules,
  }) : schedules = List.unmodifiable(schedules);

  final InstallmentDTO installment;
  final List<InstallmentScheduleDTO> schedules;
}

class InstallmentRepaymentProgressDTO {
  const InstallmentRepaymentProgressDTO({
    required this.paidPeriodCount,
    required this.totalPeriodCount,
    required this.remainingPrincipal,
    required this.repaid,
  });

  final int paidPeriodCount;
  final int totalPeriodCount;
  final Money remainingPrincipal;

  /// 已发生的还款分摊，包含合同级提前还款；退款还本不在此金额内。
  final RepaymentAmountBreakdown repaid;
}

class InstallmentRepricingDTO {
  InstallmentRepricingDTO({
    required this.installmentId,
    required Iterable<InstallmentRepricingConfigurationDTO> configurations,
    required Iterable<InstallmentRepricingRecordDTO> records,
  }) : configurations = List.unmodifiable(configurations),
       records = List.unmodifiable(records);

  final String installmentId;
  final List<InstallmentRepricingConfigurationDTO> configurations;
  final List<InstallmentRepricingRecordDTO> records;

  List<String> get unconfirmedRecordIds => List.unmodifiable([
    for (final record in records)
      if (record.status == InstallmentRepricingStatus.applied) record.id,
  ]);
}

class InstallmentInterestAdjustmentDTO {
  InstallmentInterestAdjustmentDTO({
    required this.installmentId,
    required Iterable<InstallmentInterestAdjustmentItemDTO> adjustments,
  }) : adjustments = List.unmodifiable(adjustments);

  final String installmentId;
  final List<InstallmentInterestAdjustmentItemDTO> adjustments;
}

class InstallmentRepricingConfigurationDTO {
  const InstallmentRepricingConfigurationDTO({
    required this.id,
    required this.stageId,
    required this.effectiveFrom,
    required this.rule,
    this.lastGeneratedDate,
    required this.generationCompleted,
  });

  final String id;
  final DateTime effectiveFrom;
  final FloatingRateRule rule;
  final String stageId;
  final DateTime? lastGeneratedDate;
  final bool generationCompleted;
}

class InstallmentRepricingRecordDTO {
  const InstallmentRepricingRecordDTO({
    required this.id,
    required this.stageId,
    required this.change,
    required this.status,
  });

  final String id;
  final String stageId;
  final RateChange change;
  final InstallmentRepricingStatus status;
}

class InstallmentInterestAdjustmentItemDTO {
  const InstallmentInterestAdjustmentItemDTO({
    required this.id,
    required this.adjustment,
  });

  final String id;
  final InterestAdjustment adjustment;
}

class InstallmentScheduleDTO {
  const InstallmentScheduleDTO({
    required this.id,
    required this.contractId,
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
    required this.status,
    required this.createdAt,
    this.note,
    this.stageId,
  });

  final String id;
  final String contractId;
  final String? stageId;
  final int periodNo;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final InstallmentScheduleStatus status;
  final String? note;
  final DateTime createdAt;
}
