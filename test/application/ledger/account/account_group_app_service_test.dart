import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/account/command/account_group_app_service.dart';
import 'package:smartflow/application/ledger/account/command/account_group_command.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/account_group.dart';
import 'package:smartflow/domain/ledger/port/account_group_repository.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

void main() {
  test('deleting a group unassigns active and archived accounts', () async {
    final active = _account('active')..groupId = 'group';
    final archived =
        _account('archived')
          ..groupId = 'group'
          ..archive(DateTime(2026));
    final accounts = _Accounts([active, archived]);
    final service = _service(accounts: accounts, groups: _Groups([_group()]));

    await service.deleteGroup(const DeleteAccountGroupCommand(id: 'group'));

    expect(accounts.byId('active')!.groupId, isNull);
    expect(accounts.byId('archived')!.groupId, isNull);
  });

  test('moving an account applies the target group order', () async {
    final first = _account('first')..groupId = 'group';
    final second = _account('second');
    final accounts = _Accounts([first, second]);
    final service = _service(accounts: accounts, groups: _Groups([_group()]));

    await service.moveAccountToGroup(
      const MoveAccountToGroupCommand(
        accountId: 'second',
        groupId: 'group',
        orderedAccountIds: ['second', 'first'],
      ),
    );

    expect(accounts.byId('second')!.groupId, 'group');
    expect(accounts.byId('second')!.sortOrder, 0);
    expect(accounts.byId('first')!.sortOrder, 1);
  });

  test(
    'moving an account does not disturb archived account placement',
    () async {
      final first = _account('first')..groupId = 'group';
      final archived =
          _account('archived')
            ..groupId = 'group'
            ..sortOrder = 8
            ..archive(DateTime(2026));
      final second = _account('second');
      final accounts = _Accounts([first, archived, second]);
      final service = _service(accounts: accounts, groups: _Groups([_group()]));

      await service.moveAccountToGroup(
        const MoveAccountToGroupCommand(
          accountId: 'second',
          groupId: 'group',
          orderedAccountIds: ['second', 'first'],
        ),
      );

      expect(accounts.byId('archived')!.groupId, 'group');
      expect(accounts.byId('archived')!.sortOrder, 8);
    },
  );

  test('creating a group appends after existing group order', () async {
    final groups = _Groups([
      AccountGroup(id: 'fund', name: '资金', sortOrder: 10),
      AccountGroup(id: 'credit', name: '信用', sortOrder: 20),
    ]);
    final service = _service(accounts: _Accounts([]), groups: groups);

    final created = await service.createGroup(
      const CreateAccountGroupCommand(name: '投资'),
    );

    expect(created.sortOrder, 21);
  });
}

AccountGroupAppService _service({
  required _Accounts accounts,
  required _Groups groups,
}) {
  return AccountGroupAppServiceImpl(
    accounts: accounts,
    groups: groups,
    transactionRunner: const _Runner(),
    idGenerator: const _Ids(),
  );
}

Account _account(String id) =>
    Account(id: id, name: id, type: AccountType.asset, balance: Money.zero());

AccountGroup _group() => AccountGroup(id: 'group', name: 'Group');

class _Accounts implements AccountRepository {
  _Accounts(Iterable<Account> accounts)
    : _items = {for (final account in accounts) account.id: account};

  final Map<String, Account> _items;

  Account? byId(String id) => _items[id];

  @override
  Future<Account?> findById(String id) async => _items[id];

  @override
  Future<List<Account>> findByGroupId(String? groupId) async => [
    for (final account in _items.values)
      if (account.groupId == groupId) account,
  ];

  @override
  Future<void> saveAll(Iterable<Account> accounts) async {
    for (final account in accounts) {
      _items[account.id] = account;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Groups implements AccountGroupRepository {
  _Groups(Iterable<AccountGroup> groups)
    : _items = {for (final group in groups) group.id: group};

  final Map<String, AccountGroup> _items;

  @override
  Future<AccountGroup?> findById(String id) async => _items[id];

  @override
  Future<List<AccountGroup>> findAll() async => _items.values.toList();

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
  }

  @override
  Future<void> create(AccountGroup group) async {
    _items[group.id] = group;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runner implements TransactionRunner {
  const _Runner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _Ids implements IdGenerator {
  const _Ids();

  @override
  String newId() => 'new';
}
