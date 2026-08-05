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

    group('permanent deletion', () {
      test(
        'physically deletes an archived account without business data',
        () async {
          final account = _account('cash', archived: true);
          final repository = _FakeAccountRepository([account]);
          final service = _service(repository);

          await service.deleteAccount(const DeleteAccountCommand(id: 'cash'));

          expect(repository.contains('cash'), isFalse);
        },
      );

      test('rejects deleting an active account', () async {
        final repository = _FakeAccountRepository([_account('cash')]);
        final service = _service(repository);

        await expectLater(
          () => service.deleteAccount(const DeleteAccountCommand(id: 'cash')),
          throwsA(_hasCode(LedgerErrorCode.accountUnavailable)),
        );

        expect(repository.contains('cash'), isTrue);
      });

      test('rejects deleting a credit-managed liability account', () async {
        final repository = _FakeAccountRepository([
          _account('card', type: AccountType.liability, archived: true),
        ]);
        final service = _service(repository);

        await expectLater(
          () => service.deleteAccount(const DeleteAccountCommand(id: 'card')),
          throwsA(_hasCode(LedgerErrorCode.accountUnavailable)),
        );

        expect(repository.contains('card'), isTrue);
      });

      test('allows the dedicated credit deletion capability', () async {
        final repository = _FakeAccountRepository([
          _account('card', type: AccountType.liability, archived: true),
        ]);
        final service = _service(repository);

        await service.deleteCreditManagedAccount(
          const DeleteAccountCommand(id: 'card'),
        );

        expect(repository.contains('card'), isFalse);
      });

      test(
        'rejects deleting an archived account referenced by entries',
        () async {
          final repository = _FakeAccountRepository([
            _account('cash', archived: true),
          ]);
          final service = _service(repository, entryCounts: const {'cash': 1});

          await expectLater(
            () => service.deleteAccount(const DeleteAccountCommand(id: 'cash')),
            throwsA(_hasCode(LedgerErrorCode.accountInUse)),
          );

          expect(repository.contains('cash'), isTrue);
        },
      );
    });
  });
}

Matcher _hasCode(LedgerErrorCode code) {
  return isA<BusinessException>().having(
    (exception) => exception.code,
    'code',
    code.code,
  );
}

AccountAppServiceImpl _service(
  AccountRepository repository, {
  TransactionRunner transactionRunner = const _PassthroughTransactionRunner(),
  Map<String, int> entryCounts = const {},
}) {
  return AccountAppServiceImpl(
    repository,
    transactionRunner: transactionRunner,
    ledgerPostingService: _UnusedLedgerPostingService(),
    transactionRepository: _FakeTransactionRepository(entryCounts),
    idGenerator: const _UnusedIdGenerator(),
  );
}

Account _account(
  String id, {
  SystemKey? systemKey,
  AccountType type = AccountType.asset,
  bool archived = false,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    balance: Money.zero(),
    systemKey: systemKey,
    archivedAt: archived ? DateTime(2026) : null,
  );
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(Iterable<Account> accounts)
    : _accounts = {for (final account in accounts) account.id: account};

  final Map<String, Account> _accounts;

  Account account(String id) => _accounts[id]!;

  bool contains(String id) => _accounts.containsKey(id);

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

class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository(this.entryCounts);

  final Map<String, int> entryCounts;

  @override
  Future<Map<String, int>> countEntriesByAccount(Set<String> accountIds) async {
    return {
      for (final id in accountIds)
        if (entryCounts[id] case final int count when count > 0) id: count,
    };
  }

  @override
  Future<Map<String, int>> countReimbursementExpenseRefs(
    Set<String> accountIds,
  ) async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedIdGenerator implements IdGenerator {
  const _UnusedIdGenerator();

  @override
  String newId() => throw UnimplementedError();
}
