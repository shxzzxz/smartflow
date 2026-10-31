import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import '../repayment_amount_dto.dart';
import 'repayment_command.dart';

/// 各还款目标 module 共享的账务交易读写能力。
///
/// 业务目标的加载与状态联动仍由具体 module 负责；这里只收口与目标无关的
/// 交易发布、编辑、删除和账户定位逻辑。
class RepaymentTransactionSupport {
  const RepaymentTransactionSupport({
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentRepository installments,
    required CreditLedgerPort ledger,
  }) : _bills = bills,
       _repayments = repayments,
       _installments = installments,
       _ledger = ledger;

  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final InstallmentRepository _installments;
  final CreditLedgerPort _ledger;

  Future<Repayment> requireRepayment({
    required String? repaymentId,
    required String? transactionId,
    required Set<RepaymentType> allowedTypes,
  }) async {
    if ((repaymentId == null) == (transactionId == null)) {
      throw BusinessException(CreditErrorCode.repaymentInvalidCommand);
    }
    final repayment = repaymentId != null
        ? await _repayments.findRepayment(repaymentId)
        : await _repayments.findByTransaction(transactionId!);
    if (repayment == null) {
      throw BusinessException(CreditErrorCode.repaymentNotFound);
    }
    if (!allowedTypes.contains(repayment.repaymentType)) {
      throw BusinessException(
        CreditErrorCode.repaymentNotEditable,
        message: 'Repayment target is owned by another repayment module.',
      );
    }
    return repayment;
  }

  Future<void> editTransaction(
    Repayment repayment,
    EditCreditRepaymentTransactionCommand command,
  ) async {
    repayment.ensureBillItemReferences();
    final transactionId = repayment.transactionId;
    if (transactionId == null) {
      throw BusinessException(CreditErrorCode.repaymentNotEditable);
    }
    final detail = await _currentParentTransaction(transactionId);

    if (command.paidFromAccountId == null) {
      await _ledger.updateBasicInfo(
        CreditLedgerUpdateBasicInfoCommand(
          transactionId: detail.transactionId,
          occurredAt: command.occurredAt,
          note: command.note,
        ),
      );
    } else {
      final liabilityAccountId = await _liabilityAccountIdForRepayment(
        repayment,
      );
      await _ledger.editRepayment(
        CreditLedgerEditRepaymentCommand(
          transactionId: detail.transactionId,
          amount: repayment.totalAllocated(),
          liabilityAccountId: liabilityAccountId,
          paidFromAccountId: command.paidFromAccountId,
          occurredAt: command.occurredAt ?? repayment.repaymentDate,
          note: command.note,
        ),
      );
    }
    if (command.occurredAt != null) {
      repayment.reviseRepaymentDate(command.occurredAt!);
      await _repayments.updateRepayment(repayment);
    }
  }

  Future<CreditLedgerTransactionSnapshot?> loadParentTransaction(
    Repayment repayment,
  ) {
    final transactionId = repayment.transactionId;
    if (transactionId == null) return Future.value(null);
    return _currentParentTransaction(transactionId);
  }

  Future<CreditLedgerRepaymentSnapshot?> findRepaymentTransaction(
    String transactionId,
  ) {
    return _ledger.findRepaymentTransaction(transactionId);
  }

  Future<void> deleteParentTransaction(
    CreditLedgerTransactionSnapshot? transaction,
  ) async {
    if (transaction == null) return;
    await _ledger.deleteTransaction(transaction.transactionId);
  }

  Future<CreditLedgerPostedTransaction?> postIfNeeded({
    required String liabilityAccountId,
    required String repaymentId,
    required RepaymentAmountBreakdown total,
    required RepaymentTransactionInfo? transactionInfo,
    required String? note,
  }) {
    if (transactionInfo == null) return Future.value(null);
    return post(
      liabilityAccountId: liabilityAccountId,
      repaymentId: repaymentId,
      total: total,
      transactionInfo: transactionInfo,
      note: note,
    );
  }

  Future<CreditLedgerPostedTransaction> post({
    required String liabilityAccountId,
    required String repaymentId,
    required RepaymentAmountBreakdown total,
    required RepaymentTransactionInfo transactionInfo,
    required String? note,
  }) {
    return _ledger.postRepayment(
      CreditLedgerPostRepaymentCommand(
        amount: total,
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: transactionInfo.paidFromAccountId,
        occurredAt: transactionInfo.occurredAt,
        counterpartyId: transactionInfo.counterpartyId,
        note: transactionInfo.note ?? note,
        ownership: CreditLedgerOwnership(
          ownerType: creditRepaymentOwnerType,
          ownerId: repaymentId,
        ),
      ),
    );
  }

  Future<CreditLedgerPostedTransaction> editRepayment({
    required String transactionId,
    required RepaymentAmountBreakdown amount,
    required String liabilityAccountId,
    required String paidFromAccountId,
    required DateTime occurredAt,
    Patch<String?>? note,
  }) {
    return _ledger.editRepayment(
      CreditLedgerEditRepaymentCommand(
        transactionId: transactionId,
        amount: amount,
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: paidFromAccountId,
        occurredAt: occurredAt,
        note: note,
      ),
    );
  }

  Future<CreditLedgerTransactionSnapshot> _currentParentTransaction(
    String transactionId,
  ) async {
    final detail = await _ledger.findParentTransaction(transactionId);
    if (detail == null) {
      throw BusinessException(
        CreditErrorCode.repaymentNotFound,
        message: 'Current repayment transaction does not exist.',
      );
    }
    return detail;
  }

  Future<String> _liabilityAccountIdForRepayment(Repayment repayment) async {
    switch (repayment.targetType) {
      case RepaymentTargetType.account:
        return repayment.targetId;
      case RepaymentTargetType.bill:
        final bill = await _bills.findBill(repayment.targetId);
        if (bill == null) throw BusinessException(CreditErrorCode.billNotFound);
        return bill.accountId;
      case RepaymentTargetType.contract:
        final contract = await _installments.findContract(repayment.targetId);
        if (contract == null) {
          throw BusinessException(CreditErrorCode.contractNotFound);
        }
        return contract.liabilityAccountId;
    }
  }
}

RepaymentAmountBreakdown repaymentAmountBreakdown(RepaymentAmountDto amount) {
  return RepaymentAmountBreakdown(
    principal: amount.principal,
    interest: amount.interest,
    fee: amount.fee,
    discount: amount.discount,
  );
}

DateTime requireRepaymentDate(DateTime? value) {
  if (value == null) {
    throw BusinessException(
      CreditErrorCode.repaymentInvalidCommand,
      message: 'Repayment must carry a repayment date.',
    );
  }
  return value;
}
