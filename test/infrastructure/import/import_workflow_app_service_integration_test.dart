import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:smartflow/application/import/import_workflow_app_service.dart';
import 'package:smartflow/application/import/import_workflow_models.dart';
import 'package:smartflow/application/credit/account/command/credit_account_app_service.dart';
import 'package:smartflow/application/ledger/account/command/account_app_service.dart';
import 'package:smartflow/application/ledger/account/query/account_query_service.dart';
import 'package:smartflow/application/ledger/category/command/category_app_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_edit_app_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_ledger_writer.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_posting_app_service.dart';
import 'package:smartflow/application/ledger/transaction/query/transaction_query_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/import/import_error_code.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/import_persistence_models.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/import/ledger_import_port.dart';
import 'package:smartflow/infrastructure/credit/adapter/ledger_credit_account_port.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_account_repository.dart';
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
    'creates a credit account with centralized import cycle defaults',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      const creditEntity = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:来源信用卡',
        displayName: '来源信用卡',
        allowedTargetDescriptors: {ImportTargetDescriptor.creditAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.creditAccount,
      );
      final plan = ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [creditEntity],
        groups: [
          ImportTransactionGroupDraft(
            topLevel: ImportOpeningBalanceDraft(
              amount: Money.parse('500'),
              liabilityAccount: const ImportAccountReference.source(
                sourceEntityKey: 'account:来源信用卡',
                displayName: '来源信用卡',
              ),
              occurredAt: DateTime(2026, 4, 6),
            ),
            sourceOperationFingerprint: 'credit-account-fingerprint',
            fingerprintVersion: 1,
          ),
        ],
      );
      final review = await fixture.service.review(plan);

      await fixture.service.commit(
        ImportCommitCommand(
          plan: plan,
          mappings: review.effectiveMappings,
          plannedCreations: review.plannedCreations,
          selectedGroupIndexes: const {0},
        ),
      );

      final account = (await fixture.database
              .select(fixture.database.accounts)
              .get())
          .singleWhere((row) => row.name == '来源信用卡');
      expect(account.accountProfileKey, 'credit.credit');
      final extension = (await fixture.database
              .select(fixture.database.creditLiabilityAccounts)
              .get())
          .singleWhere((row) => row.accountId == account.id);
      expect(extension.kind, CreditLiabilityAccountKind.credit);
      expect(extension.billingDay, 1);
      expect(extension.repaymentDay, 15);
      expect(extension.billingDayToNext, isTrue);
    },
  );

  test(
    'creates a debt-source liability as a loan account with credit extension',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      const loanEntity = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:来源贷款',
        displayName: '来源贷款',
        allowedTargetDescriptors: {ImportTargetDescriptor.loanAccount},
        preferredTargetDescriptor: ImportTargetDescriptor.loanAccount,
      );
      final plan = ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [loanEntity],
        groups: [
          ImportTransactionGroupDraft(
            topLevel: ImportOpeningBalanceDraft(
              amount: Money.parse('1000'),
              liabilityAccount: const ImportAccountReference.source(
                sourceEntityKey: 'account:来源贷款',
                displayName: '来源贷款',
              ),
              occurredAt: DateTime(2026, 4, 6),
            ),
            sourceOperationFingerprint: 'loan-account-fingerprint',
            fingerprintVersion: 1,
          ),
        ],
      );
      final review = await fixture.service.review(plan);
      final creation = review.plannedCreations.values.single;
      expect(creation.effectiveDescriptor, ImportTargetDescriptor.loanAccount);
      final mappingItem = review.mappingItems.single;
      expect(mappingItem.sourceDescription, '账户');
      expect(mappingItem.action, ImportMappingAction.create);
      expect(mappingItem.targetDescription, '贷款账户');
      expect(
        mappingItem.creationOptions.map((option) => option.effectiveDescriptor),
        [ImportTargetDescriptor.loanAccount],
      );
      expect(
        mappingItem.existingTargetOptions,
        everyElement(
          isA<ImportMappingTarget>().having(
            (target) => target.effectiveDescriptor,
            'descriptor',
            ImportTargetDescriptor.loanAccount,
          ),
        ),
      );

      final result = await fixture.service.commit(
        ImportCommitCommand(
          plan: plan,
          mappings: review.effectiveMappings,
          plannedCreations: review.plannedCreations,
          selectedGroupIndexes: const {0},
        ),
      );
      expect(result.createdBatch, isTrue);
      final account = (await fixture.database
              .select(fixture.database.accounts)
              .get())
          .singleWhere((row) => row.name == '来源贷款');
      expect(account.accountProfileKey, 'credit.loan');
      final extensions =
          await fixture.database
              .select(fixture.database.creditLiabilityAccounts)
              .get();
      final extension = extensions.singleWhere(
        (row) => row.accountId == account.id,
      );
      expect(extension.kind, CreditLiabilityAccountKind.loan);
      expect(extension.billingDay, isNull);
      expect(extension.repaymentDay, isNull);
    },
  );

  test(
    'creates missing category parents once and maps the leaf category',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      const account = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:cash',
        displayName: '现金',
      );
      const category = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.category,
        sourceEntityKey: 'category:expense:临时食品 / 临时午餐',
        displayName: '临时食品 / 临时午餐',
        categoryKind: ImportCategoryKind.expense,
      );
      final plan = ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [account, category],
        groups: [
          ImportTransactionGroupDraft(
            topLevel: ImportExpenseDraft(
              amount: Money.parse('12'),
              paidFrom: const ImportAccountReference.source(
                sourceEntityKey: 'account:cash',
                displayName: '现金',
              ),
              category: const ImportCategoryReference(
                sourceEntityKey: 'category:expense:临时食品 / 临时午餐',
                path: '临时食品 / 临时午餐',
                kind: ImportCategoryKind.expense,
              ),
              occurredAt: DateTime(2026, 4, 6),
            ),
            sourceOperationFingerprint: 'category-path-fingerprint',
            fingerprintVersion: 1,
          ),
        ],
      );

      final review = await fixture.service.review(plan);
      final result = await fixture.service.commit(
        ImportCommitCommand(
          plan: plan,
          mappings: review.effectiveMappings,
          plannedCreations: review.plannedCreations,
          selectedGroupIndexes: const {0},
        ),
      );

      expect(result.createdBatch, isTrue);
      final rows =
          await fixture.database.select(fixture.database.accounts).get();
      final parent = rows.singleWhere((row) => row.name == '临时食品');
      final leaf = rows.singleWhere((row) => row.name == '临时午餐');
      expect(leaf.parentId, parent.id);
      expect(leaf.accountType, AccountType.expense);
    },
  );

  test(
    'creates unmatched mapping targets only when the import is committed',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      const accountEntity = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:new-wallet',
        displayName: '新钱包',
      );
      const categoryEntity = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.category,
        sourceEntityKey: 'category:expense:new-food',
        displayName: '新餐饮',
        categoryKind: ImportCategoryKind.expense,
      );
      final plan = ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [accountEntity, categoryEntity],
        groups: [
          ImportTransactionGroupDraft(
            topLevel: ImportExpenseDraft(
              amount: Money.parse('25.00'),
              paidFrom: const ImportAccountReference.source(
                sourceEntityKey: 'account:new-wallet',
                displayName: '新钱包',
              ),
              category: const ImportCategoryReference(
                sourceEntityKey: 'category:expense:new-food',
                path: '新餐饮',
                kind: ImportCategoryKind.expense,
              ),
              occurredAt: DateTime(2026, 4, 6),
            ),
            sourceOperationFingerprint: 'new-targets-fingerprint',
            fingerprintVersion: 1,
          ),
        ],
      );
      const accountKey = ImportMappingKey(
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.account,
        sourceEntityKey: 'account:new-wallet',
      );
      const categoryKey = ImportMappingKey(
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.category,
        sourceEntityKey: 'category:expense:new-food',
      );
      final creations = {
        accountKey: const ImportMappingCreation(
          name: '新钱包',
          kind: ImportMappingTargetKind.asset,
        ),
        categoryKey: const ImportMappingCreation(
          name: '新餐饮',
          kind: ImportMappingTargetKind.expenseCategory,
        ),
      };

      final review = await fixture.service.review(
        plan,
        plannedCreations: creations,
      );

      expect(review.groups.single.canSelect, isTrue);
      expect(
        (await fixture.database.select(fixture.database.accounts).get()).where(
          (row) => row.name == '新钱包' || row.name == '新餐饮',
        ),
        isEmpty,
      );

      final result = await fixture.service.commit(
        ImportCommitCommand(
          plan: plan,
          mappings: review.effectiveMappings,
          plannedCreations: creations,
          selectedGroupIndexes: const {0},
          saveMappingConfiguration: true,
        ),
      );

      expect(result.batch?.importedGroupCount, 1);
      expect(result.createdMappings.keys, containsAll(creations.keys));
      final createdTargets =
          (await fixture.database.select(fixture.database.accounts).get())
              .where((row) => row.name == '新钱包' || row.name == '新餐饮')
              .toList();
      expect(createdTargets, hasLength(2));
      final refreshed = await fixture.service.review(plan);
      expect(refreshed.defaultMappings.keys, containsAll(creations.keys));
      expect(refreshed.groups.single.canSelect, isTrue);
    },
  );

  test(
    'creates only the mapping kind used by selected transaction groups',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      const sharedSourceKey = 'shared-source-key';
      const accountKey = ImportMappingKey(
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.account,
        sourceEntityKey: sharedSourceKey,
      );
      const categoryKey = ImportMappingKey(
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.category,
        sourceEntityKey: sharedSourceKey,
      );
      final plan = ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [
          ImportSourceEntity(
            source: ImportSource.yimu,
            kind: ImportEntityKind.account,
            sourceEntityKey: sharedSourceKey,
            displayName: '新结算账户',
          ),
          ImportSourceEntity(
            source: ImportSource.yimu,
            kind: ImportEntityKind.category,
            sourceEntityKey: sharedSourceKey,
            displayName: '未使用分类',
            categoryKind: ImportCategoryKind.expense,
          ),
        ],
        groups: [
          ImportTransactionGroupDraft(
            topLevel: ImportInterestExpenseDraft(
              amount: Money.parse('2.00'),
              paidFrom: const ImportAccountReference.source(
                sourceEntityKey: sharedSourceKey,
                displayName: '新结算账户',
              ),
              occurredAt: DateTime(2026, 4, 6),
            ),
            sourceOperationFingerprint: 'shared-source-key-fingerprint',
            fingerprintVersion: 1,
          ),
        ],
      );
      final creations = {
        accountKey: const ImportMappingCreation(
          name: '新结算账户',
          kind: ImportMappingTargetKind.asset,
        ),
        categoryKey: const ImportMappingCreation(
          name: '未使用分类',
          kind: ImportMappingTargetKind.expenseCategory,
        ),
      };
      final review = await fixture.service.review(
        plan,
        plannedCreations: creations,
      );

      final result = await fixture.service.commit(
        ImportCommitCommand(
          plan: plan,
          mappings: review.effectiveMappings,
          plannedCreations: creations,
          selectedGroupIndexes: const {0},
        ),
      );

      expect(result.createdMappings, contains(accountKey));
      expect(result.createdMappings, isNot(contains(categoryKey)));
      final accounts =
          await fixture.database.select(fixture.database.accounts).get();
      expect(accounts.where((row) => row.name == '新结算账户'), hasLength(1));
      expect(accounts.where((row) => row.name == '未使用分类'), isEmpty);
    },
  );

  test('maps a missing settlement account to the ghost account', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);
    const missingKey = 'review:missing:account:bill:2:account';
    const category = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.category,
      sourceEntityKey: 'category:expense:餐饮 / 生鲜',
      displayName: '餐饮 / 生鲜',
      categoryKind: ImportCategoryKind.expense,
    );
    const missing = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.account,
      sourceEntityKey: missingKey,
      displayName: '缺失账户（账单文件第 2 行）',
      isReviewPlaceholder: true,
    );
    final plan = ImportParseResult(
      source: ImportSource.yimu,
      sourceEntities: const [missing, category],
      groups: [
        ImportTransactionGroupDraft(
          topLevel: ImportExpenseDraft(
            amount: Money.parse('12.00'),
            paidFrom: const ImportAccountReference.unresolved(
              sourceEntityKey: missingKey,
              displayName: '缺失账户（账单文件第 2 行）',
            ),
            category: const ImportCategoryReference(
              sourceEntityKey: 'category:expense:餐饮 / 生鲜',
              path: '餐饮 / 生鲜',
              kind: ImportCategoryKind.expense,
            ),
            occurredAt: DateTime(2026, 4, 6),
          ),
          sourceOperationFingerprint: 'missing-settlement-fingerprint',
          fingerprintVersion: 1,
          issues: const [
            ImportIssue(
              code: 'account_missing',
              message: '账户为空或未提供。',
              severity: ImportIssueSeverity.blocking,
            ),
          ],
        ),
      ],
    );
    await fixture.seedMapping(entity: category, targetAccountId: 'food');

    final review = await fixture.service.review(plan);

    const key = ImportMappingKey(
      source: ImportSource.yimu,
      entityKind: ImportEntityKind.account,
      sourceEntityKey: missingKey,
    );
    final target = review.targets.singleWhere(
      (candidate) => candidate.id == review.effectiveMappings[key],
    );
    expect(target.kind, ImportMappingTargetKind.ghost);
    expect(review.groups.single.canSelect, isTrue);
    expect(review.defaultMappings, isNot(contains(key)));
  });

  test(
    'rejects a regular source account mapped to the ghost account',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      const account = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:regular',
        displayName: '普通账户',
      );
      const category = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.category,
        sourceEntityKey: 'category:expense:餐饮 / 生鲜',
        displayName: '餐饮 / 生鲜',
        categoryKind: ImportCategoryKind.expense,
      );
      final plan = ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [account, category],
        groups: [
          ImportTransactionGroupDraft(
            topLevel: ImportExpenseDraft(
              amount: Money.parse('12.00'),
              paidFrom: const ImportAccountReference.source(
                sourceEntityKey: 'account:regular',
                displayName: '普通账户',
              ),
              category: const ImportCategoryReference(
                sourceEntityKey: 'category:expense:餐饮 / 生鲜',
                path: '餐饮 / 生鲜',
                kind: ImportCategoryKind.expense,
              ),
              occurredAt: DateTime(2026, 4, 6),
            ),
            sourceOperationFingerprint: 'regular-ghost-fingerprint',
            fingerprintVersion: 1,
          ),
        ],
      );
      final ghost = (await fixture.database
              .select(fixture.database.accounts)
              .get())
          .singleWhere((row) => row.systemKey == SystemKey.ghostAccount);
      final mappings = {
        ImportMappingKey.fromEntity(account): ghost.id,
        ImportMappingKey.fromEntity(category): 'food',
      };

      await expectLater(
        fixture.service.commit(
          ImportCommitCommand(
            plan: plan,
            mappings: mappings,
            selectedGroupIndexes: const {0},
          ),
        ),
        throwsA(
          isA<ImportWorkflowException>().having(
            (error) => error.code,
            'code',
            ImportErrorCode.mappingTargetRoleInvalid.code,
          ),
        ),
      );
      expect(
        await fixture.database.select(fixture.database.transactions).get(),
        isEmpty,
      );
    },
  );

  test('keeps a non-settlement missing account blocked', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.database.close);
    const missingKey = 'review:missing:account:debt:2:liability';
    const missing = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.account,
      sourceEntityKey: missingKey,
      displayName: '缺失债务账户（债务文件第 2 行）',
      isReviewPlaceholder: true,
    );
    final plan = ImportParseResult(
      source: ImportSource.yimu,
      sourceEntities: const [missing],
      groups: [
        ImportTransactionGroupDraft(
          topLevel: ImportOpeningBalanceDraft(
            amount: Money.parse('100.00'),
            liabilityAccount: const ImportAccountReference.unresolved(
              sourceEntityKey: missingKey,
              displayName: '缺失债务账户（债务文件第 2 行）',
            ),
            occurredAt: DateTime(2026, 4, 6),
          ),
          sourceOperationFingerprint: 'missing-liability-fingerprint',
          fingerprintVersion: 1,
          issues: const [
            ImportIssue(
              code: 'account_missing',
              message: '债务账户为空或未提供。',
              severity: ImportIssueSeverity.blocking,
            ),
          ],
        ),
      ],
    );

    final review = await fixture.service.review(plan);
    final key = ImportMappingKey.fromEntity(missing);

    expect(review.effectiveMappings, isNot(contains(key)));
    expect(review.plannedCreations, isNot(contains(key)));
    expect(review.groups.single.isBlocked, isTrue);
    expect(review.groups.single.canSelect, isFalse);
  });

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
      profileKey: 'credit.loan',
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
    expect(
      review.effectiveMappings[const ImportMappingKey(
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.account,
        sourceEntityKey: receiveKey,
      )],
      'asset-match',
    );
    expect(
      review.effectiveMappings[const ImportMappingKey(
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.account,
        sourceEntityKey: liabilityKey,
      )],
      'debt-match',
    );
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
    'review ignores an archived default and uses a unique compatible match',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      const entity = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:cash',
        displayName: '现金',
      );
      await fixture.seedMapping(entity: entity, targetAccountId: 'cash');
      final cash = await fixture.accounts.findById('cash');
      cash!.archive(DateTime(2026, 4, 7));
      await fixture.accounts.save(cash);
      await _insertAccount(
        fixture.database,
        'replacement-cash',
        '现金',
        AccountType.asset,
      );
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
      expect(review.groups.single.isBlocked, isFalse);
      expect(
        review.effectiveMappings[ImportMappingKey.fromEntity(entity)],
        'replacement-cash',
      );
      expect(
        review.plannedCreations,
        isNot(contains(ImportMappingKey.fromEntity(entity))),
      );
    },
  );

  test(
    'blocks a source entity whose target descriptor constraints conflict',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.database.close);
      const entity = ImportSourceEntity(
        source: ImportSource.yimu,
        kind: ImportEntityKind.account,
        sourceEntityKey: 'account:conflicted',
        displayName: '冲突账户',
        hasTargetDescriptorConflict: true,
      );
      final plan = ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [entity],
        groups: [
          ImportTransactionGroupDraft(
            topLevel: ImportTransferDraft(
              amount: Money.parse('10'),
              fromAccount: const ImportAccountReference.source(
                sourceEntityKey: 'account:conflicted',
                displayName: '冲突账户',
              ),
              toAccount: const ImportAccountReference.source(
                sourceEntityKey: 'account:conflicted',
                displayName: '冲突账户',
              ),
              occurredAt: DateTime(2026, 4, 6),
            ),
            sourceOperationFingerprint: 'conflicted-descriptor-fingerprint',
            fingerprintVersion: 1,
          ),
        ],
      );

      final review = await fixture.service.review(plan);

      expect(review.groups.single.isBlocked, isTrue);
      expect(review.mappingItems.single.action, ImportMappingAction.unresolved);
      expect(
        review.mappingItems.single.issues.map((issue) => issue.code),
        contains('source_entity_target_descriptor_conflict'),
      );
      expect(review.mappingItems.single.creationOptions, isEmpty);
      expect(review.mappingItems.single.existingTargetOptions, isEmpty);
    },
  );
}

class _Fixture {
  _Fixture._({
    required this.database,
    required this.accounts,
    required this.mappings,
    required this.service,
  });

  final AppDatabase database;
  final DriftAccountRepository accounts;
  final DriftImportMappingRepository mappings;
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
      accountQuery: accountQuery,
      metricsSource: DriftLedgerMetricsSource(database),
    );
    final ledgerPosting = LedgerPostingService(
      accountRepository: accounts,
      systemAccountResolver: systemAccounts,
      postingEngine: PostingEngine(idGenerator: ids),
      accountPostingService: const DefaultAccountPostingService(),
      accountRolePolicy: AccountRolePolicy(accountRepository: accounts),
    );
    final accountCommands = AccountAppServiceImpl(
      accounts,
      transactionRunner: runner,
      ledgerPostingService: ledgerPosting,
      transactionRepository: postings,
      idGenerator: ids,
    );
    final categoryCommands = CategoryAppServiceImpl(
      repository: accounts,
      transactionRepository: postings,
      transactionRunner: runner,
      idGenerator: ids,
    );
    final ledger = LedgerImportPort(
      posting: posting,
      editing: editing,
      transactions: transactionQuery,
      accounts: accountQuery,
      accountCommands: accountCommands,
      categoryCommands: categoryCommands,
      systemAccounts: systemAccounts,
      creditAccounts: CreditAccountAppServiceImpl(
        ledger: LedgerCreditAccountPort(accountCommands),
        creditAccounts: DriftCreditAccountRepository(database),
        transactionRunner: runner,
        idGenerator: ids,
      ),
    );
    final mappings = DriftImportMappingRepository(database);
    return _Fixture._(
      database: database,
      accounts: accounts,
      mappings: mappings,
      service: ImportWorkflowAppServiceImpl(
        mappings: mappings,
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
      await seedMapping(entity: entity, targetAccountId: targetId);
    }
  }

  Future<void> seedMapping({
    required ImportSourceEntity entity,
    required String targetAccountId,
  }) async {
    final now = DateTime(2026, 4, 6);
    await mappings.upsert(
      ImportEntityMapping(
        id: 'seed:${entity.kind.name}:${entity.sourceEntityKey}',
        source: entity.source,
        entityKind: entity.kind,
        sourceEntityKey: entity.sourceEntityKey,
        targetAccountId: targetAccountId,
        createdAt: now,
        updatedAt: now,
      ),
    );
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
  AccountType type, {
  String? profileKey,
}) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          name: name,
          accountType: type,
          accountProfileKey: Value(profileKey),
        ),
      );
}
