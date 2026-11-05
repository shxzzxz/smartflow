import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';

class CreateDisbursementInstallmentCommand {
  const CreateDisbursementInstallmentCommand({
    this.name,
    required this.liabilityAccountId,
    required this.principal,
    required this.borrowingDate,
    this.disbursementAccountId,
    this.note,
    this.counterpartyId,
    required this.stageTerms,
  });

  final String liabilityAccountId;
  final String? name;

  /// 放款入账账户。为空时只记录分期与计划，不创建借入交易。
  final String? disbursementAccountId;
  final Money principal;

  /// 借款日期，同时作为借入交易的业务时间。
  final DateTime borrowingDate;

  final String? note;
  final String? counterpartyId;
  final InstallmentContractTerms stageTerms;
}

class DisbursementInstallmentResult {
  const DisbursementInstallmentResult({
    required this.contractId,
    this.disbursementTransactionId,
  });

  /// 分期与合同共用的稳定身份。
  final String contractId;
  final String? disbursementTransactionId;
}
