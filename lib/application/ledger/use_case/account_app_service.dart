import '../../../core/error/failure.dart';
import '../../../core/result/result.dart';
import '../../../application/shared/transaction_runner.dart';
import '../command/account_command.dart';
import '../command/transaction_command.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'posting_app_service.dart';

abstract interface class AccountAppService {
  Future<Account?> findAccountById(int id);

  Future<List<Account>> findAccountsByIds(Set<int> ids);

  Future<Result<Account>> createAccount(CreateAccountCommand command);

  Future<Result<void>> editAccount(EditAccountCommand command);
}

class AccountAppServiceImpl implements AccountAppService {
  const AccountAppServiceImpl(
    this._repository, {
    required TransactionRunner transactionRunner,
    required PostingAppService transactions,
  }) : _runner = transactionRunner,
       _transactions = transactions;

  final AccountRepository _repository;
  final PostingAppService _transactions;
  final TransactionRunner _runner;

  @override
  Future<Account?> findAccountById(int id) {
    return _repository.findById(id);
  }

  @override
  Future<List<Account>> findAccountsByIds(Set<int> ids) {
    return _repository.findByIds(ids);
  }

  @override
  Future<Result<Account>> createAccount(CreateAccountCommand command) async {
    if (command.openingBalance.minorUnits != 0 &&
        !command.type.supportsManualBalance(command.subtype)) {
      return const Result.failure(
        Failure(
          code: 'opening_balance_not_supported',
          message: 'This account type does not support opening balance.',
        ),
      );
    }
    final draftResult = Account.createUserAccount(
      name: command.name.trim(),
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
    final Account draft;
    switch (draftResult) {
      case Success(:final value):
        draft = value;
      case FailureResult(:final failure):
        return Result.failure(failure);
    }

    try {
      return await _runner.run<Account>(() async {
        final account = await _repository.create(draft);
        if (command.openingBalance.minorUnits == 0) {
          return Result.success(account);
        }
        final openingResult = await _transactions.createOpeningBalance(
          CreateOpeningBalanceCommand(
            accountId: account.id,
            amount: command.openingBalance,
            occurredAt: DateTime.now(),
          ),
        );
        switch (openingResult) {
          case Success():
            final refreshed = await _repository.findById(account.id);
            return Result.success(refreshed ?? account);
          case FailureResult(:final failure):
            return Result.failure(failure);
        }
      });
    } on Object catch (error) {
      return Result.failure(
        Failure(
          code: 'account_create_failed',
          message: 'Failed to create account.',
          cause: error,
        ),
      );
    }
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
      final Account profile;
      switch (profileResult) {
        case Success(:final value):
          profile = value;
        case FailureResult(:final failure):
          return Result.failure(failure);
      }
      final creditResult = profile.changeCreditProfile(
        AccountCreditProfilePatch(
          creditLimit: command.creditLimit,
          billingDay: command.billingDay,
          repaymentDay: command.repaymentDay,
        ),
      );
      final Account edited;
      switch (creditResult) {
        case Success(:final value):
          edited = value;
        case FailureResult(:final failure):
          return Result.failure(failure);
      }

      return await _runner.run<void>(() async {
        await _repository.save(edited);

        if (targetBalance == null ||
            targetBalance.minorUnits == account.balance.minorUnits) {
          return const Result.success(null);
        }
        final adjustmentResult = await _transactions.adjustBalance(
          AdjustBalanceCommand(
            accountId: command.id,
            targetBalance: targetBalance,
            occurredAt: DateTime.now(),
          ),
        );
        switch (adjustmentResult) {
          case Success():
            return const Result.success(null);
          case FailureResult(:final failure):
            return Result.failure(failure);
        }
      });
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
