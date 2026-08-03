import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/ledger/entity/account_group.dart';
import 'package:smartflow/domain/ledger/port/account_group_repository.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';

import 'account_group_command.dart';

abstract interface class AccountGroupAppService {
  Future<AccountGroup> createGroup(CreateAccountGroupCommand command);

  Future<void> renameGroup(RenameAccountGroupCommand command);

  Future<void> deleteGroup(DeleteAccountGroupCommand command);

  Future<void> reorderGroups(ReorderAccountGroupsCommand command);

  Future<void> moveAccountToGroup(MoveAccountToGroupCommand command);
}

class AccountGroupAppServiceImpl implements AccountGroupAppService {
  const AccountGroupAppServiceImpl({
    required AccountGroupRepository groups,
    required AccountRepository accounts,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
  }) : _groups = groups,
       _accounts = accounts,
       _runner = transactionRunner,
       _idGenerator = idGenerator;

  final AccountGroupRepository _groups;
  final AccountRepository _accounts;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;

  @override
  Future<AccountGroup> createGroup(CreateAccountGroupCommand command) {
    return _runner.run(() async {
      final group = AccountGroup(
        id: _idGenerator.newId(),
        name: command.name,
        sortOrder: (await _groups.findAll()).length,
      );
      await _groups.create(group);
      return group;
    });
  }

  @override
  Future<void> renameGroup(RenameAccountGroupCommand command) {
    return _runner.run(() async {
      final group = await _requireGroup(command.id);
      group.rename(command.name);
      await _groups.save(group);
    });
  }

  @override
  Future<void> deleteGroup(DeleteAccountGroupCommand command) {
    return _runner.run(() async {
      await _requireGroup(command.id);
      final accounts = await _accounts.findByGroupId(command.id);
      for (final account in accounts) {
        account.groupId = null;
      }
      await _accounts.saveAll(accounts);
      await _groups.delete(command.id);
    });
  }

  @override
  Future<void> reorderGroups(ReorderAccountGroupsCommand command) {
    return _runner.run(() async {
      final groups = await _groups.findAll();
      _requireSameIds(
        actual: groups.map((group) => group.id),
        requested: command.orderedIds,
        message: 'Account group order does not match existing groups.',
      );
      for (var index = 0; index < groups.length; index++) {
        final group = groups.singleWhere(
          (item) => item.id == command.orderedIds[index],
        );
        group.reorder(index);
      }
      await _groups.saveAll(groups);
    });
  }

  @override
  Future<void> moveAccountToGroup(MoveAccountToGroupCommand command) {
    return _runner.run(() async {
      if (command.groupId case final groupId?) {
        await _requireGroup(groupId);
      }
      final account = await _accounts.findById(command.accountId);
      if (account == null) {
        throw BusinessException(LedgerErrorCode.accountNotFound);
      }
      final sourceGroupId = account.groupId;
      final sourceAccounts = await _accounts.findByGroupId(sourceGroupId);
      final targetAccounts =
          sourceGroupId == command.groupId
              ? sourceAccounts
              : await _accounts.findByGroupId(command.groupId);
      final updatedTarget = [
        for (final item in targetAccounts)
          if (item.id != account.id) item,
        account,
      ];
      _requireSameIds(
        actual: updatedTarget.map((item) => item.id),
        requested: command.orderedAccountIds,
        message: 'Account order does not match group contents.',
      );
      for (var index = 0; index < command.orderedAccountIds.length; index++) {
        final item = updatedTarget.singleWhere(
          (candidate) => candidate.id == command.orderedAccountIds[index],
        );
        item.moveToGroup(command.groupId, sortOrder: index);
      }
      final updated = [...updatedTarget];
      if (sourceGroupId != command.groupId) {
        var sourceOrder = 0;
        for (final item in sourceAccounts) {
          if (item.id == account.id) continue;
          item.moveToGroup(sourceGroupId, sortOrder: sourceOrder++);
          updated.add(item);
        }
      }
      await _accounts.saveAll(updated);
    });
  }

  Future<AccountGroup> _requireGroup(String id) async {
    final group = await _groups.findById(id);
    if (group == null) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Account group not found.',
      );
    }
    return group;
  }

  void _requireSameIds({
    required Iterable<String> actual,
    required List<String> requested,
    required String message,
  }) {
    final actualIds = actual.toSet();
    if (actualIds.length != requested.length ||
        actualIds.length != requested.toSet().length ||
        !actualIds.containsAll(requested)) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: message,
      );
    }
  }
}
