import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/import/import_workflow_app_service.dart';
import 'package:smartflow/application/import/import_workflow_models.dart';
import 'package:smartflow/application/ledger/account/query/account_query_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_edit_app_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_ledger_writer.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_posting_app_service.dart';
import 'package:smartflow/application/ledger/transaction/query/transaction_query_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/import/import_error_code.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/import_persistence_models.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/import/ledger_import_port.dart';
import 'package:smartflow/infrastructure/import/repository/drift_import_batch_repository.dart';
import 'package:smartflow/infrastructure/import/repository/drift_import_mapping_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_query_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_entry_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_ledger_metrics_source.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_system_account_resolver.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_detail_read_repository.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_read_repository.dart';

import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  test(
    'commits groups atomically, records duplicates, and reverts idempotently',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      final plan = _expenseRefundAndNoAccountIncomePlan();
      await fixture.saveMappings(plan.sourceEntities);

      final review = await fixture.service.review(plan);
      expect(review.defaultMappings, hasLength(3));
      expect(review.groups.every((group) => group.canSelect), isTrue);

      final result = await fixture.service.commit(
        ImportCommitCommand(
          plan: plan,
          mappings: review.effectiveMappings,
          selectedGroupIndexes: {0, 1},
          importedAt: DateTime(2026, 4, 7),
        ),
      );
      expect(result.batch?.importedGroupCount, 2);
      expect(result.batch?.createdTransactionCount, 3);
      expect(result.batch?.skippedGroupCount, 0);

      final rows =
          await fixture.database.select(fixture.database.transactions).get();
      expect(rows, hasLength(3));
      expect(rows.every((row) => row.sourceKind == SourceKind.import), isTrue);
      final expense = rows.singleWhere(
        (row) => row.businessPurpose == BusinessPurpose.dailyExpense,
      );
      expect(expense.occurredAt, DateTime(2026, 4, 4, 12, 55));
      expect(expense.postedAt, DateTime(2026, 4, 5));
      expect(
        rows
            .singleWhere((row) => row.businessPurpose == BusinessPurpose.refund)
            .parentTransactionId,
        expense.id,
      );
      expect(
        rows
            .singleWhere(
              (row) => row.businessPurpose == BusinessPurpose.dailyIncome,
            )
            .isExcludedFromBudget,
        isTrue,
      );

      final duplicateResult = await fixture.service.commit(
        ImportCommitCommand(
          plan: plan,
          mappings: review.effectiveMappings,
          selectedGroupIndexes: {0, 1},
        ),
      );
      expect(duplicateResult.batch, isNull);
      expect(duplicateResult.skippedGroupCount, 2);
      expect(await fixture.service.listBatches(), hasLength(1));

      final batchId = result.batch!.id;
      final reverted = await fixture.service.revertBatch(
        batchId,
        revertedAt: DateTime(2026, 4, 8),
      );
      expect(reverted.status, ImportBatchStatus.reverted);
      expect(
        await fixture.database.select(fixture.database.transactions).get(),
        isEmpty,
      );
      expect((await fixture.accounts.findById('cash'))?.balance, Money.zero());

      final repeated = await fixture.service.revertBatch(batchId);
      expect(repeated.status, ImportBatchStatus.reverted);
      expect(repeated.revertedAt, DateTime(2026, 4, 8));
      expect(await fixture.service.findBatchItems(batchId), hasLength(2));
    },
  );

  test(
    'a later ledger failure rolls back earlier groups and batch rows',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      final base = _expenseRefundAndNoAccountIncomePlan();
      final invalidPlan = ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: base.sourceEntities,
        groups: [
          base.groups.first,
          ImportTransactionGroupDraft(
            topLevel: ImportTransferDraft(
              amount: Money.parse('10'),
              fromAccount: _accountReference('cash'),
              toAccount: _accountReference('cash'),
              occurredAt: DateTime(2026, 4, 6),
            ),
            sourceOperationKey: 'operation-invalid',
            sourceOperationFingerprint: 'fingerprint-invalid',
            fingerprintVersion: 1,
          ),
        ],
      );
      await fixture.saveMappings(invalidPlan.sourceEntities);
      final review = await fixture.service.review(invalidPlan);

      await expectLater(
        () => fixture.service.commit(
          ImportCommitCommand(
            plan: invalidPlan,
            mappings: review.effectiveMappings,
            selectedGroupIndexes: {0, 1},
          ),
        ),
        throwsA(
          isA<ImportWorkflowException>()
              .having(
                (error) => error.code,
                'code',
                ImportErrorCode.commitFailed.code,
              )
              .having((error) => error.groupIndex, 'groupIndex', 1),
        ),
      );

      expect(
        await fixture.database.select(fixture.database.transactions).get(),
        isEmpty,
      );
      expect(
        await fixture.database.select(fixture.database.importBatches).get(),
        isEmpty,
      );
      expect((await fixture.accounts.findById('cash'))?.balance, Money.zero());
    },
  );

  test(
    'review edits and group mapping overrides keep source identity at commit',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      await _insertAccount(fixture.database, 'card', '银行卡', AccountType.asset);
      final base = _expenseRefundAndNoAccountIncomePlan();
      final original = base.groups.first;
      final edited = original.copyWith(
        topLevel: applyImportDraftEdit(
          original.topLevel,
          ImportDraftEdit(
            amount: Money.parse('80'),
            occurredAt: DateTime(2026, 4, 9, 8, 30),
            postedAt: DateTime(2026, 4, 10),
            note: const Patch.set('审阅后修正'),
          ),
        ),
        children: const [],
      );
      final plan = base.copyWith(groups: [edited]);
      await fixture.saveMappings(plan.sourceEntities);
      const accountKey = ImportMappingKey(
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.account,
        sourceEntityKey: 'account:cash',
      );
      final review = await fixture.service.review(
        plan,
        groupMappingOverrides: {
          0: {accountKey: 'card'},
        },
      );

      final result = await fixture.service.commit(
        ImportCommitCommand(
          plan: review.plan,
          mappings: review.effectiveMappings,
          groupMappingOverrides: review.groupMappingOverrides,
          selectedGroupIndexes: const {0},
        ),
      );

      expect(result.batch?.importedGroupCount, 1);
      expect((await fixture.accounts.findById('cash'))?.balance, Money.zero());
      expect(
        (await fixture.accounts.findById('card'))?.balance,
        Money.parse('-80'),
      );
      final transaction =
          (await fixture.database.select(fixture.database.transactions).get())
              .single;
      expect(transaction.occurredAt, DateTime(2026, 4, 9, 8, 30));
      expect(transaction.postedAt, DateTime(2026, 4, 10));
      expect(transaction.note, '审阅后修正');
      final item =
          (await fixture.service.findBatchItems(result.batch!.id)).single;
      expect(
        item.sourceOperationFingerprint,
        original.sourceOperationFingerprint,
      );
      expect(item.sourceOperationKey, original.sourceOperationKey);
    },
  );

  test('ordinary warnings require confirmation before commit', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);
    final base = _expenseRefundAndNoAccountIncomePlan();
    final plan = base.copyWith(
      groups: [
        base.groups.first.copyWith(
          children: const [],
          issues: const [
            ImportIssue(
              code: 'review_warning',
              message: '请确认解析结果。',
              severity: ImportIssueSeverity.warning,
            ),
          ],
        ),
      ],
    );
    await fixture.saveMappings(plan.sourceEntities);
    final review = await fixture.service.review(plan);

    final skipped = await fixture.service.commit(
      ImportCommitCommand(
        plan: plan,
        mappings: review.effectiveMappings,
        selectedGroupIndexes: const {0},
      ),
    );
    expect(skipped.batch, isNull);

    final committed = await fixture.service.commit(
      ImportCommitCommand(
        plan: plan,
        mappings: review.effectiveMappings,
        selectedGroupIndexes: const {0},
        confirmedWarningIndexes: const {0},
      ),
    );
    expect(committed.batch?.importedGroupCount, 1);
  });

  test(
    'duplicate source operation keys block only conflicting groups',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      final base = _expenseRefundAndNoAccountIncomePlan();
      final duplicate = ImportTransactionGroupDraft(
        topLevel: base.groups.first.topLevel,
        children: base.groups.first.children,
        sourceOperationKey: base.groups.first.sourceOperationKey,
        sourceOperationFingerprint: 'fingerprint-duplicate',
        fingerprintVersion: base.groups.first.fingerprintVersion,
      );
      final plan = base.copyWith(
        groups: [base.groups.first, duplicate, base.groups.last],
      );
      await fixture.saveMappings(plan.sourceEntities);

      final review = await fixture.service.review(plan);
      expect(review.groups[0].isBlocked, isTrue);
      expect(review.groups[1].isBlocked, isTrue);
      expect(review.groups[2].isBlocked, isFalse);
      expect(
        review.groups[0].issues,
        contains(
          isA<ImportIssue>().having(
            (issue) => issue.code,
            'code',
            'duplicate_source_operation_key',
          ),
        ),
      );

      final legalCommit = await fixture.service.commit(
        ImportCommitCommand(
          plan: plan,
          mappings: review.effectiveMappings,
          selectedGroupIndexes: const {2},
        ),
      );
      expect(legalCommit.batch?.importedGroupCount, 1);

      await expectLater(
        () => fixture.service.commit(
          ImportCommitCommand(
            plan: plan,
            mappings: review.effectiveMappings,
            selectedGroupIndexes: const {0},
          ),
        ),
        throwsA(
          isA<ImportWorkflowException>()
              .having(
                (error) => error.code,
                'code',
                ImportErrorCode.selectedGroupBlocked.code,
              )
              .having((error) => error.groupIndex, 'groupIndex', 0),
        ),
      );
    },
  );

  test('mapping suggestions honor each source entity usage role', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);
    await _insertAccount(
      fixture.database,
      'asset-match',
      '同名账户',
      AccountType.asset,
    );
    await _insertAccount(
      fixture.database,
      'liability-match',
      '同名账户',
      AccountType.liability,
    );
    await _insertAccount(
      fixture.database,
      'debt-match',
      '债务账户',
      AccountType.liability,
    );
    const receiveKey = 'account:同名账户';
    const liabilityKey = 'account:债务账户';
    final plan = ImportParseResult(
      source: ImportSource.yimu,
      sourceEntities: const [
        ImportSourceEntity(
          source: ImportSource.yimu,
          kind: ImportEntityKind.account,
          sourceEntityKey: receiveKey,
          displayName: '同名账户',
        ),
        ImportSourceEntity(
          source: ImportSource.yimu,
          kind: ImportEntityKind.account,
          sourceEntityKey: liabilityKey,
          displayName: '债务账户',
        ),
      ],
      groups: [
        ImportTransactionGroupDraft(
          topLevel: ImportBorrowingDraft(
            amount: Money.parse('100'),
            liabilityAccount: const ImportAccountReference.source(
              sourceEntityKey: liabilityKey,
              displayName: '债务账户',
            ),
            receiveAccount: const ImportAccountReference.source(
              sourceEntityKey: receiveKey,
              displayName: '同名账户',
            ),
            occurredAt: DateTime(2026, 4, 1),
          ),
          sourceOperationFingerprint: 'borrowing-fingerprint',
          fingerprintVersion: 1,
        ),
      ],
    );

    final review = await fixture.service.review(plan);
    final suggestions = {
      for (final suggestion in review.suggestions)
        suggestion.key.sourceEntityKey: suggestion.targetAccountId,
    };
    expect(suggestions[receiveKey], 'asset-match');
    expect(suggestions[liabilityKey], 'debt-match');
  });

  test('a group mapping repairs a parser missing-account blocker', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);
    const missingKey = 'review:missing:account:transfer:2:from';
    const categoryKey = 'category:expense:餐饮 / 生鲜';
    final plan = ImportParseResult(
      source: ImportSource.yimu,
      sourceEntities: const [
        ImportSourceEntity(
          source: ImportSource.yimu,
          kind: ImportEntityKind.account,
          sourceEntityKey: missingKey,
          displayName: '缺失转出账户（转账文件第 2 行）',
          isReviewPlaceholder: true,
        ),
        ImportSourceEntity(
          source: ImportSource.yimu,
          kind: ImportEntityKind.category,
          sourceEntityKey: categoryKey,
          displayName: '餐饮 / 生鲜',
          categoryKind: ImportCategoryKind.expense,
        ),
      ],
      groups: [
        ImportTransactionGroupDraft(
          topLevel: ImportExpenseDraft(
            amount: Money.parse('25.00'),
            paidFrom: const ImportAccountReference.unresolved(
              sourceEntityKey: missingKey,
              displayName: '缺失转出账户（转账文件第 2 行）',
            ),
            category: const ImportCategoryReference(
              sourceEntityKey: categoryKey,
              path: '餐饮 / 生鲜',
              kind: ImportCategoryKind.expense,
            ),
            occurredAt: DateTime(2026, 4, 6),
          ),
          sourceOperationFingerprint: 'missing-account-fingerprint',
          fingerprintVersion: 1,
          issues: const [
            ImportIssue(
              code: 'account_missing',
              message: '来源账户为空。',
              severity: ImportIssueSeverity.blocking,
            ),
          ],
        ),
      ],
    );
    final review = await fixture.service.review(
      plan,
      temporaryMappings: {
        const ImportMappingKey(
              source: ImportSource.yimu,
              entityKind: ImportEntityKind.account,
              sourceEntityKey: missingKey,
            ):
            'cash',
        const ImportMappingKey(
              source: ImportSource.yimu,
              entityKind: ImportEntityKind.category,
              sourceEntityKey: categoryKey,
            ):
            'food',
      },
    );

    expect(review.groups.single.isBlocked, isFalse);
    expect(review.groups.single.canSelect, isTrue);
    expect(review.suggestions, isEmpty);
  });

  test(
    'review exposes an archived default target for explicit remapping',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      const entity = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:cash',
        displayName: '现金',
      );
      await fixture.service.saveDefaultMapping(
        entity: entity,
        targetAccountId: 'cash',
      );
      final cash = await fixture.accounts.findById('cash');
      cash!.archive(DateTime(2026, 4, 7));
      await fixture.accounts.save(cash);
      final plan = ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [entity],
        groups: [
          ImportTransactionGroupDraft(
            topLevel: ImportTransferDraft(
              amount: Money.parse('10.00'),
              fromAccount: const ImportAccountReference.source(
                sourceEntityKey: 'account:cash',
                displayName: '现金',
              ),
              toAccount: const ImportAccountReference.source(
                sourceEntityKey: 'account:cash',
                displayName: '现金',
              ),
              occurredAt: DateTime(2026, 4, 6),
            ),
            sourceOperationFingerprint: 'archived-target-fingerprint',
            fingerprintVersion: 1,
          ),
        ],
      );

      final review = await fixture.service.review(plan);

      expect(
        review.targets.singleWhere((target) => target.id == 'cash').isArchived,
        isTrue,
      );
      expect(review.groups.single.isBlocked, isTrue);
    },
  );
}

class _Fixture {
  _Fixture._({
    required this.database,
    required this.accounts,
    required this.service,
  });

  final AppDatabase database;
  final DriftAccountRepository accounts;
  final ImportWorkflowAppServiceImpl service;

  static Future<_Fixture> create() async {
    final database = createTestDatabase();
    await _insertAccount(database, 'cash', '现金', AccountType.asset);
    await _insertAccount(database, 'food', '餐饮 / 生鲜', AccountType.expense);
    await _insertAccount(database, 'salary', '收入 / 工资', AccountType.income);

    final ids = SequentialIdGenerator(prefix: 'import');
    final runner = DriftTransactionRunner(database);
    final accounts = DriftAccountRepository(database);
    final postings = DriftPostingRepository(database);
    final systemAccounts = DriftSystemAccountResolver(database);
    final writer = TransactionLedgerWriter(
      transactionRunner: runner,
      transactionRepository: postings,
      transactionGroupRepository: postings,
      accountRepository: accounts,
    );
    final posting = TransactionPostingAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: postings,
      systemAccountResolver: systemAccounts,
      ledgerWriter: writer,
      idGenerator: ids,
    );
    final editing = TransactionEditAppServiceImpl(
      accountRepository: accounts,
      transactionGroupRepository: postings,
      systemAccountResolver: systemAccounts,
      ledgerWriter: writer,
      idGenerator: ids,
    );
    final accountQuery = AccountQueryServiceImpl(
      accounts: DriftAccountQueryRepository(database),
    );
    final transactionQuery = TransactionQueryServiceImpl(
      transactionRead: DriftTransactionReadRepository(database),
      entryRead: DriftEntryReadRepository(database),
      detailRead: DriftTransactionDetailReadRepository(database),
      metricsSource: DriftLedgerMetricsSource(database),
    );
    final ledger = LedgerImportPort(
      posting: posting,
      editing: editing,
      transactions: transactionQuery,
      accounts: accountQuery,
      systemAccounts: systemAccounts,
    );
    return _Fixture._(
      database: database,
      accounts: accounts,
      service: ImportWorkflowAppServiceImpl(
        mappings: DriftImportMappingRepository(database),
        batches: DriftImportBatchRepository(database),
        ledger: ledger,
        transactionRunner: runner,
        idGenerator: ids,
        now: () => DateTime(2026, 4, 6),
      ),
    );
  }

  Future<void> saveMappings(List<ImportSourceEntity> entities) async {
    for (final entity in entities) {
      final targetId = switch (entity.sourceEntityKey) {
        'account:cash' => 'cash',
        'category:expense:餐饮 / 生鲜' => 'food',
        'category:income:收入 / 工资' => 'salary',
        _ => throw StateError('Unknown test entity ${entity.sourceEntityKey}'),
      };
      await service.saveDefaultMapping(
        entity: entity,
        targetAccountId: targetId,
      );
    }
  }
}

ImportParseResult _expenseRefundAndNoAccountIncomePlan() {
  return ImportParseResult(
    source: ImportSource.yimu,
    sourceEntities: const [
      ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:cash',
        displayName: '现金',
      ),
      ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.category,
        sourceEntityKey: 'category:expense:餐饮 / 生鲜',
        displayName: '餐饮 / 生鲜',
        categoryKind: ImportCategoryKind.expense,
      ),
      ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.category,
        sourceEntityKey: 'category:income:收入 / 工资',
        displayName: '收入 / 工资',
        categoryKind: ImportCategoryKind.income,
      ),
    ],
    groups: [
      ImportTransactionGroupDraft(
        topLevel: ImportExpenseDraft(
          amount: Money.parse('70'),
          paidFrom: _accountReference('cash'),
          category: _expenseCategory,
          occurredAt: DateTime(2026, 4, 4, 12, 55),
          postedAt: DateTime(2026, 4, 5),
          note: '生鲜',
        ),
        children: [
          ImportRefundDraft(
            amount: Money.parse('2'),
            refundTo: _accountReference('cash'),
            occurredAt: DateTime(2026, 4, 4, 13),
          ),
        ],
        sourceOperationKey: 'operation-expense',
        sourceOperationFingerprint: 'fingerprint-expense',
        fingerprintVersion: 1,
      ),
      ImportTransactionGroupDraft(
        topLevel: ImportIncomeDraft(
          amount: Money.parse('1500'),
          receiveAccount: const ImportAccountReference.explicitNone(),
          category: _incomeCategory,
          occurredAt: DateTime(2026, 3, 11, 10, 19),
          isExcludedFromBudget: true,
        ),
        sourceOperationKey: 'operation-income',
        sourceOperationFingerprint: 'fingerprint-income',
        fingerprintVersion: 1,
      ),
    ],
  );
}

const _expenseCategory = ImportCategoryReference(
  sourceEntityKey: 'category:expense:餐饮 / 生鲜',
  path: '餐饮 / 生鲜',
  kind: ImportCategoryKind.expense,
);

const _incomeCategory = ImportCategoryReference(
  sourceEntityKey: 'category:income:收入 / 工资',
  path: '收入 / 工资',
  kind: ImportCategoryKind.income,
);

ImportAccountReference _accountReference(String name) {
  return ImportAccountReference.source(
    sourceEntityKey: 'account:$name',
    displayName: name,
  );
}

Future<void> _insertAccount(
  AppDatabase database,
  String id,
  String name,
  AccountType type,
) {
  return database
      .into(database.accounts)
      .insert(AccountsCompanion.insert(id: id, name: name, accountType: type));
}
