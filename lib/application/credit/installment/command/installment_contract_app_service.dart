import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

import 'installment_command.dart';
import 'installment_contract_removal_app_service.dart';

abstract interface class InstallmentContractAppService {
  Future<void> updateContractDetails(UpdateContractDetailsCommand command);

  /// 账单分期的删除入口在账单还款 module 落地前暂由合同维护用例承接。
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
  }) : _repository = repository,
       _ledger = ledger,
       _runner = transactionRunner,
       _removal = InstallmentContractRemovalAppService(
         installments: repository,
         bills: bills,
         repayments: repayments,
         ledger: ledger,
       );

  final InstallmentRepository _repository;
  final CreditLedgerPort _ledger;
  final TransactionRunner _runner;
  final InstallmentContractRemovalAppService _removal;

  @override
  Future<void> updateContractDetails(UpdateContractDetailsCommand command) =>
      _runner.run(() async {
        final contract =
            await _repository.findContract(command.contractId) ??
            (throw BusinessException(CreditErrorCode.contractNotFound));
        contract.reviseDetails(name: command.name, note: command.note);
        await _synchronizeBorrowing(contract, command);
        await _repository.saveAggregate(contract);
      });

  Future<void> _synchronizeBorrowing(
    InstallmentContract contract,
    UpdateContractDetailsCommand command,
  ) async {
    if (contract.installmentType != InstallmentType.disbursement) return;
    final txId = contract.sourceRefId;
    if (txId == null) return;
    if (command.disbursementAccountId != null) {
      await _ledger.editBorrowing(
        CreditLedgerEditBorrowingCommand(
          transactionId: txId,
          receiveAccountId: command.disbursementAccountId,
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
  Future<void> deleteContract(DeleteContractCommand command) {
    return _runner.run(() async {
      final contract = await _repository.findContract(command.contractId);
      if (contract == null) {
        throw BusinessException(
          CreditErrorCode.contractNotFound,
          message: 'Installment contract does not exist.',
        );
      }
      if (contract.installmentType != InstallmentType.billConversion) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '请通过对应分期场景删除该分期',
        );
      }
      await _removal.remove(contract);
    });
  }
}
