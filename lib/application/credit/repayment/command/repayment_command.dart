import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

import '../repayment_amount_dto.dart';

class RepaymentTransactionInfo {
  const RepaymentTransactionInfo({
    required this.paidFromAccountId,
    required this.occurredAt,
    this.counterpartyName,
    this.note,
  });

  final String paidFromAccountId;
  final DateTime occurredAt;
  final String? counterpartyName;
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
    this.note,
  });

  final String billId;
  final List<BillRepaymentAllocation> allocations;
  final RepaymentTransactionInfo? transactionInfo;
  final String? note;
}

class CreateBillConversionInstallmentRepaymentCommand {
  const CreateBillConversionInstallmentRepaymentCommand({
    required this.billId,
    required this.allocations,
    required this.totalPeriods,
    required this.repaymentMethod,
    this.borrowingDate,
    this.firstRepaymentDate,
    this.lastRepaymentDate,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.interestAccrualMethod = InterestAccrualMethod.daily,
    this.totalFeeMinor = 0,
    this.equalInstallmentOverrideMinor,
    this.note,
  });

  final String billId;
  final List<BillRepaymentAllocation> allocations;
  final int totalPeriods;
  final DateTime? borrowingDate;
  final DateTime? firstRepaymentDate;
  final DateTime? lastRepaymentDate;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final InterestAccrualMethod interestAccrualMethod;
  final int totalFeeMinor;
  final int? equalInstallmentOverrideMinor;
  final String? note;
}

class CreateContractPrepaymentRepaymentCommand {
  const CreateContractPrepaymentRepaymentCommand({
    required this.contractId,
    required this.amount,
    this.transactionInfo,
    this.note,
  });

  final String contractId;
  final RepaymentAmountDto amount;
  final RepaymentTransactionInfo? transactionInfo;
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
    this.rootTransactionId,
    this.contractId,
  });

  final String repaymentId;
  final String? transactionId;
  final String? rootTransactionId;
  final String? contractId;
}

class DeleteCreditRepaymentCommand {
  const DeleteCreditRepaymentCommand({
    this.repaymentId,
    this.rootTransactionId,
  });

  final String? repaymentId;
  final String? rootTransactionId;
}

class EditCreditRepaymentTransactionCommand {
  const EditCreditRepaymentTransactionCommand({
    this.repaymentId,
    this.rootTransactionId,
    this.paidFromAccountId,
    this.occurredAt,
    this.note,
  });

  final String? repaymentId;
  final String? rootTransactionId;
  final String? paidFromAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? note;
}

class CreateLiabilityRepaymentCommand {
  const CreateLiabilityRepaymentCommand({
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.amount,
    required this.occurredAt,
    this.note,
  });

  final String liabilityAccountId;
  final String paidFromAccountId;
  final RepaymentAmountDto amount;
  final DateTime occurredAt;
  final String? note;
}

class CorrectLiabilityRepaymentCommand {
  const CorrectLiabilityRepaymentCommand({
    required this.transactionId,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.amount,
    required this.occurredAt,
    this.note,
  });

  final String transactionId;
  final String liabilityAccountId;
  final String paidFromAccountId;
  final RepaymentAmountDto amount;
  final DateTime occurredAt;
  final String? note;
}

/// 普通还款编辑视图。把交易 detail / entries 反解出的结构化字段提供给 UI，
/// 避免表单层自己从分录里凑账户与金额。
class LiabilityRepaymentEditView {
  const LiabilityRepaymentEditView({
    required this.amount,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.note,
  });

  final RepaymentAmountDto amount;
  final String liabilityAccountId;
  final String paidFromAccountId;
  final DateTime occurredAt;
  final String? note;
}

enum LiabilityRepaymentEditViewLoadStatus { loaded, notFound, notEditable }

class LiabilityRepaymentEditViewLoadResult {
  const LiabilityRepaymentEditViewLoadResult._({
    required this.status,
    this.view,
  });

  const LiabilityRepaymentEditViewLoadResult.loaded(
    LiabilityRepaymentEditView view,
  ) : this._(status: LiabilityRepaymentEditViewLoadStatus.loaded, view: view);

  const LiabilityRepaymentEditViewLoadResult.notFound()
    : this._(status: LiabilityRepaymentEditViewLoadStatus.notFound);

  const LiabilityRepaymentEditViewLoadResult.notEditable()
    : this._(status: LiabilityRepaymentEditViewLoadStatus.notEditable);

  final LiabilityRepaymentEditViewLoadStatus status;
  final LiabilityRepaymentEditView? view;
}
