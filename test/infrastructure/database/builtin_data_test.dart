import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/builtin_data.dart';
import 'package:smartflow/shared/account_group/initial_account_groups.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_product_repository.dart';
import 'package:smartflow/domain/credit/entity/installment_product.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';

import '../../helper/test_app_database.dart';

void main() {
  test('seeds default prepaid and deferred income accounts', () async {
    final database = createTestDatabase();
    addTearDown(database.close);

    final prepaid =
        await (database.select(database.accounts)..where(
              (row) => row.accountProfileKey.equals(
                AccountProfileKind.prepaidExpense.key,
              ),
            ))
            .getSingle();
    final deferred =
        await (database.select(database.accounts)..where(
              (row) => row.accountProfileKey.equals(
                AccountProfileKind.deferredIncome.key,
              ),
            ))
            .getSingle();

    expect(prepaid.name, '通用预付');
    expect(prepaid.accountType, AccountType.asset);
    expect(prepaid.accountSubtype, AccountSubtype.prepaidExpense);
    expect(
      prepaid.groupId,
      initialAccountGroupIdForProfile(AccountProfileKind.prepaidExpense),
    );
    expect(prepaid.source, AccountSource.builtin);

    expect(deferred.name, '通用预收');
    expect(deferred.accountType, AccountType.liability);
    expect(deferred.accountSubtype, AccountSubtype.deferredIncome);
    expect(
      deferred.groupId,
      initialAccountGroupIdForProfile(AccountProfileKind.deferredIncome),
    );
    expect(deferred.source, AccountSource.builtin);
  });

  test(
    'v13 upgrade adds missing default accounts without overwriting groups',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final profileKeys = [
        AccountProfileKind.prepaidExpense.key,
        AccountProfileKind.deferredIncome.key,
      ];
      const prepaidGroupId = 'builtin-account-group-prepaid-expense';
      const deferredGroupId = 'builtin-account-group-deferred-income';

      await (database.delete(
        database.accounts,
      )..where((row) => row.accountProfileKey.isIn(profileKeys))).go();
      await (database.delete(
        database.accountGroups,
      )..where((row) => row.id.equals(deferredGroupId))).go();
      await (database.update(database.accountGroups)
            ..where((row) => row.id.equals(prepaidGroupId)))
          .write(const AccountGroupsCompanion(name: Value('我的预付')));
      await (database.update(database.appMetadata)
            ..where((row) => row.key.equals(builtinDataVersionKey)))
          .write(const AppMetadataCompanion(value: Value('13')));

      await ensureBuiltinData(database);

      final groups = await (database.select(
        database.accountGroups,
      )..where((row) => row.id.isIn([prepaidGroupId, deferredGroupId]))).get();
      expect(
        {for (final group in groups) group.id: group.name},
        {prepaidGroupId: '我的预付', deferredGroupId: '预收'},
      );

      final accounts =
          await (database.select(database.accounts)
                ..where((row) => row.accountProfileKey.isIn(profileKeys))
                ..orderBy([(row) => OrderingTerm.asc(row.name)]))
              .get();
      expect(accounts.map((account) => account.name), ['通用预付', '通用预收']);
      expect(accounts.map((account) => account.groupId), [
        prepaidGroupId,
        deferredGroupId,
      ]);
    },
  );

  test(
    'v13 upgrade groups existing deferral accounts without duplicating them',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      const prepaidGroupId = 'builtin-account-group-prepaid-expense';
      const deferredGroupId = 'builtin-account-group-deferred-income';

      await (database.delete(database.accounts)..where(
            (row) =>
                row.accountProfileKey.equals(
                  AccountProfileKind.prepaidExpense.key,
                ) |
                row.accountProfileKey.equals(
                  AccountProfileKind.deferredIncome.key,
                ),
          ))
          .go();
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'existing-prepaid',
              name: '我的预付',
              accountType: AccountType.asset,
              accountSubtype: const Value(AccountSubtype.prepaidExpense),
              accountProfileKey: Value(AccountProfileKind.prepaidExpense.key),
            ),
          );
      await (database.delete(
        database.accountGroups,
      )..where((row) => row.id.isIn([prepaidGroupId, deferredGroupId]))).go();
      await (database.update(database.appMetadata)
            ..where((row) => row.key.equals(builtinDataVersionKey)))
          .write(const AppMetadataCompanion(value: Value('13')));

      await ensureBuiltinData(database);

      final prepaidAccounts =
          await (database.select(database.accounts)..where(
                (row) => row.accountProfileKey.equals(
                  AccountProfileKind.prepaidExpense.key,
                ),
              ))
              .get();
      expect(prepaidAccounts, hasLength(1));
      expect(prepaidAccounts.single.id, 'existing-prepaid');
      expect(prepaidAccounts.single.groupId, prepaidGroupId);

      final deferred =
          await (database.select(database.accounts)..where(
                (row) => row.accountProfileKey.equals(
                  AccountProfileKind.deferredIncome.key,
                ),
              ))
              .getSingle();
      expect(deferred.name, '通用预收');
      expect(deferred.groupId, deferredGroupId);
    },
  );

  test(
    'v11 template upgrade retires old combination and preserves existing edits',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentProductRepository(database);
      final base = (await repository.find('builtin-loan-equal-installment'))!;
      await repository.save(
        InstallmentProduct(
          id: 'builtin-loan-interest-then-installment',
          name: '先息后本转等额本息',
          stages: const [
            InstallmentStageRule.repayment(
              id: 'retired-template-stage',
              method: InstallmentRepaymentMethod.interestFirst,
              intervalMonths: 1,
              ratePeriod: InterestRatePeriod.annual,
              accrual: InterestAccrualMethod.monthly,
            ),
          ],
          createdAt: DateTime(2026),
        ),
      );
      await (database.update(database.installmentProducts)
            ..where((p) => p.id.equals(base.id)))
          .write(const InstallmentProductsCompanion(name: Value('我的模板')));
      await repository.delete('builtin-loan-equal-principal');
      await repository.delete('builtin-loan-interest-first');
      await (database.update(database.appMetadata)
            ..where((row) => row.key.equals(builtinDataVersionKey)))
          .write(const AppMetadataCompanion(value: Value('11')));
      await ensureBuiltinData(database);
      expect((await repository.find(base.id))!.name, '我的模板');
      expect(
        (await repository.find(
          'builtin-loan-interest-then-installment',
        ))!.archived,
        isTrue,
      );
      expect(
        (await repository.find('builtin-loan-equal-principal'))!.name,
        '等额本金',
      );
      expect(
        (await repository.find('builtin-loan-interest-first'))!.name,
        '先息后本',
      );
    },
  );
  test(
    'seeds ordinary loan products once without per-loan parameters',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentProductRepository(database);
      final products = await repository.list();
      expect(
        products.map((p) => p.name),
        unorderedEquals(['等额本息', '等额本金', '一次性手续费', '先息后本', '国家助学贷款']),
      );
      for (final product in products) {
        product.validate();
      }
      final stages = await database
          .select(database.installmentProductStageConfigs)
          .get();
      expect(stages, hasLength(7));
      expect(
        stages.map((stage) => stage.productId).toSet(),
        products.map((product) => product.id).toSet(),
      );
      expect(
        await database.select(database.installmentStageConfigs).get(),
        isEmpty,
      );
      await repository.delete(products.first.id);
      await ensureBuiltinData(database);
      expect(await repository.find(products.first.id), isNull);
      expect(await repository.list(), hasLength(4));
    },
  );
  test('builtin data assigns receivable and payable profile groups', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'receivable',
            name: 'Receivable',
            accountType: AccountType.asset,
            accountSubtype: const Value(AccountSubtype.receivable),
            accountProfileKey: const Value('ledger.receivable'),
          ),
        );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'payable',
            name: 'Payable',
            accountType: AccountType.liability,
            accountSubtype: const Value(AccountSubtype.payable),
            accountProfileKey: const Value('ledger.payable'),
          ),
        );
    await (database.update(database.appMetadata)
          ..where((row) => row.key.equals(builtinDataVersionKey)))
        .write(const AppMetadataCompanion(value: Value('9')));

    await ensureBuiltinData(database);
    await ensureBuiltinData(database);

    final receivable = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('receivable'))).getSingle();
    final payable = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('payable'))).getSingle();
    expect(
      receivable.groupId,
      initialAccountGroupIdForProfile(AccountProfileKind.receivable),
    );
    expect(
      payable.groupId,
      initialAccountGroupIdForProfile(AccountProfileKind.payable),
    );
  });

  test('v12 renames advance compensation classification', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await database.customStatement(
      "UPDATE accounts SET name = '垫付补偿收入' "
      "WHERE system_key = 'advanceCompensationIncome'",
    );
    await (database.update(database.appMetadata)
          ..where((row) => row.key.equals(builtinDataVersionKey)))
        .write(const AppMetadataCompanion(value: Value('12')));

    await ensureBuiltinData(database);

    final name = await database
        .customSelect(
          "SELECT name FROM accounts "
          "WHERE system_key = 'advanceCompensationIncome'",
        )
        .getSingle();
    expect(name.read<String>('name'), '垫付补偿');
  });

  test('v14 upgrade repairs built-in category icon mappings', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    const mappings = [
      (
        name: '早餐',
        type: AccountType.expense,
        oldIcon: 'cup-line',
        icon: 'breakfast',
      ),
      (
        name: '食材生鲜',
        type: AccountType.expense,
        oldIcon: 'cabbage',
        icon: 'fresh-food',
      ),
      (
        name: '日用品',
        type: AccountType.expense,
        oldIcon: 'shopping',
        icon: 'daily-supplies',
      ),
      (
        name: '水电燃',
        type: AccountType.expense,
        oldIcon: 'flashlight-line',
        icon: 'electricity-bill',
      ),
      (
        name: '通讯',
        type: AccountType.expense,
        oldIcon: 'phone',
        icon: 'sim-card',
      ),
      (
        name: '文化教育',
        type: AccountType.expense,
        oldIcon: 'book',
        icon: 'education',
      ),
      (
        name: '休闲娱乐',
        type: AccountType.expense,
        oldIcon: 'gamepad-line',
        icon: 'leisure',
      ),
      (
        name: '工作',
        type: AccountType.income,
        oldIcon: 'briefcase-line',
        icon: 'briefcase',
      ),
      (
        name: '工资',
        type: AccountType.income,
        oldIcon: 'wallet-3-line',
        icon: 'salary',
      ),
      (
        name: '借出',
        type: AccountType.expense,
        oldIcon: 'logout-box-r-line',
        icon: 'lend-out',
      ),
      (
        name: '借入',
        type: AccountType.income,
        oldIcon: 'hand-coin-line',
        icon: 'borrow-in',
      ),
    ];

    for (final mapping in mappings) {
      await (database.update(database.accounts)..where(
            (row) =>
                row.name.equals(mapping.name) &
                row.accountType.equalsValue(mapping.type) &
                row.source.equalsValue(AccountSource.builtin),
          ))
          .write(AccountsCompanion(iconKey: Value(mapping.oldIcon)));
    }
    await (database.update(database.appMetadata)
          ..where((row) => row.key.equals(builtinDataVersionKey)))
        .write(const AppMetadataCompanion(value: Value('14')));

    await ensureBuiltinData(database);

    for (final mapping in mappings) {
      final account =
          await (database.select(database.accounts)..where(
                (row) =>
                    row.name.equals(mapping.name) &
                    row.accountType.equalsValue(mapping.type),
              ))
              .getSingle();
      expect(
        account.iconKey,
        'builtin:category:rounded-line:${mapping.icon}',
        reason: '${mapping.name} should use ${mapping.icon}',
      );
    }
    final version = await (database.select(
      database.appMetadata,
    )..where((row) => row.key.equals(builtinDataVersionKey))).getSingle();
    expect(version.value, currentBuiltinDataVersion.toString());
  });

  test(
    'v15 upgrade normalizes icon refs and removes icon style settings',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await database.batch((batch) {
        batch.insertAllOnConflictUpdate(database.appMetadata, [
          AppMetadataCompanion.insert(
            key: 'settings.account_icon_style',
            value: 'soft-duotone',
          ),
          AppMetadataCompanion.insert(
            key: 'settings.category_icon_style',
            value: 'color-shape',
          ),
        ]);
        batch.insertAll(database.accounts, [
          AccountsCompanion.insert(
            id: 'icon-generic',
            name: '资金',
            accountType: AccountType.asset,
            iconKey: const Value('bank-card'),
          ),
          AccountsCompanion.insert(
            id: 'icon-brand',
            name: '支付宝',
            accountType: AccountType.asset,
            iconKey: const Value('alipay'),
          ),
          AccountsCompanion.insert(
            id: 'icon-category',
            name: '餐饮',
            accountType: AccountType.expense,
            iconKey: const Value('meal'),
          ),
          AccountsCompanion.insert(
            id: 'icon-exact',
            name: '自定义',
            accountType: AccountType.asset,
            iconKey: const Value('user:account:mine:custom'),
          ),
        ]);
      });
      await (database.update(database.appMetadata)
            ..where((row) => row.key.equals(builtinDataVersionKey)))
          .write(const AppMetadataCompanion(value: Value('15')));

      await ensureBuiltinData(database);

      expect(
        await _accountIcon(database, 'icon-generic'),
        'builtin:account:soft-duotone:bank-card',
      );
      expect(
        await _accountIcon(database, 'icon-brand'),
        'builtin:account:brand:alipay',
      );
      expect(
        await _accountIcon(database, 'icon-category'),
        'builtin:category:color-shape:meal',
      );
      expect(
        await _accountIcon(database, 'icon-exact'),
        'user:account:mine:custom',
      );
      expect(
        await (database.select(database.appMetadata)..where(
              (row) => row.key.isIn([
                'settings.account_icon_style',
                'settings.category_icon_style',
              ]),
            ))
            .get(),
        isEmpty,
      );
    },
  );
}

Future<String?> _accountIcon(AppDatabase database, String id) async {
  final row = await (database.select(
    database.accounts,
  )..where((account) => account.id.equals(id))).getSingle();
  return row.iconKey;
}
