import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';

void main() {
  group('AccountAppService', () {
    test('archives an active user account', () async {
      final account = _account('cash');
      final repository = _FakeAccountRepository([account]);
      final service = _service(repository);

      await service.archiveAccount(const ArchiveAccountCommand(id: 'cash'));

      expect(repository.account('cash').isArchived, true);
    });

    test('rejects archiving a system account', () async {
      final account = _account('opening', systemKey: SystemKey.openingBalance);
      final service = _service(_FakeAccountRepository([account]));

      await expectLater(
        () =>
            service.archiveAccount(const ArchiveAccountCommand(id: 'opening')),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            LedgerErrorCode.accountUnavailable.code,
          ),
        ),
      );
    });

    test('rejects archiving an already archived account', () async {
      final account = _account('cash')..archive(DateTime(2026, 1, 1));
      final service = _service(_FakeAccountRepository([account]));

      await expectLater(
        () => service.archiveAccount(const ArchiveAccountCommand(id: 'cash')),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            LedgerErrorCode.accountUnavailable.code,
          ),
        ),
      );
    });

    test('propagates transaction failures while archiving', () async {
      final account = _account('cash');
      final repository = _FakeAccountRepository([account]);
      final transactionRunner = _FailingTransactionRunner(
        StateError('transaction failed'),
      );
      final service = _service(
        repository,
        transactionRunner: transactionRunner,
      );

      await expectLater(
        () => service.archiveAccount(const ArchiveAccountCommand(id: 'cash')),
        throwsA(same(transactionRunner.failure)),
      );

      expect(transactionRunner.entered, true);
      expect(repository.account('cash').isArchived, false);
    });
  });
}

AccountAppService _service(
  AccountRepository repository, {
  TransactionRunner transactionRunner = const _PassthroughTransactionRunner(),
}) {
  return AccountAppServiceImpl(
    repository,
    transactionRunner: transactionRunner,
    ledgerPostingService: _UnusedLedgerPostingService(),
    transactionRepository: _UnusedTransactionRepository(),
    idGenerator: const _UnusedIdGenerator(),
  );
}

Account _account(String id, {SystemKey? systemKey}) {
  return Account(
    id: id,
    name: id,
    type: AccountType.asset,
    balance: Money.zero(),
    systemKey: systemKey,
  );
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(Iterable<Account> accounts)
    : _accounts = {for (final account in accounts) account.id: account};

  final Map<String, Account> _accounts;

  Account account(String id) => _accounts[id]!;

  @override
  Future<void> create(Account account) async {
    _accounts[account.id] = account;
  }

  @override
  Future<Account?> findById(String id) async => _accounts[id];

  @override
  Future<List<Account>> findByIds(Set<String> ids) async {
    return [
      for (final id in ids)
        if (_accounts[id] != null) _accounts[id]!,
    ];
  }

  @override
  Future<List<Account>> findChildrenOf(String parentId) async => const [];

  @override
  Future<List<Account>> findByGroupId(String? groupId) async => [
    for (final account in _accounts.values)
      if (account.groupId == groupId) account,
  ];

  @override
  Future<void> save(Account account) async {
    _accounts[account.id] = account;
  }

  @override
  Future<void> saveAll(Iterable<Account> accounts) async {
    for (final account in accounts) {
      _accounts[account.id] = account;
    }
  }

  @override
  Future<List<Account>> findArchivedMountsOf(Set<String> categoryIds) async {
    return [
      for (final account in _accounts.values)
        if (account.isArchived && categoryIds.contains(account.parentId))
          account,
    ];
  }

  @override
  Future<void> delete(String id) async {
    _accounts.remove(id);
  }
}

class _PassthroughTransactionRunner implements TransactionRunner {
  const _PassthroughTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _FailingTransactionRunner implements TransactionRunner {
  _FailingTransactionRunner(this.failure);

  final Object failure;
  var entered = false;

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    entered = true;
    throw failure;
  }
}

class _UnusedLedgerPostingService implements LedgerPostingService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedTransactionRepository implements TransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedIdGenerator implements IdGenerator {
  const _UnusedIdGenerator();

  @override
  String newId() => throw UnimplementedError();
}
