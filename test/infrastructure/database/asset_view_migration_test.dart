import 'dart:convert';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/analytics/entity/asset_view.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v68.dart' as v68;
import '../../generated_migrations/schema_v69.dart' as v69;

void main() {
  test('v68 to v69 preserves the immutable intermediate view schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(68);
    final old = v68.DatabaseAtV68(schema.newConnection());
    await old.customStatement(
      "INSERT INTO app_metadata (key, value) VALUES ('builtin_data_version', '999')",
    );
    await old.customStatement(
      "INSERT INTO accounts (id, name, account_type, balance_minor) VALUES ('cash', '原有账户', 'asset', 12345)",
    );
    await old.close();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 69);
    expect(
      (await db
              .customSelect(
                "SELECT balance_minor FROM accounts WHERE id = 'cash'",
              )
              .getSingle())
          .read<int>('balance_minor'),
      12345,
    );
    final view = await db.customSelect('SELECT * FROM asset_views').getSingle();
    expect(view.read<String>('id'), 'builtin-asset-view-all');
    expect(view.read<String>('name'), '所有账户');
    expect(view.read<String>('account_ids_json'), '[]');
    expect(view.read<String>('blocks_json'), '[]');
  });

  test(
    'v69 to v70 migrates global groups and order into each view without foreign keys',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      await verifier.testWithDataIntegrity<v69.DatabaseAtV69, AppDatabase>(
        createOld: v69.DatabaseAtV69.new,
        createNew: AppDatabase.new,
        openTestedDatabase: AppDatabase.new,
        oldVersion: 69,
        newVersion: 70,
        createItems: (batch, db) {
          batch.customStatement(
            "INSERT INTO app_metadata (key, value) VALUES ('builtin_data_version', '999')",
          );
          batch.customStatement(
            "INSERT INTO account_groups (id, name, sort_order) VALUES ('fund', '资金', 10), ('debt', '借贷', 0)",
          );
          batch.customStatement(
            "INSERT INTO accounts (id, name, account_type, account_subtype, account_profile_key, group_id, "
            "sort_order, balance_minor, archived_at) VALUES "
            "('a', '资金甲', 'asset', 'fund', 'ledger.fund', 'fund', 1, 111, NULL), "
            "('b', '资金乙', 'asset', 'fund', 'ledger.fund', 'fund', 0, 222, NULL), "
            "('archived', '归档', 'asset', 'fund', 'ledger.fund', 'fund', 2, 333, 100), "
            "('liability', '负债', 'liability', 'payable', 'ledger.payable', 'debt', 0, 444, NULL), "
            "('ungrouped', '未分组', 'asset', 'fund', 'ledger.fund', NULL, 5, 555, NULL), "
            "('category', '分类', 'expense', NULL, NULL, NULL, 77, 0, NULL)",
          );
          batch.customStatement(
            "INSERT INTO asset_views (id, name, account_ids_json, blocks_json, sort_order, version) VALUES "
            "('builtin-asset-view-all', '所有账户', '[]', '[]', 0, 0), "
            "('custom', '默认', '[\"a\",\"b\",\"archived\",\"gone\"]', "
            "'[{\"id\":\"block\",\"name\":\"资金入口\",\"groupIds\":[\"fund\"]}]', 1, 4)",
          );
        },
        validateItems: (db) async {
          final rows = await db.select(db.assetViews).get();
          final builtin = rows.firstWhere(
            (row) => row.id == AssetView.defaultId,
          );
          final custom = rows.firstWhere((row) => row.id == 'custom');
          expect(builtin.name, '默认');
          expect(
            jsonDecode(builtin.accountIdsJson),
            containsAll(['a', 'b', 'archived', 'liability', 'ungrouped']),
          );
          expect(
            jsonDecode(builtin.accountIdsJson),
            isNot(contains('category')),
          );
          expect(custom.name, '默认 (2)');
          expect(custom.version, 4);
          expect(jsonDecode(custom.accountIdsJson), [
            'b',
            'a',
            'archived',
            'gone',
          ]);
          expect(jsonDecode(custom.groupsJson), [
            {'id': 'debt', 'name': '借贷'},
            {'id': 'fund', 'name': '资金'},
          ]);
          expect(jsonDecode(custom.accountGroupIdsJson), {
            'a': 'fund',
            'b': 'fund',
            'archived': 'fund',
          });
          final accounts = await db.select(db.accounts).get();
          expect(accounts.firstWhere((row) => row.id == 'a').balanceMinor, 111);
          expect(
            accounts.firstWhere((row) => row.id == 'archived').archivedAt,
            isNotNull,
          );
          expect(
            accounts.firstWhere((row) => row.id == 'category').sortOrder,
            77,
          );
          expect(
            accounts
                .where((row) => row.id != 'category')
                .map((row) => row.sortOrder),
            everyElement(0),
          );
          final tables = await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table'",
              )
              .get();
          expect(
            tables.map((row) => row.read<String>('name')),
            isNot(contains('account_groups')),
          );
          final accountColumns = await db
              .customSelect('PRAGMA table_info(accounts)')
              .get();
          expect(
            accountColumns.map((row) => row.read<String>('name')),
            isNot(contains('group_id')),
          );
          final viewColumns = await db
              .customSelect('PRAGMA table_info(asset_views)')
              .get();
          expect(
            viewColumns.map((row) => row.read<String>('name')),
            isNot(contains('blocks_json')),
          );
          for (final table in ['accounts', 'asset_views']) {
            expect(
              await db.customSelect('PRAGMA foreign_key_list($table)').get(),
              isEmpty,
            );
          }
        },
      );
    },
  );

  test(
    'invalid legacy scope rolls back the migration and keeps schema v69',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(69);
      final old = v69.DatabaseAtV69(schema.newConnection());
      await old.customStatement(
        "INSERT INTO app_metadata (key, value) VALUES ('builtin_data_version', '999')",
      );
      await old.customStatement(
        "INSERT INTO account_groups (id, name) VALUES ('fund', '原有分组')",
      );
      await old.customStatement(
        "INSERT INTO asset_views (id, name, account_ids_json) VALUES "
        "('builtin-asset-view-all', '所有账户', '[]'), ('invalid', '错误视图', '{')",
      );
      await old.close();
      final failed = AppDatabase(schema.newConnection());
      await expectLater(
        failed.customSelect('SELECT 1').get(),
        throwsA(isA<FormatException>()),
      );
      await failed.close();
      final unchanged = v69.DatabaseAtV69(schema.newConnection());
      addTearDown(unchanged.close);
      expect(
        (await unchanged.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        69,
      );
      expect(
        (await unchanged
                .customSelect('SELECT * FROM account_groups')
                .getSingle())
            .read<String>('name'),
        '原有分组',
      );
      final columns = await unchanged
          .customSelect('PRAGMA table_info(asset_views)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        contains('blocks_json'),
      );
      expect(
        columns.map((row) => row.read<String>('name')),
        isNot(contains('groups_json')),
      );
    },
  );

  test('supported v60 baseline reaches the latest view schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final db = AppDatabase(await verifier.startAt(60));
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 70);
    expect(
      (await db.select(db.assetViews).get()).single.id,
      AssetView.defaultId,
    );
    expect(
      (await db.select(db.assetViews).get()).single.name,
      AssetView.defaultName,
    );
  });
}
