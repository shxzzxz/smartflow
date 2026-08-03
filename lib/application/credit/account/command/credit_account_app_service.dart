import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';

import 'credit_account_command.dart';

abstract interface class CreditAccountAppService {
  Future<CreditLedgerAccountSnapshot> createAccount(
    CreateCreditLiabilityAccountCommand command,
  );

  Future<void> editAccount(EditCreditLiabilityAccountCommand command);
}

class CreditAccountAppServiceImpl implements CreditAccountAppService {
  const CreditAccountAppServiceImpl({
    required CreditAccountLedgerPort ledger,
    required CreditAccountRepository creditAccounts,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
  }) : _ledger = ledger,
       _creditAccounts = creditAccounts,
       _runner = transactionRunner,
       _idGenerator = idGenerator;

  final CreditAccountLedgerPort _ledger;
  final CreditAccountRepository _creditAccounts;
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
}
