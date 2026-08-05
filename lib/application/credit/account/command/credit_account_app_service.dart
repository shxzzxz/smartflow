import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/port/bill_generation_suppression_repository.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'credit_account_command.dart';

abstract interface class CreditAccountAppService {
  Future<CreditLedgerAccountSnapshot> createAccount(
    CreateCreditLiabilityAccountCommand command,
  );

  Future<void> editAccount(EditCreditLiabilityAccountCommand command);

  Future<void> deleteAccount(DeleteCreditLiabilityAccountCommand command);
}

class CreditAccountAppServiceImpl implements CreditAccountAppService {
  const CreditAccountAppServiceImpl({
    required CreditAccountLedgerPort ledger,
    required CreditAccountRepository creditAccounts,
    required BillRepository bills,
    required InstallmentRepository installments,
    required RepaymentRepository repayments,
    required BillGenerationSuppressionRepository suppressions,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
  }) : _ledger = ledger,
       _creditAccounts = creditAccounts,
       _bills = bills,
       _installments = installments,
       _repayments = repayments,
       _suppressions = suppressions,
       _runner = transactionRunner,
       _idGenerator = idGenerator;

  final CreditAccountLedgerPort _ledger;
  final CreditAccountRepository _creditAccounts;
  final BillRepository _bills;
  final InstallmentRepository _installments;
  final RepaymentRepository _repayments;
  final BillGenerationSuppressionRepository _suppressions;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;

  @override
  Future<CreditLedgerAccountSnapshot> createAccount(
    CreateCreditLiabilityAccountCommand command,
  ) {
    return _runner.run<CreditLedgerAccountSnapshot>(() async {
      final account = await _ledger.createLiabilityAccount(
        CreditLedgerCreateLiabilityAccountCommand(
          name: command.name,
          kind: command.kind,
          openingBalance: command.openingBalance,
          iconKey: command.iconKey,
          note: command.note,
          groupId: command.groupId,
          sortOrder: command.sortOrder,
          isHidden: command.isHidden,
        ),
      );
      final extension = CreditLiabilityAccount(
        id: _idGenerator.newId(),
        accountId: account.id,
        kind: command.kind,
        creditLimit: command.creditLimit,
        billingDay: command.billingDay,
        repaymentDay: command.repaymentDay,
        billingDayToNext: command.billingDayToNext,
      );
      await _creditAccounts.insert(
        CreditLiabilityAccountDraft(
          id: extension.id,
          accountId: account.id,
          kind: extension.kind,
          creditLimit: extension.creditLimit,
          billingDay: extension.billingDay,
          repaymentDay: extension.repaymentDay,
          billingDayToNext: extension.billingDayToNext,
        ),
      );
      return account;
    });
  }

  @override
  Future<void> editAccount(EditCreditLiabilityAccountCommand command) async {
    final current = await _creditAccounts.findByAccountId(command.accountId);
    if (current == null) {
      throw BusinessException(CreditErrorCode.accountNotFound);
    }
    final patch = CreditLiabilityAccountPatch(
      creditLimit: command.creditLimit,
      billingDay: command.billingDay,
      repaymentDay: command.repaymentDay,
      billingDayToNext: command.billingDayToNext,
    );
    current.updateParameters(patch);

    await _runner.run<void>(() async {
      await _ledger.editLiabilityAccount(
        CreditLedgerEditLiabilityAccountCommand(
          accountId: command.accountId,
          name: command.name,
          iconKey: command.iconKey,
          note: command.note,
          groupId: command.groupId,
          targetBalance: command.targetBalance,
        ),
      );
      await _creditAccounts.update(
        command.accountId,
        CreditLiabilityAccountPersistencePatch(
          creditLimit: command.creditLimit,
          billingDay: command.billingDay,
          repaymentDay: command.repaymentDay,
          billingDayToNext: command.billingDayToNext,
        ),
      );
    });
  }

  @override
  Future<void> deleteAccount(
    DeleteCreditLiabilityAccountCommand command,
  ) async {
    await _runner.run<void>(() async {
      final account = await _creditAccounts.findByAccountId(command.accountId);
      if (account == null) {
        throw BusinessException(CreditErrorCode.accountNotFound);
      }

      final contracts = await _installments.listContractsByLiabilityAccount(
        command.accountId,
      );
      final accountRepayments = await _repayments.listByTarget(
        RepaymentTargetType.account,
        command.accountId,
      );
      final bills = await _bills.listBillsByAccount(command.accountId);
      if (contracts.isNotEmpty || accountRepayments.isNotEmpty) {
        throw BusinessException(CreditErrorCode.accountInUse);
      }
      for (final bill in bills) {
        final billRepayments = await _repayments.listByTarget(
          RepaymentTargetType.bill,
          bill.id,
        );
        if (bill.items.isNotEmpty || billRepayments.isNotEmpty) {
          throw BusinessException(CreditErrorCode.accountInUse);
        }
      }

      for (final bill in bills) {
        await _bills.deleteBill(bill.id);
      }
      await _suppressions.clearAll(command.accountId);
      await _creditAccounts.delete(command.accountId);
      await _ledger.deleteLiabilityAccount(command.accountId);
    });
  }
}
