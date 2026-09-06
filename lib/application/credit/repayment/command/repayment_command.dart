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
  final List<BillRepaymentAllocation> allocations;
  final bool hasTransaction;
  final String? transactionId;
  final String? paidFromAccountId;
  final DateTime? occurredAt;
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

class CreateLiabilityRepaymentCommand {
  const CreateLiabilityRepaymentCommand({
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.amount,
    required this.occurredAt,
    this.note,
    this.tagIds = const {},
  });

  final String liabilityAccountId;
  final String paidFromAccountId;
  final RepaymentAmountDto amount;
  final DateTime occurredAt;
  final String? note;

  /// 交易携带的标签 ID；随入账一并写入。
  final Set<String> tagIds;
}

class EditLiabilityRepaymentCommand {
  const EditLiabilityRepaymentCommand({
    required this.transactionId,
    required this.liabilityAccountId,
    required this.paidFromAccountId,
    required this.amount,
    required this.occurredAt,
    this.note,
    this.tagIds,
  });

  final String transactionId;
  final String liabilityAccountId;
  final String paidFromAccountId;
  final RepaymentAmountDto amount;
  final DateTime occurredAt;
  final String? note;

  /// `null` 表示不改标签；非空集合表示整体替换。
  final Set<String>? tagIds;
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
