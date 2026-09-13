import '../../../../core/money/money.dart';
import '../../../../core/time/date_label.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';
import '../../../../domain/credit/valobj/floating_rate.dart';
import '../../../../domain/credit/valobj/installment_plan_operation.dart';

class InstallmentContractReadModel {
  const InstallmentContractReadModel({
    required this.id,
    String? name,
    required this.liabilityAccountId,
    required this.sourceType,
    required this.principal,
    required this.borrowingDate,
    required this.status,
    required this.createdAt,
    this.disbursementAccountId,
    this.disbursementTransactionId,
    this.sourceRepaymentId,
    this.note,
    required this.stageTerms,
    this.productId,
    this.productName,
    this.customRules = false,
    this.unconfirmedRepricingIds = const [],
    this.repricingConfigurations = const [],
    this.repricings = const [],
    this.interestAdjustments = const [],
  }) : _name = name;

  final String id;
  final String? _name;
  String get name => _name ?? formatCompactDate(borrowingDate);
  final String liabilityAccountId;
  final InstallmentSourceType sourceType;
  final String? disbursementAccountId;
  final String? disbursementTransactionId;
  final String? sourceRepaymentId;
  final Money principal;
  final DateTime borrowingDate;
  final InstallmentContractStatus status;
  final String? note;
  final DateTime createdAt;
  final InstallmentContractTerms stageTerms;
  final String? productId;
  final String? productName;
  final bool customRules;
  final List<String> unconfirmedRepricingIds;
  final List<InstallmentRepricingConfigurationReadModel>
  repricingConfigurations;
  final List<InstallmentRepricingReadModel> repricings;
  final List<InstallmentInterestAdjustmentReadModel> interestAdjustments;
  int get totalPeriods => stageTerms.totalPeriods;
  DateTime get firstRepaymentDate => stageTerms.firstDate;
  DateTime get lastRepaymentDate => stageTerms.lastDate;
  int get totalFeeMinor => stageTerms.totalFeeMinor;
}

class InstallmentRepricingConfigurationReadModel {
  const InstallmentRepricingConfigurationReadModel({
    required this.id,
    required this.stageId,
    required this.effectiveFrom,
    required this.rule,
  });
  final String id;
  final DateTime effectiveFrom;
  final FloatingRateRule rule;
  final String stageId;
}

class InstallmentRepricingReadModel {
  const InstallmentRepricingReadModel({
    required this.id,
    required this.stageId,
    required this.change,
    required this.status,
  });
  final String id;
  final RateChange change;
  final String stageId;
  final InstallmentRepricingStatus status;
}

class InstallmentInterestAdjustmentReadModel {
  const InstallmentInterestAdjustmentReadModel({
    required this.id,
    required this.adjustment,
  });
  final String id;
  final InterestAdjustment adjustment;
}

class InstallmentScheduleReadModel {
  const InstallmentScheduleReadModel({
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
