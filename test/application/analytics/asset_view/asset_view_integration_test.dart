import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/analytics/analytics_command_api.dart';
import 'package:smartflow/application/analytics/analytics_query_api.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/analytics/port/asset_view_repository.dart';
import 'package:smartflow/domain/analytics/valobj/analytics_error_code.dart';
import 'package:smartflow/infrastructure/analytics/adapter/financial_asset_view_accounts.dart';
import 'package:smartflow/infrastructure/analytics/adapter/ledger_asset_view_references.dart';
import 'package:smartflow/infrastructure/analytics/repository/drift_asset_view_repository.dart';
import 'package:smartflow/infrastructure/data_management/backup/drift_backup_gateway.dart';
import 'package:smartflow/infrastructure/data_management/backup/file_backup_package_store.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/database_provider.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late DriftAssetViewRepository views;
  late AssetViewAppService service;
  late AssetViewQueryService query;
  late AccountAppService ledger;
  late Account cash;
  late Account other;
  late Account debt;
  late Account archived;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    views = DriftAssetViewRepository(db);
    service = container.read(assetViewAppServiceProvider);
    query = container.read(assetViewQueryServiceProvider);
    ledger = container.read(accountAppServiceProvider);
    Future<Account> create(
      String name,
      AccountProfileKind profile,
      int balance,
    ) => ledger.createAccount(
      CreateAccountCommand(
        transactionBookId: Book.dailyId,
        name: name,
        type: profile.accountType,
        subtype: profile.accountSubtype,
        profileKey: profile.key,
        openingBalance: Money(minorUnits: balance),
      ),
    );
    cash = await create('指定资金', AccountProfileKind.fund, 10000);
    other = await create('其他资金', AccountProfileKind.fund, 90000);
    debt = await create('指定应付', AccountProfileKind.payable, 5000);
    archived = await create('归档资金', AccountProfileKind.fund, 30000);
    await ledger.archiveAccount(ArchiveAccountCommand(id: archived.id));
    final builtin = (await views.findView(AssetView.defaultId))!;
    await service.saveView(
      SaveAssetViewCommand(
        id: builtin.id,
        expectedVersion: builtin.version,
        name: builtin.name,
        accountIds: [cash.id, other.id, debt.id, archived.id],
      ),
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<AssetView> createView(String name, Iterable<String> ids) =>
      service.saveView(SaveAssetViewCommand(name: name, accountIds: ids));
  String fundGroup(AssetView view) =>
      view.groups.firstWhere((group) => group.name == '资金').id;

  test(
    'new views group selected accounts by profile and persist independent organization',
    () async {
      final first = await createView('日常', [cash.id, other.id, debt.id]);
      final second = await createView('储蓄', [cash.id, other.id, debt.id]);
      final before = (await container
          .read(accountQueryServiceProvider)
          .findAccountById(cash.id))!;
      await service.moveAccountToGroup(first.id, other.id, fundGroup(first), [
        other.id,
        cash.id,
      ]);
      await service.createGroup(first.id, '备用');
      var current = (await views.findView(first.id))!;
      final spare = current.groups.firstWhere((group) => group.name == '备用').id;
      await service.moveAccountToGroup(first.id, cash.id, spare, [cash.id]);
      current = (await views.findView(first.id))!;
      await service.reorderGroups(
        first.id,
        current.groups.reversed.map((group) => group.id).toList(),
      );
      await service.renameGroup(first.id, spare, '储备');
      final changed = (await DriftAssetViewRepository(db).findView(first.id))!;
      final untouched = (await views.findView(second.id))!;
      expect(changed.groupIdFor(cash.id), spare);
      expect(changed.groups.first.name, '储备');
      expect(untouched.accountsInGroup(fundGroup(untouched)), [
        cash.id,
        other.id,
      ]);
      expect(
        untouched.groups.map((group) => group.id),
        second.groups.map((group) => group.id),
      );
      expect(
        untouched.groupIdFor(debt.id),
        untouched.groups.firstWhere((group) => group.name == '应付账户').id,
      );
      final after = (await container
          .read(accountQueryServiceProvider)
          .findAccountById(cash.id))!;
      expect(after.version, before.version);
      expect(after.balance, before.balance);
    },
  );

  test(
    'sorting active accounts preserves archived positions and ledger facts',
    () async {
      final view = await createView('归档排序', [cash.id, archived.id, other.id]);
      final before = (await container
          .read(accountQueryServiceProvider)
          .findAccountById(archived.id))!;
      await service.moveAccountToGroup(view.id, other.id, fundGroup(view), [
        other.id,
        archived.id,
        cash.id,
      ]);
      final saved = (await views.findView(view.id))!;
      expect(saved.accountsInGroup(fundGroup(saved)), [
        other.id,
        archived.id,
        cash.id,
      ]);
      final after = (await container
          .read(accountQueryServiceProvider)
          .findAccountById(archived.id))!;
      expect(after.version, before.version);
      expect(after.archivedAt, before.archivedAt);
      await ledger.restoreAccount(RestoreAccountCommand(id: archived.id));
      expect((await views.findView(view.id))!.accountIds, saved.accountIds);
    },
  );

  test(
    'scope edits retain existing organization and append newly included accounts',
    () async {
      final view = await createView('范围编辑', [cash.id, debt.id]);
      await service.deleteGroup(view.id, fundGroup(view));
      final current = (await views.findView(view.id))!;
      final saved = await service.saveView(
        SaveAssetViewCommand(
          id: current.id,
          expectedVersion: current.version,
          name: current.name,
          accountIds: [other.id, debt.id],
        ),
      );
      expect(saved.accountIds, [debt.id, other.id]);
      expect(saved.accountGroupIds.containsKey(cash.id), isFalse);
      expect(saved.groupIdFor(other.id), isNull);
      expect(saved.groupIdFor(debt.id), current.groupIdFor(debt.id));
      expect(saved.groups.any((group) => group.name == '资金'), isFalse);
    },
  );

  test(
    'deleting a group affects only that view and preserves archived scope entries',
    () async {
      final first = await createView('日常', [cash.id, archived.id]);
      final second = await createView('副视图', [cash.id, archived.id]);
      await service.deleteGroup(first.id, fundGroup(first));
      final changed = (await views.findView(first.id))!;
      final untouched = (await views.findView(second.id))!;
      expect(changed.accountsInGroup(null), [cash.id, archived.id]);
      expect(untouched.accountsInGroup(fundGroup(untouched)), [
        cash.id,
        archived.id,
      ]);
      expect(
        (await query.watchStatistics(changed, DateTime(2099)).first)
            .assets
            .minorUnits,
        10000,
      );
      await ledger.restoreAccount(RestoreAccountCommand(id: archived.id));
      expect(
        (await query.watchStatistics(changed, DateTime(2099)).first)
            .assets
            .minorUnits,
        40000,
      );
      expect((await views.findView(second.id))!.accountIds, [
        cash.id,
        archived.id,
      ]);
    },
  );

  test(
    'invalid references names and stale ordering leave saved views unchanged',
    () async {
      final view = await createView('日常', [cash.id]);
      final equity =
          (await container.read(accountQueryServiceProvider).findAccountsById())
              .values
              .firstWhere(
                (account) => account.systemKey == SystemKey.openingBalance,
              );
      for (final ids in [
        [equity.id],
        ['missing-account'],
      ]) {
        await expectLater(
          createView('非法范围', ids),
          throwsA(isA<BusinessException>()),
        );
      }
      await expectLater(
        createView('日常', [other.id]),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        service.reorderGroups(view.id, [fundGroup(view)]),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        service.moveAccountToGroup(view.id, archived.id, fundGroup(view), [
          cash.id,
          archived.id,
        ]),
        throwsA(isA<BusinessException>()),
      );
      expect((await views.findView(view.id))!.version, view.version);
      expect((await views.findViews()).length, 2);
    },
  );

  test(
    'existing deleted references survive edits while newly introduced missing references fail',
    () async {
      final view = await createView('保留范围', [cash.id]);
      await (db.delete(
        db.entries,
      )..where((row) => row.accountId.equals(cash.id))).go();
      await (db.delete(
        db.accounts,
      )..where((row) => row.id.equals(cash.id))).go();
      final edited = await service.saveView(
        SaveAssetViewCommand(
          id: view.id,
          expectedVersion: view.version,
          name: '保留范围改名',
          accountIds: view.accountIds,
        ),
      );
      expect(edited.accountIds, [cash.id]);
      expect(edited.groupIdFor(cash.id), view.groupIdFor(cash.id));
      await expectLater(
        createView('新非法范围', [cash.id]),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test('a group edit invalidates an already open view editor', () async {
    final view = await createView('日常', [cash.id]);
    await service.renameGroup(view.id, fundGroup(view), '现金');
    await expectLater(
      service.saveView(
        SaveAssetViewCommand(
          id: view.id,
          expectedVersion: view.version,
          name: '过时编辑',
          accountIds: [other.id],
        ),
      ),
      throwsA(
        isA<BusinessException>().having(
          (error) => error.code,
          'code',
          AnalyticsErrorCode.concurrentUpdate.code,
        ),
      ),
    );
    final current = (await views.findView(view.id))!;
    expect(current.name, '日常');
    expect(current.accountIds, [cash.id]);
  });

  test(
    'copying and ordering views preserve independent scopes groups and account order',
    () async {
      final original = await createView('日常', [cash.id, other.id, archived.id]);
      await service.renameGroup(original.id, fundGroup(original), '现金');
      final source = (await views.findView(original.id))!;
      final copy = await service.saveView(
        SaveAssetViewCommand(
          name: '副本',
          accountIds: source.accountIds,
          copyFrom: source,
        ),
      );
      await service.reorderViews([AssetView.defaultId, copy.id, original.id]);
      final ordered = await views.findViews();
      expect(ordered.map((view) => view.id), [
        AssetView.defaultId,
        copy.id,
        original.id,
      ]);
      expect(ordered[1].accountIds, source.accountIds);
      expect(ordered[1].accountGroupIds, source.accountGroupIds);
      await service.renameGroup(copy.id, source.groups.first.id, '副本资金');
      expect((await views.findView(original.id))!.groups.first.name, '现金');
    },
  );

  test(
    'default scope is editable can be empty and default name and deletion are protected',
    () async {
      final builtin = (await views.findView(AssetView.defaultId))!;
      final edited = await service.saveView(
        SaveAssetViewCommand(
          id: builtin.id,
          expectedVersion: builtin.version,
          name: builtin.name,
          accountIds: [],
        ),
      );
      final statistics = await query
          .watchStatistics(edited, DateTime(2099))
          .first;
      expect(statistics.assets.minorUnits, 0);
      expect(statistics.liabilities.minorUnits, 0);
      await expectLater(
        service.deleteView(builtin.id),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        service.saveView(
          SaveAssetViewCommand(
            id: edited.id,
            expectedVersion: edited.version,
            name: '重命名',
            accountIds: [],
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      final removable = await createView('可删除', [cash.id]);
      await service.deleteView(removable.id);
      expect(await views.findView(removable.id), isNull);
    },
  );

  test(
    'failure after inserting a view rolls back its complete configuration',
    () async {
      final failing = AssetViewAppServiceImpl(
        views: _FailingViews(views, failCreate: true),
        references: LedgerAssetViewReferences(
          accounts: container.read(accountQueryServiceProvider),
        ),
        transactionRunner: DriftTransactionRunner(db),
        ids: _Ids(),
      );
      await expectLater(
        failing.saveView(
          SaveAssetViewCommand(name: '失败视图', accountIds: [cash.id]),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await views.findView('failed-view'), isNull);
      expect((await views.findViews()).length, 1);
    },
  );

  test(
    'new account joins only the selected view using that view custom group',
    () async {
      final selected = await createView('日常', [cash.id]);
      final otherView = await createView('储蓄', [cash.id]);
      await service.createGroup(selected.id, '日常现金');
      final selectedNow = (await views.findView(selected.id))!;
      final groupId = selectedNow.groups.last.id;
      final id = await container
          .read(assetViewAccountAppServiceProvider)
          .createAccount(
            CreateAssetViewAccountCommand(
              viewId: selected.id,
              groupId: groupId,
              account: _draft('新银行卡', AccountProfileKind.fund),
            ),
          );
      final saved = (await views.findView(selected.id))!;
      expect(saved.accountsInGroup(groupId), [id]);
      expect(
        (await views.findView(otherView.id))!.includesAccount(id),
        isFalse,
      );
      expect(
        (await views.findView(AssetView.defaultId))!.includesAccount(id),
        isFalse,
      );
      expect(
        (await container.read(accountQueryServiceProvider).findAccountById(id))!
            .balance
            .minorUnits,
        5000,
      );
    },
  );

  for (final profile in [AccountProfileKind.fund, AccountProfileKind.credit]) {
    test(
      'account and view writes roll back together after a view save fails for ${profile.name}',
      () async {
        final view = await createView('日常', [cash.id]);
        final before = await DriftBackupGateway(db).readSnapshot();
        final failing = AssetViewAccountAppServiceImpl(
          views: _FailingViews(views),
          accounts: FinancialAssetViewAccounts(
            ledger: ledger,
            credit: container.read(creditAccountAppServiceProvider),
          ),
          transactionRunner: DriftTransactionRunner(db),
        );
        await expectLater(
          failing.createAccount(
            CreateAssetViewAccountCommand(
              viewId: view.id,
              groupId: fundGroup(view),
              account: _draft('失败账户', profile),
            ),
          ),
          throwsA(isA<StateError>()),
        );
        final after = await DriftBackupGateway(db).readSnapshot();
        for (final table in [
          'accounts',
          'transactions',
          'entries',
          'credit_liability_accounts',
          'bills',
          'bill_items',
        ]) {
          expect(
            after.rows(table).length,
            before.rows(table).length,
            reason: table,
          );
        }
        expect(
          after.rows('accounts').any((row) => row['name'] == '失败账户'),
          isFalse,
        );
        expect((await views.findView(view.id))!.accountIds, view.accountIds);
        expect((await views.findView(view.id))!.version, view.version);
      },
    );
  }

  test(
    'editing shared account facts changes grouping only in the supplied view',
    () async {
      final first = await createView('日常', [cash.id]);
      final second = await createView('储蓄', [cash.id]);
      await service.createGroup(first.id, '自定义');
      final current = (await views.findView(first.id))!;
      final target = current.groups.last.id;
      await container
          .read(assetViewAccountAppServiceProvider)
          .editAccount(
            EditAssetViewAccountCommand(
              viewId: first.id,
              groupId: Patch.set(target),
              account: AssetViewAccountEdit(
                transactionBookId: Book.dailyId,
                accountId: cash.id,
                profile: AccountProfileKind.fund,
                name: '共用名称',
                iconKey: const Patch.clear(),
                note: const Patch.clear(),
              ),
            ),
          );
      expect((await views.findView(first.id))!.groupIdFor(cash.id), target);
      expect(
        (await views.findView(second.id))!.groupIdFor(cash.id),
        fundGroup(second),
      );
      expect(
        (await container
                .read(accountQueryServiceProvider)
                .findAccountById(cash.id))!
            .name,
        '共用名称',
      );
    },
  );

  test(
    'scoped current and previous balances include only selected entry accounts',
    () async {
      await db.delete(db.entries).go();
      await db.delete(db.transactions).go();
      await db
          .update(db.accounts)
          .write(const AccountsCompanion(balanceMinor: Value(0)));
      final equity =
          (await container.read(accountQueryServiceProvider).findAccountsById())
              .values
              .firstWhere(
                (account) => account.systemKey == SystemKey.openingBalance,
              )
              .id;
      await _post(
        db,
        'cash-opening',
        DateTime(2025, 12, 31),
        cash.id,
        equity,
        8000,
      );
      await _post(
        db,
        'other-opening',
        DateTime(2025, 12, 31),
        other.id,
        equity,
        100000,
      );
      await _post(
        db,
        'debt-opening',
        DateTime(2025, 12, 31),
        equity,
        debt.id,
        4000,
      );
      await _post(
        db,
        'transfer',
        DateTime(2026, 1, 2),
        cash.id,
        other.id,
        2000,
      );
      await _post(
        db,
        'debt-change',
        DateTime(2026, 1, 6),
        equity,
        debt.id,
        1000,
      );
      final view = await createView('局部资产', [cash.id, debt.id]);
      final statistics = await query
          .watchStatistics(view, DateTime(2026, 1, 10))
          .first;
      expect(statistics.assets.minorUnits, 10000);
      expect(statistics.liabilities.minorUnits, 5000);
      expect(statistics.netAssets.minorUnits, 5000);
      expect(statistics.netAssetChange.minorUnits, 1000);
      await ledger.archiveAccount(ArchiveAccountCommand(id: cash.id));
      final withoutArchived = await query
          .watchStatistics(view, DateTime(2026, 1, 12))
          .first;
      expect(withoutArchived.assets.minorUnits, 0);
      expect(withoutArchived.liabilities.minorUnits, 5000);
      expect((await views.findView(view.id))!.accountIds, [cash.id, debt.id]);
    },
  );

  test(
    'complete backup restore preserves view scopes groups and account order',
    () async {
      final view = await createView('组合视图', [cash.id, other.id, debt.id]);
      await service.moveAccountToGroup(view.id, other.id, fundGroup(view), [
        other.id,
        cash.id,
      ]);
      await service.renameGroup(view.id, fundGroup(view), '现金');
      final saved = (await views.findView(view.id))!;
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-view-backup-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final backup = BackupService(
        gateway: DriftBackupGateway(db),
        packageStore: const FileBackupPackageStore(),
      );
      await backup.createBackup(directory);
      await service.deleteView(saved.id);
      await backup.restore(directory);
      final restored = (await views.findView(saved.id))!;
      expect(restored.accountIds, saved.accountIds);
      expect(restored.accountGroupIds, saved.accountGroupIds);
      expect(
        restored.groups.map((group) => group.name),
        saved.groups.map((group) => group.name),
      );
    },
  );

  for (final version in [18, 19]) {
    test(
      'legacy v$version backup moves global organization into explicit view configurations',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'smartflow-legacy-views-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final backup = BackupService(
          gateway: DriftBackupGateway(db),
          packageStore: const FileBackupPackageStore(),
        );
        await backup.createBackup(directory);
        final snapshot = await DriftBackupGateway(db).readSnapshot();
        await _writeTable(directory, 'account_groups', [
          {
            'id': 'old-fund',
            'name': '旧资金',
            'sortOrder': 20,
            'version': 0,
            'createdAt': 0,
            'updatedAt': 0,
          },
          {
            'id': 'old-debt',
            'name': '旧负债',
            'sortOrder': 10,
            'version': 0,
            'createdAt': 0,
            'updatedAt': 0,
          },
        ]);
        await _writeTable(directory, 'accounts', [
          for (final row in snapshot.rows('accounts'))
            {
              ...row,
              'groupId':
                  row['id'] == cash.id ||
                      row['id'] == other.id ||
                      row['id'] == archived.id
                  ? 'old-fund'
                  : row['id'] == debt.id
                  ? 'old-debt'
                  : null,
              'sortOrder': row['id'] == cash.id
                  ? 1
                  : row['id'] == other.id
                  ? 0
                  : row['id'] == archived.id
                  ? 2
                  : row['sortOrder'],
            },
        ]);
        if (version == 19) {
          await _writeTable(directory, 'asset_views', [
            {
              'id': AssetView.defaultId,
              'name': '所有账户',
              'accountIdsJson': '[]',
              'blocksJson': '[]',
              'sortOrder': 0,
              'version': 0,
              'createdAt': 0,
              'updatedAt': 0,
            },
            {
              'id': 'legacy-view',
              'name': '默认',
              'accountIdsJson': jsonEncode([
                cash.id,
                other.id,
                archived.id,
                'gone',
              ]),
              'blocksJson': jsonEncode([
                {
                  'id': 'old-block',
                  'name': '资金入口',
                  'groupIds': ['old-fund'],
                },
              ]),
              'sortOrder': 1,
              'version': 0,
              'createdAt': 0,
              'updatedAt': 0,
            },
          ]);
        }
        final manifestFile = File('${directory.path}/manifest.json');
        final manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, dynamic>;
        manifest['backupSchemaVersion'] = version;
        if (version == 18) {
          (manifest['requiredFiles'] as List).removeWhere(
            (file) => file['table'] == 'asset_views',
          );
          await File('${directory.path}/analytics/asset_views.ndjson').delete();
        }
        await manifestFile.writeAsString(jsonEncode(manifest));
        final inspected = await backup.inspect(directory);
        expect(
          inspected.snapshot.tables.containsKey('account_groups'),
          isFalse,
        );
        expect(
          inspected.snapshot
              .rows('accounts')
              .any((row) => row.containsKey('groupId')),
          isFalse,
        );
        await backup.restore(directory);
        final builtin = (await views.findView(AssetView.defaultId))!;
        expect(builtin.name, '默认');
        expect(
          builtin.accountIds,
          containsAll([cash.id, other.id, debt.id, archived.id]),
        );
        expect(builtin.groups.map((group) => group.name), ['旧负债', '旧资金']);
        expect(builtin.accountsInGroup('old-fund'), [
          other.id,
          cash.id,
          archived.id,
        ]);
        if (version == 19) {
          final custom = (await views.findView('legacy-view'))!;
          expect(custom.name, '默认 (2)');
          expect(custom.accountIds, [other.id, cash.id, archived.id, 'gone']);
        }
      },
    );
  }

  test(
    'backup rejects group assignments outside a view before restoring data',
    () async {
      final snapshot = await DriftBackupGateway(db).readSnapshot();
      final invalid = snapshot.copyWith(
        tables: {
          ...snapshot.tables,
          'asset_views': [
            ...snapshot.rows('asset_views'),
            {
              'id': 'bad-view',
              'name': '错误分组',
              'accountIdsJson': jsonEncode([cash.id]),
              'groupsJson': '[{"id":"fund","name":"资金"}]',
              'accountGroupIdsJson': jsonEncode({other.id: 'fund'}),
              'sortOrder': 1,
              'version': 0,
              'createdAt': 0,
              'updatedAt': 0,
            },
          ],
        },
      );
      expect(
        () => BackupService.validateSnapshot(invalid),
        throwsA(isA<BackupValidationException>()),
      );
      expect((await views.findViews()).length, 1);
    },
  );
}

AssetViewAccountDraft _draft(String name, AccountProfileKind profile) =>
    AssetViewAccountDraft(
      transactionBookId: Book.dailyId,
      profile: profile,
      name: name,
      openingBalance: const Money(minorUnits: 5000),
      billingDay: 1,
      repaymentDay: 20,
    );

class _Ids implements IdGenerator {
  @override
  String newId() => 'failed-view';
}

class _FailingViews implements AssetViewRepository {
  _FailingViews(this.delegate, {this.failCreate = false});
  final AssetViewRepository delegate;
  final bool failCreate;
  @override
  Future<void> create(AssetView view) async {
    await delegate.create(view);
    if (failCreate) throw StateError('after view insertion');
  }

  @override
  Future<void> save(AssetView view) async {
    await delegate.save(view);
    if (!failCreate) throw StateError('after view update');
  }

  @override
  Future<AssetView?> findView(String id) => delegate.findView(id);
  @override
  Future<List<AssetView>> findViews() => delegate.findViews();
  @override
  Future<void> delete(String id) => delegate.delete(id);
}

Future<void> _post(
  AppDatabase db,
  String id,
  DateTime date,
  String debit,
  String credit,
  int amount,
) async {
  await db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: id,
          bookId: const Value(Book.dailyId),
          businessPurpose: BusinessPurpose.openingBalance,
          occurredAt: date,
          postedAt: date,
          primaryAmountMinor: amount,
          sourceKind: SourceKind.manual,
        ),
      );
  for (final entry in [
    (id: '$id-debit', account: debit, direction: EntryDirection.debit),
    (id: '$id-credit', account: credit, direction: EntryDirection.credit),
  ]) {
    await db
        .into(db.entries)
        .insert(
          EntriesCompanion.insert(
            id: entry.id,
            transactionId: id,
            accountId: entry.account,
            direction: entry.direction,
            amountMinor: amount,
          ),
        );
  }
}

Future<void> _writeTable(
  Directory directory,
  String table,
  List<Map<String, Object?>> rows,
) async {
  final path = '${BackupTables.sectionFor(table)}/$table.ndjson';
  final file = File('${directory.path}/$path');
  await file.parent.create(recursive: true);
  final bytes = utf8.encode(rows.map(jsonEncode).map((row) => '$row\n').join());
  await file.writeAsBytes(bytes);
  final manifestFile = File('${directory.path}/manifest.json');
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  final files = manifest['requiredFiles'] as List;
  files.removeWhere((file) => file['table'] == table);
  files.add({
    'path': path,
    'table': table,
    'rowCount': rows.length,
    'byteCount': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  });
  await manifestFile.writeAsString(jsonEncode(manifest));
}
