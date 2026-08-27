import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';

void main() {
  test('migrates each matched group through category replacement', () async {
    final editService = _RecordingEditService();
    final service = _service(
      accounts: [_category('source'), _category('target')],
      targets: const [
        CategoryTransactionTarget(
          transactionId: 'expense-1',
          businessPurpose: BusinessPurpose.dailyExpense,
        ),
        CategoryTransactionTarget(
          transactionId: 'income-1',
          businessPurpose: BusinessPurpose.dailyIncome,
        ),
        CategoryTransactionTarget(
          transactionId: 'advance-1',
          businessPurpose: BusinessPurpose.reimbursementAdvance,
        ),
      ],
      editService: editService,
    );

    final result = await service.migrate(
      const CategoryTransactionMigrationCommand(
        sourceCategoryId: 'source',
        targetCategoryId: 'target',
      ),
    );

    expect(result.migratedGroupCount, 3);
    expect(editService.commands.map((command) => command.transactionId), [
      'expense-1',
      'income-1',
      'advance-1',
    ]);
    expect(editService.commands.map((command) => command.businessPurpose), [
      BusinessPurpose.dailyExpense,
      BusinessPurpose.dailyIncome,
      BusinessPurpose.reimbursementAdvance,
    ]);
    expect(editService.commands.first.sourceCategoryId, 'source');
    expect(editService.commands.first.targetCategoryId, 'target');
  });

  test('succeeds with zero migrated groups when nothing matches', () async {
    final service = _service(
      accounts: [_category('source'), _category('target')],
    );

    final result = await service.migrate(
      const CategoryTransactionMigrationCommand(
        sourceCategoryId: 'source',
        targetCategoryId: 'target',
      ),
    );

    expect(result.migratedGroupCount, 0);
  });

  test('rejects missing source or target category', () async {
    final service = _service(accounts: [_category('source')]);

    await expectLater(
      () => service.migrate(
        const CategoryTransactionMigrationCommand(
          sourceCategoryId: 'missing',
          targetCategoryId: 'source',
        ),
      ),
      throwsA(_hasCode(LedgerErrorCode.categoryNotFound)),
    );
    await expectLater(
      () => service.migrate(
        const CategoryTransactionMigrationCommand(
          sourceCategoryId: 'source',
          targetCategoryId: 'missing',
        ),
      ),
      throwsA(_hasCode(LedgerErrorCode.categoryNotFound)),
    );
  });

  test('rejects archived source or target category', () async {
    final service = _service(
      accounts: [_category('source'), _category('archived', archived: true)],
    );

    await expectLater(
      () => service.migrate(
        const CategoryTransactionMigrationCommand(
          sourceCategoryId: 'archived',
          targetCategoryId: 'source',
        ),
      ),
      throwsA(_hasCode(LedgerErrorCode.categoryUnavailable)),
    );
    await expectLater(
      () => service.migrate(
        const CategoryTransactionMigrationCommand(
          sourceCategoryId: 'source',
          targetCategoryId: 'archived',
        ),
      ),
      throwsA(_hasCode(LedgerErrorCode.categoryUnavailable)),
    );
  });

  test('rejects target equal to source', () async {
    final service = _service(accounts: [_category('source')]);

    await expectLater(
      () => service.migrate(
        const CategoryTransactionMigrationCommand(
          sourceCategoryId: 'source',
          targetCategoryId: 'source',
        ),
      ),
      throwsA(_hasCode(LedgerErrorCode.categoryInvalidCommand)),
    );
  });

  test('rejects target of a different category type', () async {
    final service = _service(
      accounts: [
        _category('source'),
        _category('income-target', type: AccountType.income),
      ],
    );

    await expectLater(
      () => service.migrate(
        const CategoryTransactionMigrationCommand(
          sourceCategoryId: 'source',
          targetCategoryId: 'income-target',
        ),
      ),
      throwsA(_hasCode(LedgerErrorCode.categoryInvalidCommand)),
    );
  });

  test('rejects a system source before querying or rewriting groups', () async {
    final transactionRead = _FakeTransactionReadRepository(const [
      CategoryTransactionTarget(
        transactionId: 'system-transaction',
        businessPurpose: BusinessPurpose.dailyExpense,
      ),
    ]);
    final editService = _RecordingEditService();
    final service = _service(
      accounts: [
        _category('system-source', systemKey: SystemKey.feeExpense),
        _category('target'),
      ],
      transactionRead: transactionRead,
      editService: editService,
    );

    await expectLater(
      () => service.migrate(
        const CategoryTransactionMigrationCommand(
          sourceCategoryId: 'system-source',
          targetCategoryId: 'target',
        ),
      ),
      throwsA(_hasCode(LedgerErrorCode.categoryUnavailable)),
    );
    expect(transactionRead.queriedCategoryIds, isEmpty);
    expect(editService.commands, isEmpty);
  });

  test('rejects a system target before querying or rewriting groups', () async {
    final transactionRead = _FakeTransactionReadRepository(const [
      CategoryTransactionTarget(
        transactionId: 'expense-1',
        businessPurpose: BusinessPurpose.dailyExpense,
      ),
    ]);
    final editService = _RecordingEditService();
    final service = _service(
      accounts: [
        _category('source'),
        _category('system-target', systemKey: SystemKey.feeExpense),
      ],
      transactionRead: transactionRead,
      editService: editService,
    );

    await expectLater(
      () => service.migrate(
        const CategoryTransactionMigrationCommand(
          sourceCategoryId: 'source',
          targetCategoryId: 'system-target',
        ),
      ),
      throwsA(_hasCode(LedgerErrorCode.categoryUnavailable)),
    );
    expect(transactionRead.queriedCategoryIds, isEmpty);
    expect(editService.commands, isEmpty);
  });

  test('propagates a failed group rewrite without continuing', () async {
    final editService = _RecordingEditService(failOnTransactionId: 'expense-2');
    final service = _service(
      accounts: [_category('source'), _category('target')],
      targets: const [
        CategoryTransactionTarget(
          transactionId: 'expense-1',
          businessPurpose: BusinessPurpose.dailyExpense,
        ),
        CategoryTransactionTarget(
          transactionId: 'expense-2',
          businessPurpose: BusinessPurpose.dailyExpense,
        ),
        CategoryTransactionTarget(
          transactionId: 'expense-3',
          businessPurpose: BusinessPurpose.dailyExpense,
        ),
      ],
      editService: editService,
    );

    await expectLater(
      () => service.migrate(
        const CategoryTransactionMigrationCommand(
          sourceCategoryId: 'source',
          targetCategoryId: 'target',
        ),
      ),
      throwsA(_hasCode(LedgerErrorCode.transactionPostingFailed)),
    );
    expect(editService.commands.map((command) => command.transactionId), [
      'expense-1',
      'expense-2',
    ]);
  });
}

Matcher _hasCode(LedgerErrorCode code) {
  return isA<BusinessException>().having(
    (exception) => exception.code,
    'code',
    code.code,
  );
}

Account _category(
  String id, {
  AccountType type = AccountType.expense,
  bool archived = false,
  SystemKey? systemKey,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    balance: const Money(minorUnits: 0),
    archivedAt: archived ? DateTime(2026) : null,
    systemKey: systemKey,
  );
}

CategoryTransactionMigrationAppServiceImpl _service({
  required Iterable<Account> accounts,
  List<CategoryTransactionTarget> targets = const [],
  _FakeTransactionReadRepository? transactionRead,
  _RecordingEditService? editService,
}) {
  return CategoryTransactionMigrationAppServiceImpl(
    accountRepository: _FakeAccountRepository(accounts),
    transactionReadRepository:
        transactionRead ?? _FakeTransactionReadRepository(targets),
    editService: editService ?? _RecordingEditService(),
    transactionRunner: _PassthroughTransactionRunner(),
  );
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(Iterable<Account> accounts)
    : _accounts = {for (final account in accounts) account.id: account};

  final Map<String, Account> _accounts;

  @override
  Future<Account?> findById(String id) async => _accounts[id];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeTransactionReadRepository implements TransactionReadRepository {
  _FakeTransactionReadRepository(this._targets);

  final List<CategoryTransactionTarget> _targets;
  final queriedCategoryIds = <String>[];

  @override
  Future<List<CategoryTransactionTarget>> findCategoryTransactionTargets(
    String categoryId,
  ) async {
    queriedCategoryIds.add(categoryId);
    return _targets;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _RecordingEditService implements TransactionEditAppService {
  _RecordingEditService({this.failOnTransactionId});

  final String? failOnTransactionId;
  final commands = <ReplaceTransactionCategoryCommand>[];

  @override
  Future<PostedTransactionResult> replaceTransactionCategory(
    ReplaceTransactionCategoryCommand command,
  ) {
    commands.add(command);
    return _complete(command.transactionId);
  }

  Future<PostedTransactionResult> _complete(String transactionId) async {
    if (transactionId == failOnTransactionId) {
      throw BusinessException(LedgerErrorCode.transactionPostingFailed);
    }
    return PostedTransactionResult(transactionId: transactionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _PassthroughTransactionRunner implements TransactionRunner {
  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}
