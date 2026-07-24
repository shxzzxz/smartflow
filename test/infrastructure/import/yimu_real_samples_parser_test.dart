import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/import/import_workflow_app_service.dart';
import 'package:smartflow/application/import/import_workflow_models.dart';
import 'package:smartflow/application/ledger/account/command/account_app_service.dart';
import 'package:smartflow/application/ledger/account/query/account_query_service.dart';
import 'package:smartflow/application/ledger/category/command/category_app_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_edit_app_service.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_ledger_writer.dart';
import 'package:smartflow/application/ledger/transaction/command/transaction_posting_app_service.dart';
import 'package:smartflow/application/ledger/transaction/query/transaction_query_service.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/import_persistence_models.dart';
import 'package:smartflow/domain/import/service/yimu_import_parser.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/ledger_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/import/ledger_import_port.dart';
import 'package:smartflow/infrastructure/import/repository/drift_import_batch_repository.dart';
import 'package:smartflow/infrastructure/import/repository/drift_import_mapping_repository.dart';
import 'package:smartflow/infrastructure/import/yimu_excel2003_workbook_reader.dart';
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
  final sampleDirectory = _sampleDirectoryOrNull();
  test(
    'parses the real Yimu bundle through decode and domain seams',
    () {
      final directory = sampleDirectory!;
      final bundle = ImportBundle(
        files: [
          for (final name in [
            '账单_0406193148.xls',
            '转账_0406193209.xls',
            '债务_0406193307.xls',
          ])
            ImportFilePayload(
              name: name,
              bytes: Uint8List.fromList(
                File(
                  '${directory.path}${Platform.pathSeparator}$name',
                ).readAsBytesSync(),
              ),
            ),
        ],
      );
      final parser = YimuImportParser(
        reader: const YimuExcel2003WorkbookReader(),
      );

      final result = parser.parse(bundle);

      expect(result.fatalIssues, isEmpty);
      expect(result.groups, isNotEmpty);
      expect(result.sourceAccounts, isNotEmpty);
      expect(result.sourceCategories, isNotEmpty);
      expect(result.filteredRecords, isNotEmpty);
      expect(
        result.groups.any(
          (group) => group.topLevel is ImportReimbursementAdvanceDraft,
        ),
        isTrue,
      );
      expect(
        result.groups.any(
          (group) => group.topLevel is ImportInterestExpenseDraft,
        ),
        isTrue,
      );
      expect(
        result.groups.any(
          (group) => group.topLevel is ImportOpeningBalanceDraft,
        ),
        isTrue,
      );
    },
    skip:
        sampleDirectory == null
            ? 'Local anonymized Yimu samples are not available.'
            : false,
  );

  test(
    'imports the real Yimu bundle through mapping, commit, and ledger posting',
    () async {
      final directory = sampleDirectory!;
      final plan = YimuImportParser(
        reader: const YimuExcel2003WorkbookReader(),
      ).parse(_realBundle(directory));
      final fixture = await _GoldenFixture.create();
      addTearDown(fixture.database.close);
      final prepared = await fixture.prepareMappings(plan);

      final review = await fixture.service.review(
        plan,
        groupMappingOverrides: prepared.groupOverrides,
      );
      final selected = {
        for (final group in review.groups)
          if (group.canSelect) group.index,
      };
      expect(selected, isNotEmpty);
      final result = await fixture.service.commit(
        ImportCommitCommand(
          plan: plan,
          mappings: review.effectiveMappings,
          groupMappingOverrides: review.groupMappingOverrides,
          selectedGroupIndexes: selected,
          confirmedWarningIndexes: selected,
        ),
      );

      expect(result.batch, isNotNull);
      expect(result.batch!.importedGroupCount, selected.length);
      final expectedTransactions = selected.fold<int>(
        0,
        (count, index) => count + plan.groups[index].transactions.length,
      );
      expect(result.batch!.createdTransactionCount, expectedTransactions);
      final transactions =
          await fixture.database.select(fixture.database.transactions).get();
      final details =
          await fixture.database
              .select(fixture.database.transactionDetails)
              .get();
      final accounts =
          await fixture.database.select(fixture.database.accounts).get();
      expect(transactions, hasLength(expectedTransactions));
      expect(
        transactions.every((row) => row.sourceKind == SourceKind.import),
        isTrue,
      );
      final refund = transactions.singleWhere(
        (row) =>
            row.businessPurpose == BusinessPurpose.refund &&
            row.primaryAmountMinor == 158,
      );
      expect(refund.parentTransactionId, isNotNull);
      expect(
        details
            .where(
              (row) =>
                  row.detailType ==
                  TransactionDetailType.reimbursementGapExpense,
            )
            .map((row) => row.amountMinor),
        contains(1500),
      );
      expect(
        details
            .where(
              (row) =>
                  row.detailType ==
                  TransactionDetailType.reimbursementGapIncome,
            )
            .map((row) => row.amountMinor),
        contains(101),
      );
      final repayment = transactions.singleWhere(
        (row) =>
            row.businessPurpose == BusinessPurpose.debtRepayment &&
            row.primaryAmountMinor == 84225,
      );
      final repaymentDetails = {
        for (final row in details.where(
          (detail) => detail.transactionId == repayment.id,
        ))
          row.detailType: row.amountMinor,
      };
      expect(
        repaymentDetails,
        containsPair(TransactionDetailType.repaymentPrincipal, 81465),
      );
      expect(
        repaymentDetails,
        containsPair(TransactionDetailType.repaymentInterest, 2760),
      );
      expect(
        accounts
            .singleWhere((row) => row.systemKey == SystemKey.openingBalance)
            .balanceMinor,
        -6300000,
      );
      expect(
        accounts
            .singleWhere((row) => row.systemKey == SystemKey.ghostAccount)
            .balanceMinor,
        2954216,
      );
      expect(
        accounts
            .singleWhere(
              (row) =>
                  row.name == '利息' && row.accountType == AccountType.expense,
            )
            .balanceMinor,
        18927,
      );
      expect(
        await fixture.service.findBatchItems(result.batch!.id),
        hasLength(selected.length),
      );
    },
    skip:
        sampleDirectory == null
            ? 'Local anonymized Yimu samples are not available.'
            : false,
  );
}

ImportBundle _realBundle(Directory directory) {
  return ImportBundle(
    files: [
      for (final name in [
        '账单_0406193148.xls',
        '转账_0406193209.xls',
        '债务_0406193307.xls',
      ])
        ImportFilePayload(
          name: name,
          bytes: Uint8List.fromList(
            File(
              '${directory.path}${Platform.pathSeparator}$name',
            ).readAsBytesSync(),
          ),
        ),
    ],
  );
}

Directory? _sampleDirectoryOrNull() {
  final local = Directory('demo/data/一木记账');
  if (local.existsSync()) return local;
  final worktreeSibling = Directory(
    '${Directory.current.parent.parent.path}${Platform.pathSeparator}'
    'demo${Platform.pathSeparator}data${Platform.pathSeparator}一木记账',
  );
  if (worktreeSibling.existsSync()) return worktreeSibling;
  return null;
}

enum _TargetRole { asset, liability, reimbursement, income, expense }

class _PreparedMappings {
  const _PreparedMappings({required this.groupOverrides});

  final Map<int, Map<ImportMappingKey, String>> groupOverrides;
}

class _GoldenFixture {
  const _GoldenFixture({required this.database, required this.service});

  final AppDatabase database;
  final ImportWorkflowAppServiceImpl service;

  static Future<_GoldenFixture> create() async {
    final database = createTestDatabase();
    final ids = SequentialIdGenerator(prefix: 'golden');
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
    final ledgerPosting = LedgerPostingService(
      accountRepository: accounts,
      systemAccountResolver: systemAccounts,
      postingEngine: PostingEngine(idGenerator: ids),
      accountPostingService: const DefaultAccountPostingService(),
      accountRolePolicy: AccountRolePolicy(accountRepository: accounts),
    );
    final ledger = LedgerImportPort(
      posting: posting,
      editing: editing,
      transactions: TransactionQueryServiceImpl(
        transactionRead: DriftTransactionReadRepository(database),
        entryRead: DriftEntryReadRepository(database),
        detailRead: DriftTransactionDetailReadRepository(database),
        metricsSource: DriftLedgerMetricsSource(database),
      ),
      accounts: AccountQueryServiceImpl(
        accounts: DriftAccountQueryRepository(database),
      ),
      accountCommands: AccountAppServiceImpl(
        accounts,
        transactionRunner: runner,
        ledgerPostingService: ledgerPosting,
        transactionRepository: postings,
        idGenerator: ids,
      ),
      categoryCommands: CategoryAppServiceImpl(
        repository: accounts,
        idGenerator: ids,
      ),
      systemAccounts: systemAccounts,
    );
    return _GoldenFixture(
      database: database,
      service: ImportWorkflowAppServiceImpl(
        mappings: DriftImportMappingRepository(database),
        batches: DriftImportBatchRepository(database),
        ledger: ledger,
        transactionRunner: runner,
        idGenerator: ids,
        now: () => DateTime(2026, 7, 22),
      ),
    );
  }

  Future<_PreparedMappings> prepareMappings(ImportParseResult plan) async {
    final roles = _sourceRoles(plan);
    final targets = <(String, _TargetRole), String>{};
    final mappings = DriftImportMappingRepository(database);
    var index = 0;
    for (final entity in plan.sourceEntities) {
      final entityRoles =
          roles[entity.sourceEntityKey] ?? const <_TargetRole>{};
      for (final role in entityRoles) {
        final id = 'source-target-${index++}';
        targets[(entity.sourceEntityKey, role)] = id;
        await _insertTarget(database, id, entity.displayName, role);
      }
      if (entityRoles.isNotEmpty && !entity.isReviewPlaceholder) {
        final defaultRole = entityRoles.first;
        await mappings.upsert(
          ImportEntityMapping(
            id: 'golden-mapping:${entity.kind.name}:${entity.sourceEntityKey}',
            source: entity.source,
            entityKind: entity.kind,
            sourceEntityKey: entity.sourceEntityKey,
            targetAccountId: targets[(entity.sourceEntityKey, defaultRole)]!,
            createdAt: DateTime(2026, 7, 22),
            updatedAt: DateTime(2026, 7, 22),
          ),
        );
      }
    }

    return _PreparedMappings(
      groupOverrides: {
        for (var groupIndex = 0; groupIndex < plan.groups.length; groupIndex++)
          groupIndex: _groupOverrides(plan.groups[groupIndex], targets),
      },
    );
  }
}

Map<String, Set<_TargetRole>> _sourceRoles(ImportParseResult plan) {
  final result = <String, Set<_TargetRole>>{};
  void add(String? key, _TargetRole role) {
    if (key == null) return;
    result.putIfAbsent(key, () => <_TargetRole>{}).add(role);
  }

  for (final entity in plan.sourceEntities) {
    if (entity.kind == ImportEntityKind.category) {
      add(
        entity.sourceEntityKey,
        entity.categoryKind == ImportCategoryKind.income
            ? _TargetRole.income
            : _TargetRole.expense,
      );
    }
  }
  for (final group in plan.groups) {
    for (final draft in group.transactions) {
      _visitDraftRoles(draft, add);
    }
  }
  return result;
}

Map<ImportMappingKey, String> _groupOverrides(
  ImportTransactionGroupDraft group,
  Map<(String, _TargetRole), String> targets,
) {
  final result = <ImportMappingKey, String>{};
  void add(String? key, _TargetRole role, ImportEntityKind kind) {
    if (key == null) return;
    final target = targets[(key, role)];
    if (target == null) return;
    result[ImportMappingKey(
          source: ImportSource.yimu,
          entityKind: kind,
          sourceEntityKey: key,
        )] =
        target;
  }

  for (final draft in group.transactions) {
    _visitDraftRoles(
      draft,
      (key, role) => add(
        key,
        role,
        role == _TargetRole.income || role == _TargetRole.expense
            ? ImportEntityKind.category
            : ImportEntityKind.account,
      ),
    );
  }
  return result;
}

void _visitDraftRoles(
  ImportTransactionDraft draft,
  void Function(String? key, _TargetRole role) add,
) {
  switch (draft) {
    case ImportExpenseDraft draft:
      add(draft.paidFrom.sourceEntityKey, _TargetRole.asset);
      add(draft.category.sourceEntityKey, _TargetRole.expense);
    case ImportIncomeDraft draft:
      add(draft.receiveAccount.sourceEntityKey, _TargetRole.asset);
      add(draft.category.sourceEntityKey, _TargetRole.income);
    case ImportRefundDraft draft:
      add(draft.refundTo.sourceEntityKey, _TargetRole.asset);
    case ImportReimbursementAdvanceDraft draft:
      add(draft.receivableAccount.sourceEntityKey, _TargetRole.reimbursement);
      add(draft.paidFrom.sourceEntityKey, _TargetRole.asset);
      add(draft.category.sourceEntityKey, _TargetRole.expense);
    case ImportReimbursementReceiptDraft draft:
      add(draft.receivableAccount.sourceEntityKey, _TargetRole.reimbursement);
      add(draft.receiveAccount.sourceEntityKey, _TargetRole.asset);
    case ImportReimbursementCloseDraft draft:
      add(draft.receivableAccount.sourceEntityKey, _TargetRole.reimbursement);
      if (draft.actualReceivedAmount.minorUnits > 0) {
        add(draft.receiveAccount.sourceEntityKey, _TargetRole.asset);
      }
    case ImportTransferDraft draft:
      add(draft.fromAccount.sourceEntityKey, _TargetRole.asset);
      add(draft.toAccount.sourceEntityKey, _TargetRole.asset);
    case ImportRepaymentDraft draft:
      add(draft.liabilityAccount.sourceEntityKey, _TargetRole.liability);
      add(draft.paidFrom.sourceEntityKey, _TargetRole.asset);
    case ImportInterestExpenseDraft draft:
      add(draft.paidFrom.sourceEntityKey, _TargetRole.asset);
    case ImportBorrowingDraft draft:
      add(draft.liabilityAccount.sourceEntityKey, _TargetRole.liability);
      add(draft.receiveAccount.sourceEntityKey, _TargetRole.asset);
    case ImportOpeningBalanceDraft draft:
      add(draft.liabilityAccount.sourceEntityKey, _TargetRole.liability);
  }
}

Future<void> _insertTarget(
  AppDatabase database,
  String id,
  String name,
  _TargetRole role,
) {
  final (type, subtype) = switch (role) {
    _TargetRole.asset => (AccountType.asset, null),
    _TargetRole.liability => (AccountType.liability, null),
    _TargetRole.reimbursement => (
      AccountType.asset,
      AccountSubtype.reimbursement,
    ),
    _TargetRole.income => (AccountType.income, null),
    _TargetRole.expense => (AccountType.expense, null),
  };
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          name: name,
          accountType: type,
          accountSubtype: Value(subtype),
        ),
      );
}
