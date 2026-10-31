import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

import '../repayment_amount_dto.dart';
import 'repayment_command.dart';
import 'repayment_transaction_support.dart';

/// 应付账户的临时专用入口，后续由账务核心直接承接。
abstract interface class LiabilityRepaymentAppService {
  Future<CreditLedgerPostedTransaction> createLiabilityRepayment(
    CreateLiabilityRepaymentCommand command,
  );

  Future<CreditLedgerPostedTransaction> editLiabilityRepayment(
    EditLiabilityRepaymentCommand command,
  );

  Future<LiabilityRepaymentEditViewLoadResult> loadLiabilityRepaymentEditView(
    String transactionId,
  );
}

class LiabilityRepaymentAppServiceImpl implements LiabilityRepaymentAppService {
  const LiabilityRepaymentAppServiceImpl({
    required CreditLedgerPort ledger,
    required InstallmentRepository installments,
  }) : _ledger = ledger,
       _installments = installments;

  final CreditLedgerPort _ledger;
  final InstallmentRepository _installments;

  @override
  Future<CreditLedgerPostedTransaction> createLiabilityRepayment(
    CreateLiabilityRepaymentCommand command,
  ) async {
    await _validateLiabilityRepaymentPrincipal(
      liabilityAccountId: command.liabilityAccountId,
      principal: command.amount.principal,
    );

    return _ledger.postRepayment(
      CreditLedgerPostRepaymentCommand(
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
        amount: repaymentAmountBreakdown(command.amount),
        note: command.note,
        tagIds: command.tagIds,
      ),
    );
  }

  @override
  Future<CreditLedgerPostedTransaction> editLiabilityRepayment(
    EditLiabilityRepaymentCommand command,
  ) async {
    final snapshot = await _ledger.findRepaymentTransaction(
      command.transactionId,
    );
    if (snapshot == null) {
      throw BusinessException(
        CreditErrorCode.repaymentNotFound,
        message: 'Repayment transaction does not exist.',
      );
    }
    if (!snapshot.isDebtRepayment) {
      throw BusinessException(
        CreditErrorCode.repaymentNotEditable,
        message: 'LiabilityRepaymentAppService only handles DEBT_REPAYMENT.',
      );
    }

    await _validateLiabilityRepaymentPrincipal(
      liabilityAccountId: command.liabilityAccountId,
      principal: command.amount.principal,
      editingRepaymentSnapshot: snapshot,
    );

    return _ledger.editRepayment(
      CreditLedgerEditRepaymentCommand(
        transactionId: command.transactionId,
        amount: repaymentAmountBreakdown(command.amount),
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
        note: command.note == null
            ? const Patch<String?>.clear()
            : Patch<String?>.set(command.note),
        tagIds: command.tagIds,
      ),
    );
  }

  @override
  Future<LiabilityRepaymentEditViewLoadResult> loadLiabilityRepaymentEditView(
    String transactionId,
  ) async {
    final snapshot = await _ledger.findRepaymentTransaction(transactionId);
    if (snapshot == null) {
      return const LiabilityRepaymentEditViewLoadResult.notFound();
    }
    if (!snapshot.isDebtRepayment) {
      return const LiabilityRepaymentEditViewLoadResult.notEditable();
    }

    Money? principal;
    Money? interest;
    Money? fee;
    Money? discount;
    for (final line in snapshot.details) {
      switch (line.type) {
        case CreditLedgerRepaymentDetailType.principal:
          principal = line.amount;
        case CreditLedgerRepaymentDetailType.interest:
          interest = line.amount;
        case CreditLedgerRepaymentDetailType.fee:
          fee = line.amount;
        case CreditLedgerRepaymentDetailType.discount:
          discount = line.amount;
      }
    }
    if (principal == null) {
      return const LiabilityRepaymentEditViewLoadResult.notEditable();
    }

    final liabilityAccountId = _firstAccountId(
      snapshot,
      accountKind: CreditLedgerAccountKind.liability,
      direction: CreditLedgerEntryDirection.debit,
    );
    final paidFromAccountId = _firstSettlementAccountId(snapshot);
    if (liabilityAccountId == null || paidFromAccountId == null) {
      return const LiabilityRepaymentEditViewLoadResult.notEditable();
    }

    return LiabilityRepaymentEditViewLoadResult.loaded(
      LiabilityRepaymentEditView(
        amount: RepaymentAmountDto(
          principal: principal,
          interest: interest ?? Money.zero(),
          fee: fee ?? Money.zero(),
          discount: discount ?? Money.zero(),
        ),
        liabilityAccountId: liabilityAccountId,
        paidFromAccountId: paidFromAccountId,
        occurredAt: snapshot.occurredAt,
        note: snapshot.note,
      ),
    );
  }

  Future<void> _validateLiabilityRepaymentPrincipal({
    required String liabilityAccountId,
    required Money principal,
    CreditLedgerRepaymentSnapshot? editingRepaymentSnapshot,
  }) async {
    if (principal.minorUnits <= 0) return;
    if (editingRepaymentSnapshot?.ownerType == installmentOwnerType) return;

    final account = await _ledger.findAccount(liabilityAccountId);
    if (account == null) return;

    var oldPrincipalMinor = 0;
    if (editingRepaymentSnapshot != null) {
      for (final detail in editingRepaymentSnapshot.details) {
        if (detail.type == CreditLedgerRepaymentDetailType.principal) {
          oldPrincipalMinor += detail.amount.minorUnits;
        }
      }
    }

    final debtMinor = account.balance.minorUnits + oldPrincipalMinor;
    final unpaidMinor = await _unpaidInstallmentPrincipalMinor(
      liabilityAccountId,
    );
    final availableMinor = debtMinor - unpaidMinor;
    if (principal.minorUnits > availableMinor) {
      final clamped = availableMinor < 0 ? 0 : availableMinor;
      throw BusinessException(
        CreditErrorCode.repaymentExceedsAvailable,
        message: '本金超过可还额度（${Money(minorUnits: clamped).format()}），剩余请通过分期合同还款',
      );
    }
  }

  Future<int> _unpaidInstallmentPrincipalMinor(
    String liabilityAccountId,
  ) async {
    final contracts = await _installments.listContractsByLiabilityAccount(
      liabilityAccountId,
    );
    var sum = 0;
    for (final contract in contracts) {
      if (contract.status != InstallmentContractStatus.active) continue;
      sum += contract.schedules
          .where(
            (schedule) => schedule.status == InstallmentScheduleStatus.pending,
          )
          .fold<int>(
            0,
            (total, schedule) => total + schedule.expectedPrincipal.minorUnits,
          );
    }
    return sum;
  }

  String? _firstAccountId(
    CreditLedgerRepaymentSnapshot snapshot, {
    required CreditLedgerAccountKind accountKind,
    required CreditLedgerEntryDirection direction,
  }) {
    for (final entry in snapshot.entries) {
      if (entry.accountKind == accountKind && entry.direction == direction) {
        return entry.accountId;
      }
    }
    return null;
  }

  String? _firstSettlementAccountId(CreditLedgerRepaymentSnapshot snapshot) {
    for (final entry in snapshot.entries) {
      if (entry.direction != CreditLedgerEntryDirection.credit) continue;
      final kind = entry.accountKind;
      if (kind == CreditLedgerAccountKind.asset ||
          kind == CreditLedgerAccountKind.liability) {
        return entry.accountId;
      }
    }
    return null;
  }
}
