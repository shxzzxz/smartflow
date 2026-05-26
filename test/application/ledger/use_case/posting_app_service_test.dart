import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';
import 'package:smartflow/domain/ledger/valobj/post_receipt.dart';
import 'package:smartflow/application/ledger/use_case/receipt_builder.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/posting_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';

void main() {
  group('PostingAppService', () {
    late _RecordingPostingRepository postingRepository;
    late PostingAppService service;

    PostingAppServiceImpl buildService({
      AccountRepository? accountRepository,
    }) {
      final accounts = accountRepository ?? _defaultAccounts();
      return PostingAppServiceImpl(
        receiptBuilder: ReceiptBuilder(
          accounts: accounts,
          query: _StubQueryService(),
          systemAccounts: _StubSystemAccountResolver(),
        ),
        transactionQueryService: _StubQueryService(),
        accountRepository: accounts,
        postingRepository: postingRepository,
        transactionRunner: const _InlineTransactionRunner(),
      );
    }

    setUp(() {
      postingRepository = _RecordingPostingRepository();
      service = buildService();
    });

    test(
      'translates an expense command into posting details and entries',
      () async {
        final result = await service.createExpense(
          CreateExpenseCommand(
            amount: const Money(minorUnits: 2000),
            paidFromAccountId: 1,
            expenseAccountId: 101,
            occurredAt: DateTime(2026, 5),
            counterpartyName: 'Coffee shop',
            note: 'Latte',
          ),
        );

        expect(result, isA<Success<CreatedTransactionResult>>());
        final transaction = postingRepository.lastTransaction!;
        expect(transaction.businessPurpose, BusinessPurpose.dailyExpense);
        expect(transaction.primaryAmount, const Money(minorUnits: 2000));
        expect(transaction.counterpartyName, 'Coffee shop');
        expect(transaction.note, 'Latte');
        expect(transaction.details, hasLength(1));
        expect(
          transaction.details.single.type,
          TransactionDetailType.primaryExpense,
        );
        expect(
          transaction.details.single.amount,
          const Money(minorUnits: 2000),
        );
        expect(transaction.entries, hasLength(2));
        expect(transaction.entries[0].accountId, 101);
        expect(transaction.entries[0].direction, EntryDirection.debit);
        expect(transaction.entries[0].amount, const Money(minorUnits: 2000));
        expect(transaction.entries[1].accountId, 1);
        expect(transaction.entries[1].direction, EntryDirection.credit);
        expect(transaction.entries[1].amount, const Money(minorUnits: 2000));
      },
    );

    test(
      'translates an income command into posting details and entries',
      () async {
        final result = await service.createIncome(
          CreateIncomeCommand(
            amount: const Money(minorUnits: 1000000),
            receiveAccountId: 2,
            incomeAccountId: 201,
            occurredAt: DateTime(2026, 5),
          ),
        );

        expect(result, isA<Success<CreatedTransactionResult>>());
        final transaction = postingRepository.lastTransaction!;
        expect(transaction.businessPurpose, BusinessPurpose.dailyIncome);
        expect(
          transaction.details.single.type,
          TransactionDetailType.primaryIncome,
        );
        expect(transaction.entries, hasLength(2));
        expect(transaction.entries[0].accountId, 2);
        expect(transaction.entries[0].direction, EntryDirection.debit);
        expect(transaction.entries[1].accountId, 201);
        expect(transaction.entries[1].direction, EntryDirection.credit);
      },
    );

    test(
      'translates a transfer with fee into posting details and entries',
      () async {
        final result = await service.createTransfer(
          CreateTransferCommand(
            amount: const Money(minorUnits: 100000),
            fromAccountId: 2,
            toAccountId: 1,
            feeAmount: const Money(minorUnits: 200),
            feeExpenseAccountId: 103,
            occurredAt: DateTime(2026, 5),
          ),
        );

        expect(result, isA<Success<CreatedTransactionResult>>());
        final transaction = postingRepository.lastTransaction!;
        expect(transaction.businessPurpose, BusinessPurpose.transfer);
        expect(transaction.primaryAmount, const Money(minorUnits: 100000));
        expect(transaction.details.map((detail) => detail.type), [
          TransactionDetailType.transferMain,
          TransactionDetailType.transferFee,
        ]);
        expect(transaction.entries, hasLength(3));
        expect(transaction.entries[0].accountId, 1);
        expect(transaction.entries[0].direction, EntryDirection.debit);
        expect(transaction.entries[0].amount, const Money(minorUnits: 100000));
        expect(transaction.entries[1].accountId, 103);
        expect(transaction.entries[1].direction, EntryDirection.debit);
        expect(transaction.entries[1].amount, const Money(minorUnits: 200));
        expect(transaction.entries[2].accountId, 2);
        expect(transaction.entries[2].direction, EntryDirection.credit);
        expect(transaction.entries[2].amount, const Money(minorUnits: 100200));
      },
    );

    test('rejects a positive transfer fee without a fee account', () async {
      final result = await service.createTransfer(
        CreateTransferCommand(
          amount: const Money(minorUnits: 100000),
          fromAccountId: 2,
          toAccountId: 1,
          feeAmount: const Money(minorUnits: 200),
          occurredAt: DateTime(2026, 5),
        ),
      );

      expect(result, isA<FailureResult<CreatedTransactionResult>>());
      expect(postingRepository.lastTransaction, isNull);
    });

    test('rejects account used in the wrong transaction role', () async {
      service = buildService(
        accountRepository: _FakeAccountRepository({
          1: _account(id: 1, type: AccountType.expense),
          101: _account(id: 101, type: AccountType.expense),
        }),
      );

      final result = await service.createExpense(
        CreateExpenseCommand(
          amount: const Money(minorUnits: 2000),
          paidFromAccountId: 1,
          expenseAccountId: 101,
          occurredAt: DateTime(2026, 5),
        ),
      );

      expect(result, isA<FailureResult<CreatedTransactionResult>>());
      expect(postingRepository.lastTransaction, isNull);
    });

    test('rejects loan account as expense settlement account', () async {
      service = buildService(
        accountRepository: _FakeAccountRepository({
          1: _account(
            id: 1,
            type: AccountType.liability,
            subtype: AccountSubtype.loan,
          ),
          101: _account(id: 101, type: AccountType.expense),
        }),
      );

      final result = await service.createExpense(
        CreateExpenseCommand(
          amount: const Money(minorUnits: 2000),
          paidFromAccountId: 1,
          expenseAccountId: 101,
          occurredAt: DateTime(2026, 5),
        ),
      );

      expect(result, isA<FailureResult<CreatedTransactionResult>>());
      expect(postingRepository.lastTransaction, isNull);
    });

    test('rejects loan account as income receive account', () async {
      service = buildService(
        accountRepository: _FakeAccountRepository({
          1: _account(
            id: 1,
            type: AccountType.liability,
            subtype: AccountSubtype.loan,
          ),
          201: _account(id: 201, type: AccountType.income),
        }),
      );

      final result = await service.createIncome(
        CreateIncomeCommand(
          amount: const Money(minorUnits: 2000),
          receiveAccountId: 1,
          incomeAccountId: 201,
          occurredAt: DateTime(2026, 5),
        ),
      );

      expect(result, isA<FailureResult<CreatedTransactionResult>>());
      expect(postingRepository.lastTransaction, isNull);
    });

    test('rejects loan account in transfers', () async {
      service = buildService(
        accountRepository: _FakeAccountRepository({
          1: _account(id: 1, type: AccountType.asset),
          2: _account(
            id: 2,
            type: AccountType.liability,
            subtype: AccountSubtype.loan,
          ),
        }),
      );

      final result = await service.createTransfer(
        CreateTransferCommand(
          amount: const Money(minorUnits: 2000),
          fromAccountId: 1,
          toAccountId: 2,
          occurredAt: DateTime(2026, 5),
        ),
      );

      expect(result, isA<FailureResult<CreatedTransactionResult>>());
      expect(postingRepository.lastTransaction, isNull);
    });
  });
}

class _RecordingPostingRepository implements PostingRepository {
  Transaction? lastTransaction;

  @override
  Future<PostReceiptResult> saveTransaction(Transaction transaction) async {
    lastTransaction = transaction;
    return const PostReceiptResult(transactionId: 1, rootTransactionId: 1);
  }

  @override
  Future<void> saveAccounts(Iterable<Account> accounts) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not stubbed in _RecordingPostingRepository.',
    );
  }
}

class _FakeAccountRepository implements AccountRepository {
  const _FakeAccountRepository(this.accounts);

  final Map<int, Account> accounts;

  @override
  Future<List<Account>> findAccountsByIds(Set<int> ids) async {
    return [
      for (final id in ids)
        if (accounts[id] != null) accounts[id]!,
    ];
  }

  @override
  Future<Account?> findAccountById(int id) {
    throw UnimplementedError();
  }

  @override
  Stream<List<Account>> watchAccounts(Set<AccountType> types) {
    throw UnimplementedError();
  }

  @override
  Future<Account> createAccount(spec) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateAccount(id, spec) {
    throw UnimplementedError();
  }
}

Account _account({
  required int id,
  required AccountType type,
  AccountSubtype? subtype,
}) {
  return Account(
    id: id,
    name: 'Account $id',
    type: type,
    subtype: subtype,
    balance: Money.zero(),
  );
}

_FakeAccountRepository _defaultAccounts() {
  return _FakeAccountRepository({
    1: _account(id: 1, type: AccountType.asset),
    2: _account(id: 2, type: AccountType.asset),
    101: _account(id: 101, type: AccountType.expense),
    103: _account(id: 103, type: AccountType.expense),
    201: _account(id: 201, type: AccountType.income),
  });
}

class _StubQueryService implements TransactionQueryService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not stubbed in _StubQueryService.',
    );
  }
}

class _StubSystemAccountResolver implements SystemAccountResolver {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '${invocation.memberName} is not stubbed in _StubSystemAccountResolver.',
    );
  }
}

class _InlineTransactionRunner implements TransactionRunner {
  const _InlineTransactionRunner();

  @override
  Future<Result<T>> run<T>(Future<Result<T>> Function() body) => body();
}
