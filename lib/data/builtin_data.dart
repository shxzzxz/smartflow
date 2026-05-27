import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/ledger/valobj/ledger_enum.dart';
import 'app_database.dart';

const builtinDataVersionKey = 'builtin_data_version';
const currentBuiltinDataVersion = 7;

const _uuid = Uuid();

Future<void> ensureBuiltinData(AppDatabase database) async {
  await database.transaction(() async {
    final version = await _readBuiltinDataVersion(database);
    if (version >= currentBuiltinDataVersion) {
      return;
    }

    if (version < 1) {
      await _seedBuiltinAccounts(database);
    }
    if (version < 2) {
      await _upgradeBuiltinIcons(database);
    }
    if (version < 3) {
      await _upgradeBuiltinIncomeIcons(database);
    }
    if (version < 5) {
      await _upgradeDiscountIncome(database);
    }
    if (version < 6) {
      await _seedGhostAccount(database);
    }
    if (version < 7) {
      await _renameOpeningBalanceAccount(database);
    }

    await _writeBuiltinDataVersion(database, currentBuiltinDataVersion);
  });
}

Future<void> _renameOpeningBalanceAccount(AppDatabase database) async {
  await (database.update(database.accounts)..where(
    (account) => account.systemKey.equalsValue(SystemKey.openingBalance),
  )).write(
    AccountsCompanion(
      name: const Value('系统期初余额'),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

Future<int> _readBuiltinDataVersion(AppDatabase database) async {
  final row =
      await (database.select(database.appMetadata)..where(
        (metadata) => metadata.key.equals(builtinDataVersionKey),
      )).getSingleOrNull();
  return int.tryParse(row?.value ?? '') ?? 0;
}

Future<void> _writeBuiltinDataVersion(AppDatabase database, int version) async {
  await database
      .into(database.appMetadata)
      .insert(
        AppMetadataCompanion.insert(
          key: builtinDataVersionKey,
          value: version.toString(),
          updatedAt: Value(DateTime.now()),
        ),
        mode: InsertMode.insertOrReplace,
      );
}

Future<void> _upgradeBuiltinIcons(AppDatabase database) async {
  await _updateCategoryIcon(
    database,
    name: '人情社交',
    type: AccountType.expense,
    iconKey: 'team-line',
  );
  await _updateCategoryIcon(
    database,
    name: '请客吃饭',
    type: AccountType.expense,
    parentName: '人情社交',
    iconKey: 'service-bell-line',
  );
  await _updateCategoryIcon(
    database,
    name: '茶饮',
    type: AccountType.expense,
    parentName: '食品餐饮',
    iconKey: 'drinks-line',
  );
  await _updateCategoryIcon(
    database,
    name: '早餐',
    type: AccountType.expense,
    parentName: '食品餐饮',
    iconKey: 'cup-line',
  );
  await _updateCategoryIcon(
    database,
    name: '午餐',
    type: AccountType.expense,
    parentName: '食品餐饮',
    iconKey: 'bowl-line',
  );
  await _updateCategoryIcon(
    database,
    name: '食材生鲜',
    type: AccountType.expense,
    parentName: '食品餐饮',
    iconKey: 'cabbage',
  );
  await _updateCategoryIcon(
    database,
    name: '粮油调味',
    type: AccountType.expense,
    parentName: '食品餐饮',
    iconKey: 'rice',
  );
  await _updateCategoryIcon(
    database,
    name: '衣物',
    type: AccountType.expense,
    parentName: '购物消费',
    iconKey: 't-shirt-line',
  );
  await _updateCategoryIcon(
    database,
    name: '房租',
    type: AccountType.expense,
    parentName: '居家生活',
    iconKey: 'home-office-line',
  );
  await _updateCategoryIcon(
    database,
    name: '水电燃',
    type: AccountType.expense,
    parentName: '居家生活',
    iconKey: 'flashlight-line',
  );
  await _updateCategoryIcon(
    database,
    name: '物业',
    type: AccountType.expense,
    parentName: '居家生活',
    iconKey: 'building-2-line',
  );
  await _updateCategoryIcon(
    database,
    name: '出行交通',
    type: AccountType.expense,
    iconKey: 'traffic-light-line',
  );
  await _updateCategoryIcon(
    database,
    name: '公交',
    type: AccountType.expense,
    parentName: '出行交通',
    iconKey: 'bus-2-line',
  );
  await _updateCategoryIcon(
    database,
    name: '休闲娱乐',
    type: AccountType.expense,
    iconKey: 'gamepad-line',
  );
  await _updateCategoryIcon(
    database,
    name: '棋牌桌游',
    type: AccountType.expense,
    parentName: '休闲娱乐',
    iconKey: 'dice-5-line',
  );
  await _updateCategoryIcon(
    database,
    name: '通讯',
    type: AccountType.expense,
    iconKey: 'send-plane-line',
  );
  await _updateCategoryIcon(
    database,
    name: '其他',
    type: AccountType.expense,
    iconKey: 'more-line',
  );
  await _updateCategoryIcon(
    database,
    name: '慈善捐助',
    type: AccountType.expense,
    parentName: '其他',
    iconKey: 'hand-heart-line',
  );
  await _updateCategoryIcon(
    database,
    name: '利息',
    type: AccountType.expense,
    systemKey: SystemKey.debtInterestExpense,
    iconKey: 'money-cny-circle-line',
  );
  await _updateCategoryIcon(
    database,
    name: '手续费',
    type: AccountType.expense,
    systemKey: SystemKey.debtFeeExpense,
    iconKey: 'swap-box-line',
  );
}

Future<void> _upgradeBuiltinIncomeIcons(AppDatabase database) async {
  await _updateCategoryIcon(
    database,
    name: '借出',
    type: AccountType.expense,
    parentName: '其他',
    iconKey: 'logout-box-r-line',
  );
  await _updateCategoryIcon(
    database,
    name: '工作',
    type: AccountType.income,
    iconKey: 'briefcase-line',
  );
  await _updateCategoryIcon(
    database,
    name: '工资',
    type: AccountType.income,
    parentName: '工作',
    iconKey: 'wallet-3-line',
  );
  await _updateCategoryIcon(
    database,
    name: '奖金',
    type: AccountType.income,
    parentName: '工作',
    iconKey: 'trophy-line',
  );
  await _updateCategoryIcon(
    database,
    name: '兼职',
    type: AccountType.income,
    iconKey: 'rest-time-line',
  );
  await _updateCategoryIcon(
    database,
    name: '投资收益',
    type: AccountType.income,
    iconKey: 'funds-line',
  );
  await _updateCategoryIcon(
    database,
    name: '其他',
    type: AccountType.income,
    iconKey: 'more-2-line',
  );
  await _updateCategoryIcon(
    database,
    name: '借入',
    type: AccountType.income,
    parentName: '其他',
    iconKey: 'hand-coin-line',
  );
  await _updateCategoryIcon(
    database,
    name: '报销收入',
    type: AccountType.income,
    systemKey: SystemKey.reimbursementGapIncome,
    iconKey: 'currency-line',
  );
}

Future<void> _upgradeDiscountIncome(AppDatabase database) async {
  final other = await _findBuiltinAccount(
    database,
    name: '其他',
    type: AccountType.income,
  );
  await _ensureCategory(
    database,
    _BuiltinCategory(
      name: '优惠',
      type: AccountType.income,
      parentId: other?.id,
      iconKey: 'coupon-3-line',
      sortOrder: 30,
      systemKey: SystemKey.discountIncome,
    ),
  );
}

Future<void> _seedGhostAccount(AppDatabase database) async {
  await _ensureSystemAccount(
    database,
    const _BuiltinAccount(
      name: '幽灵账户',
      type: AccountType.equity,
      systemKey: SystemKey.ghostAccount,
      iconKey: 'ghost-line',
    ),
  );
}

Future<void> _updateCategoryIcon(
  AppDatabase database, {
  required String name,
  required AccountType type,
  required String iconKey,
  String? parentName,
  SystemKey? systemKey,
}) async {
  final parentId =
      parentName == null
          ? null
          : await _findParentId(database, name: parentName, type: type);
  if (parentName != null && parentId == null) {
    return;
  }

  await (database.update(database.accounts)..where((account) {
    final identity =
        systemKey == null
            ? account.name.equals(name) &
                (parentId == null
                    ? account.parentId.isNull()
                    : account.parentId.equals(parentId))
            : account.systemKey.equalsValue(systemKey);
    return identity &
        account.accountType.equalsValue(type) &
        account.source.equalsValue(AccountSource.builtin);
  })).write(
    AccountsCompanion(
      iconKey: Value(iconKey),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

Future<String?> _findParentId(
  AppDatabase database, {
  required String name,
  required AccountType type,
}) async {
  final row =
      await (database.select(database.accounts)..where(
        (account) =>
            account.name.equals(name) &
            account.accountType.equalsValue(type) &
            account.parentId.isNull(),
      )).getSingleOrNull();
  return row?.id;
}

Future<void> _seedBuiltinAccounts(AppDatabase database) async {
  await _ensureCategoryTree(database, _expenseCategories);
  await _ensureCategoryTree(database, _incomeCategories);
  await _ensureSystemAccount(
    database,
    const _BuiltinAccount(
      name: '系统期初余额',
      type: AccountType.equity,
      systemKey: SystemKey.openingBalance,
      iconKey: 'transfer',
    ),
  );
  await _seedGhostAccount(database);
}

Future<void> _ensureCategoryTree(
  AppDatabase database,
  List<_BuiltinCategory> roots,
) async {
  for (final root in roots) {
    final parentId = await _ensureCategory(database, root);
    for (final child in root.children) {
      await _ensureCategory(
        database,
        child.copyWith(type: root.type, parentId: parentId),
      );
    }
  }
}

Future<String> _ensureCategory(
  AppDatabase database,
  _BuiltinCategory category,
) async {
  final existing = await _findBuiltinAccount(
    database,
    name: category.name,
    type: category.type!,
    parentId: category.parentId,
    systemKey: category.systemKey,
  );
  if (existing != null) {
    await _markBuiltinSource(database, existing.id);
    return existing.id;
  }

  final id = _uuid.v7();
  final now = DateTime.now();
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          name: category.name,
          accountType: category.type!,
          parentId: Value(category.parentId),
          iconKey: Value(category.iconKey),
          sortOrder: Value(category.sortOrder),
          systemKey: Value(category.systemKey),
          source: const Value(AccountSource.builtin),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
  return id;
}

Future<void> _ensureSystemAccount(
  AppDatabase database,
  _BuiltinAccount account,
) async {
  final existing = await _findBuiltinAccount(
    database,
    name: account.name,
    type: account.type,
    systemKey: account.systemKey,
  );
  if (existing != null) {
    await _markBuiltinSource(database, existing.id);
    return;
  }

  final now = DateTime.now();
  await database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(
          id: _uuid.v7(),
          name: account.name,
          accountType: account.type,
          iconKey: Value(account.iconKey),
          systemKey: Value(account.systemKey),
          source: const Value(AccountSource.builtin),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<AccountRow?> _findBuiltinAccount(
  AppDatabase database, {
  required String name,
  required AccountType type,
  String? parentId,
  SystemKey? systemKey,
}) {
  return (database.select(database.accounts)..where((account) {
    final identity =
        systemKey == null
            ? account.name.equals(name) &
                (parentId == null
                    ? account.parentId.isNull()
                    : account.parentId.equals(parentId))
            : account.systemKey.equalsValue(systemKey);
    return identity & account.accountType.equalsValue(type);
  })).getSingleOrNull();
}

Future<void> _markBuiltinSource(AppDatabase database, String accountId) async {
  await (database.update(database.accounts)
    ..where((account) => account.id.equals(accountId))).write(
    AccountsCompanion(
      source: const Value(AccountSource.builtin),
      updatedAt: Value(DateTime.now()),
    ),
  );
}

class _BuiltinAccount {
  const _BuiltinAccount({
    required this.name,
    required this.type,
    required this.systemKey,
    this.iconKey,
  });

  final String name;
  final AccountType type;
  final SystemKey systemKey;
  final String? iconKey;
}

class _BuiltinCategory {
  const _BuiltinCategory({
    required this.name,
    this.type,
    this.parentId,
    this.iconKey,
    this.sortOrder = 0,
    this.systemKey,
    this.children = const [],
  });

  final String name;
  final AccountType? type;
  final String? parentId;
  final String? iconKey;
  final int sortOrder;
  final SystemKey? systemKey;
  final List<_BuiltinCategory> children;

  _BuiltinCategory copyWith({AccountType? type, String? parentId}) {
    return _BuiltinCategory(
      name: name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      iconKey: iconKey,
      sortOrder: sortOrder,
      systemKey: systemKey,
      children: children,
    );
  }
}

const _expenseCategories = [
  _BuiltinCategory(
    name: '人情社交',
    type: AccountType.expense,
    iconKey: 'team-line',
    sortOrder: 10,
    children: [
      _BuiltinCategory(
        name: '请客吃饭',
        iconKey: 'service-bell-line',
        sortOrder: 10,
      ),
      _BuiltinCategory(name: '送礼人情', iconKey: 'gift', sortOrder: 20),
    ],
  ),
  _BuiltinCategory(
    name: '食品餐饮',
    type: AccountType.expense,
    iconKey: 'meal',
    sortOrder: 20,
    children: [
      _BuiltinCategory(name: '茶饮', iconKey: 'drinks-line', sortOrder: 10),
      _BuiltinCategory(name: '早餐', iconKey: 'cup-line', sortOrder: 20),
      _BuiltinCategory(name: '午餐', iconKey: 'bowl-line', sortOrder: 30),
      _BuiltinCategory(name: '晚餐', iconKey: 'dinner', sortOrder: 40),
      _BuiltinCategory(name: '酒水', iconKey: 'drink', sortOrder: 50),
      _BuiltinCategory(name: '休闲零食', iconKey: 'snack', sortOrder: 60),
      _BuiltinCategory(name: '食材生鲜', iconKey: 'cabbage', sortOrder: 70),
      _BuiltinCategory(name: '粮油调味', iconKey: 'rice', sortOrder: 80),
    ],
  ),
  _BuiltinCategory(
    name: '购物消费',
    type: AccountType.expense,
    iconKey: 'shopping',
    sortOrder: 30,
    children: [
      _BuiltinCategory(name: '日用品', iconKey: 'shopping', sortOrder: 10),
      _BuiltinCategory(name: '衣物', iconKey: 't-shirt-line', sortOrder: 20),
      _BuiltinCategory(name: '手机数码', iconKey: 'phone', sortOrder: 30),
    ],
  ),
  _BuiltinCategory(
    name: '居家生活',
    type: AccountType.expense,
    iconKey: 'home',
    sortOrder: 40,
    children: [
      _BuiltinCategory(name: '房租', iconKey: 'home-office-line', sortOrder: 10),
      _BuiltinCategory(name: '水电燃', iconKey: 'flashlight-line', sortOrder: 20),
      _BuiltinCategory(name: '物业', iconKey: 'building-2-line', sortOrder: 30),
    ],
  ),
  _BuiltinCategory(
    name: '出行交通',
    type: AccountType.expense,
    iconKey: 'traffic-light-line',
    sortOrder: 50,
    children: [
      _BuiltinCategory(name: '地铁', iconKey: 'metro', sortOrder: 10),
      _BuiltinCategory(name: '打车', iconKey: 'taxi', sortOrder: 20),
      _BuiltinCategory(name: '公交', iconKey: 'bus-2-line', sortOrder: 30),
    ],
  ),
  _BuiltinCategory(
    name: '休闲娱乐',
    type: AccountType.expense,
    iconKey: 'gamepad-line',
    sortOrder: 60,
    children: [
      _BuiltinCategory(name: '电影', iconKey: 'movie', sortOrder: 10),
      _BuiltinCategory(name: '棋牌桌游', iconKey: 'dice-5-line', sortOrder: 20),
    ],
  ),
  _BuiltinCategory(
    name: '文化教育',
    type: AccountType.expense,
    iconKey: 'book',
    sortOrder: 70,
  ),
  _BuiltinCategory(
    name: '健康医疗',
    type: AccountType.expense,
    iconKey: 'health',
    sortOrder: 80,
  ),
  _BuiltinCategory(
    name: '通讯',
    type: AccountType.expense,
    iconKey: 'send-plane-line',
    sortOrder: 90,
  ),
  _BuiltinCategory(
    name: '其他',
    type: AccountType.expense,
    iconKey: 'more-line',
    sortOrder: 100,
    children: [
      _BuiltinCategory(name: '慈善捐助', iconKey: 'hand-heart-line', sortOrder: 10),
      _BuiltinCategory(
        name: '利息',
        iconKey: 'money-cny-circle-line',
        sortOrder: 20,
        systemKey: SystemKey.debtInterestExpense,
      ),
      _BuiltinCategory(
        name: '手续费',
        iconKey: 'swap-box-line',
        sortOrder: 30,
        systemKey: SystemKey.debtFeeExpense,
      ),
      _BuiltinCategory(name: '借出', iconKey: 'logout-box-r-line', sortOrder: 40),
    ],
  ),
];

const _incomeCategories = [
  _BuiltinCategory(
    name: '工作',
    type: AccountType.income,
    iconKey: 'briefcase-line',
    sortOrder: 10,
    children: [
      _BuiltinCategory(name: '工资', iconKey: 'wallet-3-line', sortOrder: 10),
      _BuiltinCategory(name: '奖金', iconKey: 'trophy-line', sortOrder: 20),
    ],
  ),
  _BuiltinCategory(
    name: '兼职',
    type: AccountType.income,
    iconKey: 'rest-time-line',
    sortOrder: 20,
  ),
  _BuiltinCategory(
    name: '投资收益',
    type: AccountType.income,
    iconKey: 'funds-line',
    sortOrder: 30,
  ),
  _BuiltinCategory(
    name: '其他',
    type: AccountType.income,
    iconKey: 'more-2-line',
    sortOrder: 40,
    children: [
      _BuiltinCategory(name: '借入', iconKey: 'hand-coin-line', sortOrder: 10),
      _BuiltinCategory(
        name: '报销收入',
        iconKey: 'currency-line',
        sortOrder: 20,
        systemKey: SystemKey.reimbursementGapIncome,
      ),
      _BuiltinCategory(
        name: '优惠',
        iconKey: 'coupon-3-line',
        sortOrder: 30,
        systemKey: SystemKey.discountIncome,
      ),
    ],
  ),
];
