import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/account/account_factory.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import 'account_command.dart';

abstract interface class AccountAppService {
  Future<Account> createAccount(CreateAccountCommand command);

  Future<void> editAccount(EditAccountCommand command);
}

class AccountAppServiceImpl implements AccountAppService {
  const AccountAppServiceImpl(
    this._repository, {
    required TransactionRunner transactionRunner,
    required LedgerPostingService ledgerPostingService,
    required TransactionRepository transactionRepository,
    required IdGenerator idGenerator,
    AccountFactory accountFactory = const AccountFactory(),
  }) : _runner = transactionRunner,
       _ledgerPostingService = ledgerPostingService,
       _transactionRepository = transactionRepository,
       _idGenerator = idGenerator,
       _accountFactory = accountFactory;

  final AccountRepository _repository;
  final LedgerPostingService _ledgerPostingService;
  final TransactionRepository _transactionRepository;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;
  final AccountFactory _accountFactory;

  @override
  Future<Account> createAccount(CreateAccountCommand command) async {
    final account = _accountFactory.createUserAccount(
      id: _idGenerator.newId(),
      name: command.name,
      type: command.type,
      subtype: command.subtype,
      profileKey: command.profileKey,
      iconKey: command.iconKey,
      note: command.note,
      sortOrder: command.sortOrder,
      isHidden: command.isHidden,
    );

    if (command.openingBalance.minorUnits == 0) {
      return _runner.run<Account>(() async {
        await _repository.create(account);
        return account;
      });
    }

    final posting = await _ledgerPostingService.postOpeningBalanceForAccount(
      account: account,
      instruction: OpeningBalanceInstruction(
        accountId: account.id,
        amount: command.openingBalance,
        occurredAt: DateTime.now(),
      ),
    );

    return _runner.run<Account>(() async {
      await _repository.create(account);
      await _transactionRepository.save(posting.transaction);
      await _repository.saveAll(posting.accounts);
      return account;
    });
  }

  @override
  Future<void> editAccount(EditAccountCommand command) async {
    final account = await _repository.findById(command.id);
    if (account == null) {
      throw BusinessException(LedgerErrorCode.accountNotFound);
    }
    final targetBalance = command.targetBalance;
    account.changeProfile(
      AccountProfilePatch(
        name: command.name,
        sortOrder: command.sortOrder,
        isHidden: command.isHidden,
        subtype: command.subtype,
        profileKey: command.profileKey,
        iconKey: command.iconKey,
        note: command.note,
      ),
    );
    await _runner.run<void>(() async {
      if (targetBalance == null ||
          targetBalance.minorUnits == account.balance.minorUnits) {
        await _repository.save(account);
        return;
      }
      final adjustment = await _ledgerPostingService
          .postBalanceAdjustmentForAccount(
            account: account,
            instruction: BalanceAdjustmentInstruction(
              accountId: command.id,
              targetBalance: targetBalance,
              occurredAt: DateTime.now(),
            ),
          );
      await _transactionRepository.save(adjustment.transaction);
      await _repository.saveAll(adjustment.accounts);
    });
  }
}
