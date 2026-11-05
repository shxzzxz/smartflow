import 'package:smartflow/application/credit/installment/port/installment_plan_change_port.dart';
import 'package:smartflow/application/credit/repayment/command/repayment_command.dart';
import 'package:smartflow/application/credit/repayment/command/repayment_transaction_support.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart'
    as domain_repayment;
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

/// 以一笔分期为目标的提前还款能力。
abstract interface class InstallmentPrepaymentAppService {
  Future<CreateRepaymentResult> createContractPrepaymentRepayment(
    CreateContractPrepaymentRepaymentCommand command,
  );

  Future<void> editRepaymentTransaction(
    EditCreditRepaymentTransactionCommand command,
  );

  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command);
}

class InstallmentPrepaymentAppServiceImpl
    implements InstallmentPrepaymentAppService {
  InstallmentPrepaymentAppServiceImpl({
    required BillRepository bills,
    required RepaymentRepository repayments,
    required InstallmentRepository installments,
    required CreditLedgerPort ledger,
    required InstallmentPlanChangePort plans,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    domain_repayment.RepaymentPolicyService repaymentPolicy =
        const domain_repayment.RepaymentPolicyService(),
  }) : _repayments = repayments,
       _installments = installments,
       _plans = plans,
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator,
       _repaymentPolicy = repaymentPolicy,
       _transactions = RepaymentTransactionSupport(
         bills: bills,
         repayments: repayments,
         installments: installments,
         ledger: ledger,
       );

  final RepaymentRepository _repayments;
  final InstallmentRepository _installments;
  final InstallmentPlanChangePort _plans;
  final TransactionRunner _transactionRunner;
  final IdGenerator _idGenerator;
  final domain_repayment.RepaymentPolicyService _repaymentPolicy;
  final RepaymentTransactionSupport _transactions;

  @override
  Future<CreateRepaymentResult> createContractPrepaymentRepayment(
    CreateContractPrepaymentRepaymentCommand command,
  ) async {
    final contract = await _installments.findContract(command.contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }
    final repaymentId = _idGenerator.newId();
    final total = repaymentAmountBreakdown(command.amount);
    _repaymentPolicy.validateActiveContractRepayment(
      contract: contract,
      total: total,
    );

    return _transactionRunner.run(() async {
      final post = await _transactions.postIfNeeded(
        liabilityAccountId: contract.liabilityAccountId,
        repaymentId: repaymentId,
        total: total,
        transactionInfo: command.transactionInfo,
        note: command.note,
      );
      final repayment = Repayment(
        id: repaymentId,
        repaymentType: RepaymentType.prepayment,
        targetType: RepaymentTargetType.contract,
        targetId: contract.id,
        transactionId: post?.transactionId,
        repaymentDate: requireRepaymentDate(
          command.transactionInfo?.occurredAt ?? command.repaymentDate,
        ),
        items: [
          RepaymentItem(
            id: _idGenerator.newId(),
            repaymentId: repaymentId,
            allocated: total,
          ),
        ],
      )..validateAgainstLedgerTransaction(total);
      await _repayments.saveRepayment(repayment);
      if (total.principal.minorUnits > 0) {
        await _plans.applyAutomaticChange(
          contract.id,
          const RecalculateFromOperations(),
        );
      }
      return CreateRepaymentResult(
        repaymentId: repaymentId,
        transactionId: post?.transactionId,
      );
    });
  }

  @override
  Future<void> editRepaymentTransaction(
    EditCreditRepaymentTransactionCommand command,
  ) {
    return _transactionRunner.run(() async {
      final repayment = await _transactions.requireRepayment(
        repaymentId: command.repaymentId,
        transactionId: command.transactionId,
        allowedTypes: const {RepaymentType.prepayment},
      );
      await _transactions.editTransaction(repayment, command);
    });
  }

  @override
  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command) async {
    final repayment = await _transactions.requireRepayment(
      repaymentId: command.repaymentId,
      transactionId: command.transactionId,
      allowedTypes: const {RepaymentType.prepayment},
    );
    final contract = await _installments.findContract(repayment.targetId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    final changesPrincipal =
        repayment.totalAllocated().principal.minorUnits > 0;
    final transaction = await _transactions.loadParentTransaction(repayment);
    return _transactionRunner.run<void>(() async {
      await _transactions.deleteParentTransaction(transaction);
      await _repayments.deleteRepayment(repayment.id);
      if (changesPrincipal) {
        await _plans.applyAutomaticChange(
          contract.id,
          const RecalculateFromOperations(),
        );
      }
    });
  }
}
