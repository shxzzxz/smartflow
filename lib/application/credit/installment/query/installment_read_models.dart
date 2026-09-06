import '../../../../core/money/money.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';

class InstallmentContractReadModel {
  const InstallmentContractReadModel({
    required this.id,
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
  });

  final String id;
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
  int get totalPeriods => stageTerms.totalPeriods;
  DateTime get firstRepaymentDate => stageTerms.firstDate;
  DateTime get lastRepaymentDate => stageTerms.lastDate;
  int get totalFeeMinor => stageTerms.totalFeeMinor;
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
