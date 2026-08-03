import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  group('LedgerPostingService.postExpense', () {
    test('returns posting result directly for valid daily expense', () async {
      final accountRepository = _FakeAccountRepository([
        _account('cash', AccountType.asset),
        _account('food', AccountType.expense),
      ]);
      final service = _service(accountRepository);

      final result = await service.postExpense(
        ExpenseInstruction(
          amount: const Money(minorUnits: 1234),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 1, 2),
        ),
      );

      expect(result.transaction.businessPurpose, BusinessPurpose.dailyExpense);
      expect(
        result.accounts.map((account) => account.id),
        containsAll(['cash', 'food']),
      );
    });

    test('throws business exception for expected posting failures', () async {
      final accountRepository = _FakeAccountRepository([
        _account('cash', AccountType.asset),
        _account('food', AccountType.asset),
      ]);
      final service = _service(accountRepository);

      await expectLater(
        () => service.postExpense(
          ExpenseInstruction(
            amount: const Money(minorUnits: 1234),
            paidFromAccountId: 'cash',
            expenseAccountId: 'food',
            occurredAt: DateTime(2026, 1, 2),
          ),
        ),
        throwsA(
          isA<BusinessException>()
              .having(
                (error) => error.code,
                'code',
                LedgerErrorCode.accountInvalidRole.code,
              )
              .having(
                (error) => error.message,
                'message',
                'Account cannot be used for this transaction.',
              ),
        ),
      );
    });

    test('rejects an archived account as a posting target', () async {
      final cash = _account('cash', AccountType.asset);
      cash.archive(DateTime(2026, 7, 16));
      final accountRepository = _FakeAccountRepository([
        cash,
        _account('food', AccountType.expense),
      ]);
      final service = _service(accountRepository);

      await expectLater(
        () => service.postExpense(
          ExpenseInstruction(
            amount: const Money(minorUnits: 1234),
            paidFromAccountId: 'cash',
            expenseAccountId: 'food',
            occurredAt: DateTime(2026, 1, 2),
          ),
        ),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            LedgerErrorCode.accountUnavailable.code,
          ),
        ),
      );
    });

    test(
      'allows the system ghost account as an import settlement account',
      () async {
        final accountRepository = _FakeAccountRepository([
          Account(
            id: 'ghost',
            name: '幽灵账户',
            type: AccountType.equity,
            systemKey: SystemKey.ghostAccount,
            balance: Money.zero(),
          ),
          _account('food', AccountType.expense),
        ]);
        final service = _service(accountRepository);

        final result = await service.postExpense(
          ExpenseInstruction(
            amount: Money.parse('12.00'),
            paidFromAccountId: 'ghost',
            expenseAccountId: 'food',
            occurredAt: DateTime(2026, 1, 2),
            sourceKind: SourceKind.import,
          ),
        );

        expect(result.transaction.sourceKind, SourceKind.import);
      },
    );

    test('does not allow a normal equity account as settlement', () async {
      final accountRepository = _FakeAccountRepository([
        _account('equity', AccountType.equity),
        _account('food', AccountType.expense),
      ]);
      final service = _service(accountRepository);

      await expectLater(
        () => service.postExpense(
          ExpenseInstruction(
            amount: Money.parse('12.00'),
            paidFromAccountId: 'equity',
            expenseAccountId: 'food',
            occurredAt: DateTime(2026, 1, 2),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
    });
  });
}

LedgerPostingService _service(_FakeAccountRepository accountRepository) {
  return LedgerPostingService(
    accountRepository: accountRepository,
    systemAccountResolver: _FakeSystemAccountResolver(),
    postingEngine: PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'tx'),
    ),
    accountPostingService: const DefaultAccountPostingService(),
    accountRolePolicy: AccountRolePolicy(accountRepository: accountRepository),
  );
}

Account _account(String id, AccountType type, {AccountSubtype? subtype}) {
  return Account(
    id: id,
    name: id,
    type: type,
    subtype: subtype,
    balance: const Money(minorUnits: 0),
  );
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(Iterable<Account> accounts)
    : _accounts = {for (final account in accounts) account.id: account};

  final Map<String, Account> _accounts;

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
  Future<List<Account>> findChildrenOf(String parentId) async {
    return [
      for (final account in _accounts.values)
        if (account.parentId == parentId && !account.isArchived) account,
    ];
  }

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

class _FakeSystemAccountResolver implements SystemAccountResolver {
  @override
  Future<String> resolveDiscountIncome() => throw UnimplementedError();

  @override
  Future<String> resolveFeeExpense() => throw UnimplementedError();

  @override
  Future<String> resolveGhostAccount() => throw UnimplementedError();

  @override
  Future<String> resolveInterestExpense() => throw UnimplementedError();

  @override
  Future<String> resolveOpeningBalance() => throw UnimplementedError();

  @override
  Future<String> resolveReimbursementGapIncome() => throw UnimplementedError();
}
