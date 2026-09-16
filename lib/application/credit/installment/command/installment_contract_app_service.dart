import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_contract_origination_service.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'installment_command.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';
import '../../settlement/settlement_app_service.dart';

abstract interface class InstallmentContractAppService {
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  );

  Future<void> updateContractDetails(UpdateContractDetailsCommand command);

  /// 删除合同：仅允许无提前还款且所有计划均未发生还款的合同。
  Future<void> deleteContract(DeleteContractCommand command);
}

class InstallmentContractAppServiceImpl
    implements InstallmentContractAppService {
  InstallmentContractAppServiceImpl({
    required InstallmentRepository repository,
    required BillRepository bills,
    required RepaymentRepository repayments,
    required CreditLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    InstallmentContractOriginationService origination =
        const InstallmentContractOriginationService(),
    InstallmentLifecycleService lifecycle = const InstallmentLifecycleService(),
    RepaymentPolicyService repaymentPolicy = const RepaymentPolicyService(),
  }) : _repository = repository,
       _bills = bills,
       _repayments = repayments,
       _ledger = ledger,
       _runner = transactionRunner,
       _idGenerator = idGenerator,
       _origination = origination,
       _lifecycle = lifecycle,
       _repaymentPolicy = repaymentPolicy,
       _repaymentSettlement = SettlementAppService(
         bills: bills,
         repayments: repayments,
         installments: repository,
       );

  final InstallmentRepository _repository;
  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;
  final InstallmentContractOriginationService _origination;
  final InstallmentLifecycleService _lifecycle;
  final RepaymentPolicyService _repaymentPolicy;
  final SettlementAppService _repaymentSettlement;

  @override
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) async {
    return _runner.run<CreateContractResult>(() async {
      final inputTerms = command.stageTerms;
      final stageTerms = InstallmentContractTerms(
        dayCount: inputTerms.dayCount,
        rounding: inputTerms.rounding,
        stages: [
          for (final stage in inputTerms.stages)
            InstallmentContractStage(
              id: _idGenerator.newId(),
              terms: stage.terms,
            ),
        ],
      );
      final disbursementAccountId = command.disbursementAccountId;
      final borrowing = disbursementAccountId == null
          ? null
          : await _ledger.postBorrowing(
              CreditLedgerPostBorrowingCommand(
                amount: command.principal,
                liabilityAccountId: command.liabilityAccountId,
                occurredAt: command.borrowingDate,
                receiveAccountId: disbursementAccountId,
                counterpartyName: command.counterpartyName,
                note: command.note,
              ),
            );
      final now = DateTime.now();
      final contractId = _idGenerator.newId();
      final aggregate = _origination.originateDisbursement(
        contractId: contractId,
        liabilityAccountId: command.liabilityAccountId,
        disbursementAccountId: disbursementAccountId,
        disbursementTransactionId: borrowing?.transactionId,
        terms: InstallmentOriginationTerms(
          name: command.name,
          principal: command.principal,
          borrowingDate: command.borrowingDate,
          note: command.note,
          stageTerms: stageTerms,
        ),
        createdAt: now,
        newScheduleId: _idGenerator.newId,
      );
      await _repository.insertAggregate(
        aggregate.contract,
        aggregate.schedules,
      );
      if (borrowing != null) {
        await _ledger.updateOwnership(
          transactionId: borrowing.transactionId,
          ownership: _installmentOwnership(
            contractId,
            InstallmentOwnerRole.disbursement,
          ),
        );
      }
      return CreateContractResult(
        contractId: contractId,
        disbursementTransactionId: borrowing?.transactionId,
      );
    });
  }

  @override
  Future<void> updateContractDetails(UpdateContractDetailsCommand command) =>
      _runner.run(() async {
        final contract = await _repository.findContract(command.contractId) ??
            (throw BusinessException(CreditErrorCode.contractNotFound));
        contract.reviseDetails(
          name: command.name,
          borrowingDate: command.borrowingDate,
          note: command.note,
          disbursementAccountId: command.disbursementAccountId,
        );
        await _synchronizeBorrowing(
          contract,
          command,
        );
        final schedules = await _repository.listSchedules(command.contractId);
        await _repository.saveAggregate(contract, schedules);
      });

  Future<void> _synchronizeBorrowing(
    InstallmentContract contract,
    UpdateContractDetailsCommand command,
  ) async {
    if (contract.sourceType != InstallmentSourceType.disbursement) return;
    final txId = contract.disbursementTransactionId;
    if (txId == null) return;
    if (command.disbursementAccountId != null ||
        command.borrowingDate != null) {
      await _ledger.editBorrowing(
        CreditLedgerEditBorrowingCommand(
          transactionId: txId,
          receiveAccountId: command.disbursementAccountId,
          occurredAt: command.borrowingDate,
        ),
      );
    }
    if (command.note != null) {
      await _ledger.updateBasicInfo(
        CreditLedgerUpdateBasicInfoCommand(
          transactionId: txId,
          note: _nullableStringPatch(command.note),
        ),
      );
    }
  }

  Patch<String?>? _nullableStringPatch(Patch<String>? patch) {
    return switch (patch) {
      null => null,
      PatchSet<String>(:final value) => Patch<String?>.set(value),
      PatchClear<String>() => const Patch<String?>.clear(),
    };
  }

  @override
  Future<void> deleteContract(DeleteContractCommand command) async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }

    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      command.contractId,
    );
    final schedules = await _repository.listSchedules(command.contractId);
    _lifecycle.validateDelete(repayments: repayments, schedules: schedules);

    return _runner.run<void>(() async {
      final sourceRepaymentId = contract.sourceRepaymentId;
      if (sourceRepaymentId != null) {
        final sourceRepayment = await _repayments.findRepayment(
          sourceRepaymentId,
        );
        if (sourceRepayment != null) {
          final sourceBill = await _bills.findBill(sourceRepayment.targetId);
          if (sourceBill == null) {
            throw BusinessException(CreditErrorCode.billNotFound);
          }
          final allocations = _repaymentPolicy.allocationsFromItems(
            sourceRepayment.items,
          );
          await _repayments.deleteRepayment(sourceRepayment.id);
          await _repaymentSettlement.refreshBillStatuses(
            sourceBill,
            allocations,
          );
        }
      }
      final disbursementTransactionId = contract.disbursementTransactionId;
      if (disbursementTransactionId != null) {
        await _ledger.deleteTransaction(disbursementTransactionId);
      }
      await _removeContractBillItems(contract);
      await _repository.deleteContract(command.contractId);
    });
  }

  Future<void> _removeContractBillItems(InstallmentContract contract) async {
    final bills = await _bills.listBillsByAccount(contract.liabilityAccountId);
    for (final bill in bills) {
      final retained = [
        for (final item in bill.items)
          if (item.contractId != contract.id) item,
      ];
      if (retained.length == bill.items.length) continue;
      await _bills.replaceBillItems(bill.id, retained);
      if (bill.status == BillStatus.open) {
        bill.refreshOpenProjection(window: bill.window!, sourceItems: retained);
      } else {
        bill.synchronizeBilledItems(retained);
      }
      await _bills.updateBill(bill);
    }
  }

  CreditLedgerOwnership _installmentOwnership(
    String contractId,
    InstallmentOwnerRole role,
  ) {
    return CreditLedgerOwnership(
      ownerType: installmentOwnerType,
      ownerId: contractId,
      ownerRole: role.wireValue,
    );
  }
}

