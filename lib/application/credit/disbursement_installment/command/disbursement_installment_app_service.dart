import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_contract_origination_service.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

import '../../installment/command/installment_command.dart';
import '../../installment/command/installment_contract_removal_app_service.dart';
import 'disbursement_installment_command.dart';

abstract interface class DisbursementInstallmentAppService {
  Future<DisbursementInstallmentResult> create(
    CreateDisbursementInstallmentCommand command,
  );

  Future<void> delete(DeleteInstallmentCommand command);
}

class DisbursementInstallmentAppServiceImpl
    implements DisbursementInstallmentAppService {
  DisbursementInstallmentAppServiceImpl({
    required InstallmentRepository installments,
    required BillRepository bills,
    required RepaymentRepository repayments,
    required CreditLedgerPort ledger,
    required TransactionRunner runner,
    required IdGenerator idGenerator,
    InstallmentContractOriginationService origination =
        const InstallmentContractOriginationService(),
  }) : _installments = installments,
       _ledger = ledger,
       _runner = runner,
       _idGenerator = idGenerator,
       _origination = origination,
       _removal = InstallmentContractRemovalAppService(
         installments: installments,
         bills: bills,
         repayments: repayments,
         ledger: ledger,
       );

  final InstallmentRepository _installments;
  final CreditLedgerPort _ledger;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;
  final InstallmentContractOriginationService _origination;
  final InstallmentContractRemovalAppService _removal;

  @override
  Future<DisbursementInstallmentResult> create(
    CreateDisbursementInstallmentCommand command,
  ) {
    return _runner.run(() async {
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
                counterpartyId: command.counterpartyId,
                note: command.note,
              ),
            );
      final contractId = _idGenerator.newId();
      final aggregate = _origination.originateDisbursement(
        contractId: contractId,
        liabilityAccountId: command.liabilityAccountId,
        disbursementTransactionId: borrowing?.transactionId,
        terms: InstallmentOriginationTerms(
          name: command.name,
          principal: command.principal,
          borrowingDate: command.borrowingDate,
          note: command.note,
          stageTerms: stageTerms,
        ),
        createdAt: DateTime.now(),
        newScheduleId: _idGenerator.newId,
      );
      await _installments.insertAggregate(aggregate.contract);
      if (borrowing != null) {
        await _ledger.updateOwnership(
          transactionId: borrowing.transactionId,
          ownership: _installmentOwnership(contractId),
        );
      }
      return DisbursementInstallmentResult(
        contractId: contractId,
        disbursementTransactionId: borrowing?.transactionId,
      );
    });
  }

  @override
  Future<void> delete(DeleteInstallmentCommand command) {
    return _runner.run(() async {
      final contract = await _installments.findContract(command.contractId);
      if (contract == null) {
        throw BusinessException(CreditErrorCode.contractNotFound);
      }
      if (contract.installmentType != InstallmentType.disbursement) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '只有放款分期支持该操作',
        );
      }
      await _removal.remove(contract);
    });
  }

  CreditLedgerOwnership _installmentOwnership(String contractId) {
    return CreditLedgerOwnership(
      ownerType: installmentOwnerType,
      ownerId: contractId,
    );
  }
}
