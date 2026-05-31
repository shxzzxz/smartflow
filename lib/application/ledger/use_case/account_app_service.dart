import '../../../core/id/id_generator.dart';
import '../../../core/result/result.dart';
import '../../../application/shared/transaction_runner.dart';
import '../command/account_command.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/account_factory.dart';
import 'package:smartflow/domain/ledger/service/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import '../../../core/error/failure.dart';

abstract interface class AccountAppService {
  Future<Result<Account>> createAccount(CreateAccountCommand command);

  Future<Result<void>> editAccount(EditAccountCommand command);
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
  Future<Result<Account>> createAccount(CreateAccountCommand command) async {
    final accountResult = _accountFactory.createUserAccount(
      id: _idGenerator.newId(),
      name: command.name,
      type: command.type,
      subtype: command.subtype,
      iconKey: command.iconKey,
      note: command.note,
      creditLimit: command.creditLimit,
      billingDay: command.billingDay,
      repaymentDay: command.repaymentDay,
      sortOrder: command.sortOrder,
      isHidden: command.isHidden,
    );
    final Account account;
    switch (accountResult) {
      case Success(:final value):
        account = value;
      case FailureResult(:final failure):
        return Result.failure(failure);
    }

    if (command.openingBalance.minorUnits == 0) {
      return _runner.run<Account>(() async {
        await _repository.create(account);
        return Result.success(account);
      });
    }

    final openingResult = await _ledgerPostingService
        .postOpeningBalanceForAccount(
          account: account,
          instruction: OpeningBalanceInstruction(
            accountId: account.id,
            amount: command.openingBalance,
            occurredAt: DateTime.now(),
          ),
        );
    if (openingResult case FailureResult(:final failure)) {
      return Result.failure(failure);
    }
    final posting = openingResult.value;

    return _runner.run<Account>(() async {
      await _repository.create(account);
      await _transactionRepository.save(posting.transaction);
      await _repository.saveAll(posting.accounts);
      return Result.success(account);
    });
  }

  @override
  Future<Result<void>> editAccount(EditAccountCommand command) async {
    try {
      final account = await _repository.findById(command.id);
      if (account == null) {
        return const Result.failure(
          Failure(
            code: 'account_not_found',
            message: 'Account does not exist.',
          ),
        );
      }
      final targetBalance = command.targetBalance;
      final profileResult = account.changeProfile(
        AccountProfilePatch(
          name: command.name,
          sortOrder: command.sortOrder,
          isHidden: command.isHidden,
          subtype: command.subtype,
          iconKey: command.iconKey,
          note: command.note,
        ),
      );
      switch (profileResult) {
        case Success():
          break;
        case FailureResult(:final failure):
          return Result.failure(failure);
      }
      final creditResult = account.changeCreditProfile(
        AccountCreditProfilePatch(
          creditLimit: command.creditLimit,
          billingDay: command.billingDay,
          repaymentDay: command.repaymentDay,
        ),
      );
      switch (creditResult) {
        case Success():
          break;
        case FailureResult(:final failure):
          return Result.failure(failure);
      }

      return await _runner.run<void>(() async {
        if (targetBalance == null ||
            targetBalance.minorUnits == account.balance.minorUnits) {
          await _repository.save(account);
          return const Result.success(null);
        }
        final adjustmentResult = await _ledgerPostingService
            .postBalanceAdjustmentForAccount(
              account: account,
              instruction: BalanceAdjustmentInstruction(
                accountId: command.id,
                targetBalance: targetBalance,
                occurredAt: DateTime.now(),
              ),
            );
        switch (adjustmentResult) {
          case Success(:final value):
            await _transactionRepository.save(value.transaction);
            await _repository.saveAll(value.accounts);
            return const Result.success(null);
          case FailureResult(:final failure):
            return Result.failure(failure);
        }
      });
    } on AccountVersionConflictException {
      rethrow;
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'account_edit_failed',
          message: 'Failed to edit account.',
          cause: error,
        ),
      );
    }
  }
}
