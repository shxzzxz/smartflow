import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../../../application/shared/transaction_runner.dart';
import '../command/account_command.dart';
import '../command/transaction_command.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'transaction_service.dart';

abstract interface class AccountService {
  Stream<List<Account>> watchAccounts(Set<AccountType> types);

  Future<Account?> findAccountById(int id);

  Future<List<Account>> findAccountsByIds(Set<int> ids);

  Future<Result<Account>> createAccount(CreateAccountCommand command);

  Future<Result<void>> editAccount(EditAccountCommand command);
}

class AccountServiceImpl implements AccountService {
  const AccountServiceImpl(
    this._repository, {
    required TransactionRunner transactionRunner,
    required TransactionService transactions,
  }) : _runner = transactionRunner,
       _transactions = transactions;

  final AccountRepository _repository;
  final TransactionService _transactions;
  final TransactionRunner _runner;

  @override
  Stream<List<Account>> watchAccounts(Set<AccountType> types) {
    return _repository.watchAccounts(types);
  }

  @override
  Future<Account?> findAccountById(int id) {
    return _repository.findAccountById(id);
  }

  @override
  Future<List<Account>> findAccountsByIds(Set<int> ids) {
    return _repository.findAccountsByIds(ids);
  }

  @override
  Future<Result<Account>> createAccount(CreateAccountCommand command) async {
    final failure = _validateCreate(command);
    if (failure != null) {
      return Result.failure(failure);
    }

    final spec = AccountInsertSpec(
      name: command.name.trim(),
      type: command.type,
      subtype: command.subtype,
      iconKey: _blankToNull(command.iconKey),
      note: _blankToNull(command.note),
      creditLimitMinor: command.creditLimit?.minorUnits,
      billingDay: command.billingDay,
      repaymentDay: command.repaymentDay,
      sortOrder: command.sortOrder,
      isHidden: command.isHidden,
    );

    try {
      return await _runner.run<Account>(() async {
        final account = await _repository.createAccount(spec);
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
            final refreshed = await _repository.findAccountById(account.id);
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
    final nameFailure = _validateEditName(command.name);
    if (nameFailure != null) {
      return Result.failure(nameFailure);
    }
    final targetBalance = command.targetBalance;
    if (targetBalance != null && targetBalance.minorUnits < 0) {
      return const Result.failure(
        Failure(
          code: 'account_target_balance_negative',
          message: 'Target balance cannot be negative.',
        ),
      );
    }

    try {
      final account = await _repository.findAccountById(command.id);
      if (account == null) {
        return const Result.failure(
          Failure(
            code: 'account_not_found',
            message: 'Account does not exist.',
          ),
        );
      }
      if (account.archivedAt != null) {
        return const Result.failure(
          Failure(
            code: 'account_archived',
            message: 'Archived account cannot be edited.',
          ),
        );
      }
      if (!_isUserAccountType(account.type)) {
        return const Result.failure(
          Failure(
            code: 'account_type_not_editable',
            message: 'Only asset and liability account can be edited here.',
          ),
        );
      }
      if (targetBalance != null &&
          !_supportsManualBalance(account.type, account.subtype)) {
        return const Result.failure(
          Failure(
            code: 'account_target_balance_not_supported',
            message: 'This account type does not support balance adjustment.',
          ),
        );
      }

      final spec = AccountUpdateSpec(
        name: command.name?.trim(),
        sortOrder: command.sortOrder,
        isHidden: command.isHidden,
        subtype: command.subtype,
        iconKey: _normalizeStringPatch(command.iconKey),
        note: _normalizeStringPatch(command.note),
        creditLimitMinor: _moneyPatchToMinor(command.creditLimit),
        billingDay: command.billingDay,
        repaymentDay: command.repaymentDay,
      );

      return await _runner.run<void>(() async {
        await _repository.updateAccount(command.id, spec);

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

  Failure? _validateCreate(CreateAccountCommand command) {
    if (command.name.trim().isEmpty) {
      return const Failure(
        code: 'account_name_required',
        message: 'Account name is required.',
      );
    }
    if (!_isUserAccountType(command.type)) {
      return const Failure(
        code: 'account_type_invalid',
        message: 'Only asset and liability account can be created here.',
      );
    }
    if (command.openingBalance.minorUnits != 0 &&
        !_supportsManualBalance(command.type, command.subtype)) {
      return const Failure(
        code: 'opening_balance_not_supported',
        message: 'This account type does not support opening balance.',
      );
    }

    return null;
  }

  Failure? _validateEditName(String? name) {
    if (name == null) {
      return null;
    }
    if (name.trim().isEmpty) {
      return const Failure(
        code: 'account_name_required',
        message: 'Account name is required.',
      );
    }
    return null;
  }

  bool _isUserAccountType(AccountType type) {
    return type == AccountType.asset || type == AccountType.liability;
  }

  bool _supportsManualBalance(AccountType type, AccountSubtype? subtype) {
    if (type == AccountType.asset) {
      return subtype != AccountSubtype.reimbursement;
    }
    return type == AccountType.liability;
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Patch<String>? _normalizeStringPatch(Patch<String>? patch) {
    return switch (patch) {
      null => null,
      PatchClear<String>() => patch,
      PatchSet<String>(:final value) =>
        _blankToNull(value) == null
            ? const Patch<String>.clear()
            : Patch.set(value.trim()),
    };
  }

  Patch<int>? _moneyPatchToMinor(Patch<Money>? patch) {
    return switch (patch) {
      null => null,
      PatchClear<Money>() => const Patch<int>.clear(),
      PatchSet<Money>(:final value) => Patch.set(value.minorUnits),
    };
  }
}
