import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/data/builtin_data.dart';
import 'package:smartflow/domain/accounting/accounting_api.dart';

import '../helpers/test_app_database.dart';

void main() {
  group('builtin data', () {
    test('is created with a fresh database', () async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final expenseRows =
          await (database.select(database.accounts)..where(
            (account) => account.accountType.equalsValue(AccountType.expense),
          )).get();
      final incomeRows =
          await (database.select(database.accounts)..where(
            (account) => account.accountType.equalsValue(AccountType.income),
          )).get();
      final metadataRow =
          await (database.select(database.appMetadata)..where(
            (metadata) => metadata.key.equals(builtinDataVersionKey),
          )).getSingle();

      expect(expenseRows.where((row) => row.name == '食品餐饮'), hasLength(1));
      expect(expenseRows.where((row) => row.name == '茶饮'), hasLength(1));
      expect(
        expenseRows.singleWhere((row) => row.name == '请客吃饭').iconKey,
        'service-bell-line',
      );
      expect(
        expenseRows.singleWhere((row) => row.name == '茶饮').iconKey,
        'drinks-line',
      );
      expect(
        expenseRows.singleWhere((row) => row.name == '食材生鲜').iconKey,
        'cabbage',
      );
      expect(
        expenseRows.singleWhere((row) => row.name == '粮油调味').iconKey,
        'rice',
      );
      expect(
        expenseRows.singleWhere((row) => row.name == '手续费').iconKey,
        'swap-box-line',
      );
      expect(
        expenseRows.singleWhere((row) => row.name == '借出').iconKey,
        'logout-box-r-line',
      );
      expect(incomeRows.where((row) => row.name == '工作'), hasLength(1));
      expect(incomeRows.where((row) => row.name == '工资'), hasLength(1));
      expect(
        incomeRows.singleWhere((row) => row.name == '工作').iconKey,
        'briefcase-line',
      );
      expect(
        incomeRows.singleWhere((row) => row.name == '工资').iconKey,
        'wallet-3-line',
      );
      expect(
        incomeRows.singleWhere((row) => row.name == '奖金').iconKey,
        'trophy-line',
      );
      expect(
        incomeRows.singleWhere((row) => row.name == '兼职').iconKey,
        'rest-time-line',
      );
      expect(
        incomeRows.singleWhere((row) => row.name == '投资收益').iconKey,
        'funds-line',
      );
      expect(
        incomeRows
            .singleWhere(
              (row) =>
                  row.name == '其他' && row.accountType == AccountType.income,
            )
            .iconKey,
        'more-2-line',
      );
      expect(
        incomeRows.singleWhere((row) => row.name == '借入').iconKey,
        'hand-coin-line',
      );
      expect(
        incomeRows.singleWhere((row) => row.name == '报销收入').iconKey,
        'currency-line',
      );
      expect(
        incomeRows.singleWhere((row) => row.name == '优惠').iconKey,
        'coupon-3-line',
      );
      expect(metadataRow.value, currentBuiltinDataVersion.toString());
      expect(
        expenseRows.every((row) => row.source == AccountSource.builtin),
        isTrue,
      );
    });

    test('creates system-keyed builtin accounts and categories', () async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final rows = await database.select(database.accounts).get();

      expect(
        rows.where(
          (row) =>
              row.name == '系统期初余额(CNY)' &&
              row.systemKey == SystemKey.openingBalance &&
              row.source == AccountSource.builtin,
        ),
        hasLength(1),
      );
      expect(
        rows.where(
          (row) =>
              row.name == '报销收入' &&
              row.systemKey == SystemKey.reimbursementGapIncome,
        ),
        hasLength(1),
      );
      expect(
        rows.where(
          (row) =>
              row.name == '利息' &&
              row.systemKey == SystemKey.debtInterestExpense,
        ),
        hasLength(1),
      );
      expect(
        rows.where(
          (row) =>
              row.name == '手续费' && row.systemKey == SystemKey.debtFeeExpense,
        ),
        hasLength(1),
      );
      expect(
        rows.where(
          (row) =>
              row.name == '优惠' && row.systemKey == SystemKey.discountIncome,
        ),
        hasLength(1),
      );
    });

    test('upgrades version 2 builtin income icons', () async {
      final database = createTestDatabase();
      addTearDown(database.close);

      await _setBuiltinIcon(
        database,
        name: '借出',
        type: AccountType.expense,
        iconKey: 'loan_out',
      );
      await _setBuiltinIcon(
        database,
        name: '工作',
        type: AccountType.income,
        iconKey: 'salary',
      );
      await _setBuiltinIcon(
        database,
        name: '工资',
        type: AccountType.income,
        iconKey: 'salary',
      );
      await _setBuiltinIcon(
        database,
        name: '奖金',
        type: AccountType.income,
        iconKey: 'income',
      );
      await _setBuiltinIcon(
        database,
        name: '兼职',
        type: AccountType.income,
        iconKey: 'salary',
      );
      await _setBuiltinIcon(
        database,
        name: '投资收益',
        type: AccountType.income,
        iconKey: 'income',
      );
      await _setBuiltinIcon(
        database,
        name: '其他',
        type: AccountType.income,
        iconKey: 'income',
      );
      await _setBuiltinIcon(
        database,
        name: '借入',
        type: AccountType.income,
        iconKey: 'loan_in',
      );
      await _setBuiltinIcon(
        database,
        name: '报销收入',
        type: AccountType.income,
        iconKey: 'reimburse',
      );
      await database
          .into(database.appMetadata)
          .insert(
            AppMetadataCompanion.insert(key: builtinDataVersionKey, value: '2'),
            mode: InsertMode.insertOrReplace,
          );

      await ensureBuiltinData(database);

      final rows = await database.select(database.accounts).get();
      final metadataRow =
          await (database.select(database.appMetadata)..where(
            (metadata) => metadata.key.equals(builtinDataVersionKey),
          )).getSingle();

      expect(
        rows.singleWhere((row) => row.name == '借出').iconKey,
        'logout-box-r-line',
      );
      expect(
        rows.singleWhere((row) => row.name == '工作').iconKey,
        'briefcase-line',
      );
      expect(
        rows.singleWhere((row) => row.name == '工资').iconKey,
        'wallet-3-line',
      );
      expect(
        rows.singleWhere((row) => row.name == '奖金').iconKey,
        'trophy-line',
      );
      expect(
        rows.singleWhere((row) => row.name == '兼职').iconKey,
        'rest-time-line',
      );
      expect(
        rows.singleWhere((row) => row.name == '投资收益').iconKey,
        'funds-line',
      );
      expect(
        rows
            .singleWhere(
              (row) =>
                  row.name == '其他' && row.accountType == AccountType.income,
            )
            .iconKey,
        'more-2-line',
      );
      expect(
        rows.singleWhere((row) => row.name == '借入').iconKey,
        'hand-coin-line',
      );
      expect(
        rows.singleWhere((row) => row.name == '报销收入').iconKey,
        'currency-line',
      );
      expect(
        rows.singleWhere((row) => row.name == '优惠').iconKey,
        'coupon-3-line',
      );
      expect(metadataRow.value, currentBuiltinDataVersion.toString());
    });

    test('is versioned and idempotent', () async {
      final database = createTestDatabase();
      addTearDown(database.close);

      await ensureBuiltinData(database);
      await ensureBuiltinData(database);

      final rows = await database.select(database.accounts).get();

      expect(rows.where((row) => row.name == '食品餐饮'), hasLength(1));
      expect(
        rows.where((row) => row.systemKey == SystemKey.openingBalance),
        hasLength(1),
      );
    });
  });
}

Future<void> _setBuiltinIcon(
  AppDatabase database, {
  required String name,
  required AccountType type,
  required String iconKey,
}) async {
  await (database.update(database.accounts)..where(
    (account) =>
        account.name.equals(name) &
        account.accountType.equalsValue(type) &
        account.source.equalsValue(AccountSource.builtin),
  )).write(AccountsCompanion(iconKey: Value(iconKey)));
}
