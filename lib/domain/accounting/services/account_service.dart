import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../entities/account.dart';
import '../enums/accounting_enums.dart';
import '../repositories/account_repository.dart';

abstract interface class AccountService {
  Stream<List<Account>> watchAccounts();

  Future<Result<Account>> createAccount(CreateAccountCommand command);

  Future<Result<void>> editAccount(EditAccountCommand command);
}

class AccountServiceImpl implements AccountService {
  const AccountServiceImpl(this._repository);

  final AccountRepository _repository;

  @override
  Stream<List<Account>> watchAccounts() {
    return _repository.watchAccounts({
      AccountType.asset,
      AccountType.liability,
    });
  }

  @override
  Future<Result<Account>> createAccount(CreateAccountCommand command) async {
    final failure = _validateCreate(command);
    if (failure != null) {
      return Result.failure(failure);
    }

    try {
      final account = await _repository.createAccount(command);
      return Result.success(account);
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
    if (command.name.trim().isEmpty) {
      return const Result.failure(
        Failure(
          code: 'account_name_required',
          message: 'Account name is required.',
        ),
      );
    }
    if (command.targetBalance != null &&
        command.targetBalance!.minorUnits < 0) {
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
            message: 'Archived accounts cannot be edited.',
          ),
        );
      }
      if (!_isUserAccountType(account.type)) {
        return const Result.failure(
          Failure(
            code: 'account_type_not_editable',
            message: 'Only asset and liability accounts can be edited here.',
          ),
        );
      }
      if (command.targetBalance != null &&
          command.targetBalance!.currency != account.currencyCode) {
        return const Result.failure(
          Failure(
            code: 'account_target_balance_currency_mismatch',
            message: 'Target balance currency must match account currency.',
          ),
        );
      }
      if (command.creditLimit != null &&
          command.creditLimit!.currency != account.currencyCode) {
        return const Result.failure(
          Failure(
            code: 'credit_limit_currency_mismatch',
            message: 'Credit limit currency must match account currency.',
          ),
        );
      }
      if (command.targetBalance != null &&
          !_supportsManualBalance(account.type, account.subtype)) {
        return const Result.failure(
          Failure(
            code: 'account_target_balance_not_supported',
            message: 'This account type does not support balance adjustment.',
          ),
        );
      }

      await _repository.updateAccount(command);
      return const Result.success(null);
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
        message: 'Only asset and liability accounts can be created here.',
      );
    }
    if (command.openingBalance.currency != command.currencyCode) {
      return const Failure(
        code: 'opening_balance_currency_mismatch',
        message: 'Opening balance currency must match account currency.',
      );
    }
    if (command.creditLimit != null &&
        command.creditLimit!.currency != command.currencyCode) {
      return const Failure(
        code: 'credit_limit_currency_mismatch',
        message: 'Credit limit currency must match account currency.',
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

  bool _isUserAccountType(AccountType type) {
    return type == AccountType.asset || type == AccountType.liability;
  }

  bool _supportsManualBalance(AccountType type, AccountSubtype? subtype) {
    if (type == AccountType.asset) {
      return subtype != AccountSubtype.reimbursement;
    }
    return type == AccountType.liability;
  }
}

class CreateAccountCommand {
  const CreateAccountCommand({
    required this.name,
    required this.type,
    this.currencyCode = Money.defaultCurrency,
    this.openingBalance = const Money(minorUnits: 0),
    this.openingOccurredAt,
    this.subtype,
    this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  final String name;
  final AccountType type;
  final String currencyCode;
  final Money openingBalance;
  final DateTime? openingOccurredAt;
  final AccountSubtype? subtype;
  final String? iconKey;
  final String? note;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final int sortOrder;
  final bool isHidden;
}

class EditAccountCommand {
  const EditAccountCommand({
    required this.id,
    required this.name,
    this.subtype,
    this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.targetBalance,
    this.balanceAdjustmentOccurredAt,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  final int id;
  final String name;
  final AccountSubtype? subtype;
  final String? iconKey;
  final String? note;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final Money? targetBalance;
  final DateTime? balanceAdjustmentOccurredAt;
  final int sortOrder;
  final bool isHidden;
}
