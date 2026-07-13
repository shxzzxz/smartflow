import '../../../../core/money/money.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';

class InstallmentContractReadModel {
  const InstallmentContractReadModel({
    required this.id,
    required this.liabilityAccountId,
    required this.sourceType,
    required this.principal,
    required this.totalPeriods,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.lastRepaymentDate,
    required this.repaymentMethod,
    required this.interestAccrualMethod,
    required this.totalFeeMinor,
    required this.status,
    required this.createdAt,
    this.disbursementAccountId,
    this.disbursementTransactionId,
    this.sourceRepaymentId,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.note,
  });

  final String id;
  final String liabilityAccountId;
  final InstallmentSourceType sourceType;
  final String? disbursementAccountId;
  final String? disbursementTransactionId;
  final String? sourceRepaymentId;
  final Money principal;
  final int totalPeriods;
  final DateTime borrowingDate;
  final DateTime firstRepaymentDate;
  final DateTime lastRepaymentDate;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final InterestAccrualMethod interestAccrualMethod;
  final int totalFeeMinor;
  final InstallmentContractStatus status;
  final String? note;
  final DateTime createdAt;
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
  });

  final String id;
  final String contractId;
  final int periodNo;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
  final InstallmentScheduleStatus status;
  final String? note;
  final DateTime createdAt;
}
