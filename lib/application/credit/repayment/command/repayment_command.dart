import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';

import '../repayment_amount_dto.dart';

class RepaymentTransactionInfo {
  const RepaymentTransactionInfo({
    required this.paidFromAccountId,
    required this.occurredAt,
    this.counterpartyId,
    this.note,
  });

  final String paidFromAccountId;
  final DateTime occurredAt;
  final String? counterpartyId;
  final String? note;
}

class BillRepaymentAllocation {
  const BillRepaymentAllocation({
    required this.billItemId,
    required this.allocated,
  });

  final String billItemId;
  final RepaymentAmountDto allocated;
}

class CreateBillRepaymentCommand {
  const CreateBillRepaymentCommand({
    required this.billId,
    required this.allocations,
    this.transactionInfo,
    this.repaymentDate,
    this.note,
  });

  final String billId;
  final List<BillRepaymentAllocation> allocations;
  final RepaymentTransactionInfo? transactionInfo;

  /// 无交易还款的时间输入；有交易时使用 transactionInfo.occurredAt 并同步保存。
  final DateTime? repaymentDate;
  final String? note;
}

class EditBillRepaymentCommand {
  const EditBillRepaymentCommand({
    required this.repaymentId,
    required this.allocations,
    this.transactionInfo,
    this.repaymentDate,
    this.note,
  });

  final String repaymentId;
  final List<BillRepaymentAllocation> allocations;
  final RepaymentTransactionInfo? transactionInfo;

  /// 无交易还款的时间输入；为空表示不改，有交易时使用 transactionInfo.occurredAt。
  final DateTime? repaymentDate;
  final String? note;
}

/// 编辑时须展示已失去明细关联的历史分项；提交命令仍要求有效明细。
class BillRepaymentEditAllocation {
  const BillRepaymentEditAllocation({
    required this.id,
    required this.billItemId,
    required this.allocated,
  });

  final String id;
  final String? billItemId;
  final RepaymentAmountDto allocated;
}

class BillRepaymentEditView {
  const BillRepaymentEditView({
    required this.repaymentId,
    required this.billId,
    required this.allocations,
    required this.hasTransaction,
    this.transactionId,
    this.paidFromAccountId,
    this.occurredAt,
    this.note,
  });

  final String repaymentId;
  final String billId;
  final List<BillRepaymentEditAllocation> allocations;
  final bool hasTransaction;
  final String? transactionId;
  final String? paidFromAccountId;
  final DateTime? occurredAt;
  final String? note;
}

class CreateBillConversionInstallmentRepaymentCommand {
  const CreateBillConversionInstallmentRepaymentCommand({
    this.contractName,
    required this.billId,
    required this.allocations,
    required this.borrowingDate,
    required this.stageTerms,
    this.note,
  });
  final String billId;
  final String? contractName;
  final List<BillRepaymentAllocation> allocations;
  final DateTime borrowingDate;
  final InstallmentContractTerms stageTerms;
  final String? note;
}

class CreateContractPrepaymentRepaymentCommand {
  const CreateContractPrepaymentRepaymentCommand({
    required this.contractId,
    required this.amount,
    this.transactionInfo,
    this.repaymentDate,
    this.note,
  });

  final String contractId;
  final RepaymentAmountDto amount;
  final RepaymentTransactionInfo? transactionInfo;

  /// 无交易提前还款的时间输入；有交易时使用 transactionInfo.occurredAt 并同步保存。
  final DateTime? repaymentDate;
  final String? note;
}

class CreateUnattributedRepaymentCommand {
  const CreateUnattributedRepaymentCommand({
    required this.accountId,
    required this.amount,
    required this.transactionInfo,
    this.note,
  });

  final String accountId;
  final RepaymentAmountDto amount;
  final RepaymentTransactionInfo transactionInfo;
  final String? note;
}

class CreateRepaymentResult {
  const CreateRepaymentResult({
    required this.repaymentId,
    this.transactionId,
    this.contractId,
  });

  final String repaymentId;
  final String? transactionId;
  final String? contractId;
}

class DeleteCreditRepaymentCommand {
  const DeleteCreditRepaymentCommand({this.repaymentId, this.transactionId});

  final String? repaymentId;
  final String? transactionId;
}

class EditCreditRepaymentTransactionCommand {
  const EditCreditRepaymentTransactionCommand({
    this.repaymentId,
    this.transactionId,
    this.paidFromAccountId,
    this.occurredAt,
    this.note,
  });

  final String? repaymentId;
  final String? transactionId;
  final String? paidFromAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? note;
}
