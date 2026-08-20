import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/port/account_group_repository.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/account/account_factory.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

import 'account_command.dart';

abstract interface class AccountAppService {
  Future<Account> createAccount(CreateAccountCommand command);

  Future<void> editAccount(EditAccountCommand command);

  Future<void> archiveAccount(ArchiveAccountCommand command);

  Future<void> restoreAccount(RestoreAccountCommand command);

  Future<void> deleteAccount(DeleteAccountCommand command);
}

abstract interface class CreditManagedAccountDeletionService {
  Future<void> deleteCreditManagedAccount(DeleteAccountCommand command);
}

class AccountAppServiceImpl
    implements AccountAppService, CreditManagedAccountDeletionService {
  const AccountAppServiceImpl(
    this._repository, {
    required TransactionRunner transactionRunner,
    required LedgerPostingService ledgerPostingService,
    required TransactionRepository transactionRepository,
    required IdGenerator idGenerator,
    AccountFactory accountFactory = const AccountFactory(),
    AccountGroupRepository? accountGroups,
  }) : _runner = transactionRunner,
       _ledgerPostingService = ledgerPostingService,
       _transactionRepository = transactionRepository,
       _idGenerator = idGenerator,
       _accountFactory = accountFactory,
       _accountGroups = accountGroups;

  final AccountRepository _repository;
  final LedgerPostingService _ledgerPostingService;
  final TransactionRepository _transactionRepository;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;
  final AccountFactory _accountFactory;
  final AccountGroupRepository? _accountGroups;

  @override
  Future<Account> createAccount(CreateAccountCommand command) async {
    if (!isAccountProfileCompatible(
      type: command.type,
      subtype: command.subtype,
      profileKey: command.profileKey,
    )) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Account profile does not match account type and subtype.',
      );
    }
    final groupId = await _availableGroupId(command.groupId);
    final account = _accountFactory.createUserAccount(
      id: _idGenerator.newId(),
      name: command.name,
      type: command.type,
      subtype: command.subtype,
      profileKey: command.profileKey,
      groupId: groupId,
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

  Future<String?> _availableGroupId(String? groupId) async {
    if (groupId == null || _accountGroups == null) return groupId;
    return await _accountGroups.findById(groupId) == null ? null : groupId;
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
        groupId: command.groupId,
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

  @override
  Future<void> archiveAccount(ArchiveAccountCommand command) async {
    await _runner.run<void>(() async {
      final account = await _repository.findById(command.id);
      if (account == null) {
        throw BusinessException(LedgerErrorCode.accountNotFound);
      }
      account.archive(DateTime.now());
      await _repository.save(account);
    });
  }

  @override
  Future<void> restoreAccount(RestoreAccountCommand command) async {
    await _runner.run<void>(() async {
      final account = await _repository.findById(command.id);
      if (account == null) {
        throw BusinessException(LedgerErrorCode.accountNotFound);
      }
      account.restore();
      await _repository.save(account);
    });
  }

  @override
  Future<void> deleteAccount(DeleteAccountCommand command) async {
    await _deleteAccount(command, profileOwner: AccountProfileOwner.ledger);
  }

  @override
  Future<void> deleteCreditManagedAccount(DeleteAccountCommand command) async {
    await _deleteAccount(command, profileOwner: AccountProfileOwner.credit);
  }

  Future<void> _deleteAccount(
    DeleteAccountCommand command, {
    required AccountProfileOwner profileOwner,
  }) async {
    await _runner.run<void>(() async {
      final account = await _repository.findById(command.id);
      if (account == null) {
        throw BusinessException(LedgerErrorCode.accountNotFound);
      }
      if (AccountProfileKind.fromKey(account.profileKey)?.owner !=
              profileOwner ||
          account.systemKey != null ||
          !account.isArchived) {
        throw BusinessException(LedgerErrorCode.accountUnavailable);
      }

      final entryCounts = await _transactionRepository.countEntriesByAccount({
        account.id,
      });
      final reimbursementRefs = await _transactionRepository
          .countReimbursementExpenseRefs({account.id});
      if (account.balance.minorUnits != 0 ||
          (entryCounts[account.id] ?? 0) > 0 ||
          (reimbursementRefs[account.id] ?? 0) > 0) {
        throw BusinessException(LedgerErrorCode.accountInUse);
      }

      await _repository.delete(account.id);
    });
  }
}
