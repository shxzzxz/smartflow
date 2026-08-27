// ignore_for_file: experimental_member_use

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/id/id_generator.dart';
import '../../../core/money/money.dart';
import '../../../domain/ledger/entity/entry.dart';
import '../../../domain/ledger/entity/transaction_line.dart';
import '../../../domain/ledger/service/posting/posting_engine.dart';
import '../../../domain/ledger/service/posting/posting_rule.dart';
import '../../../domain/ledger/valobj/ledger_enum.dart';
import '../app_database.dart';
import 'transaction_line_migration_error.dart';

/// v29:把 transaction_details 重建为 transaction_lines。
///
/// 分项从此承载过账输入的完整快照,因此存量分项需要补齐角色与账户,报销支出分类
/// 也由交易列下沉为分项。账户只能从分录回填——此刻全部存量交易都是单腿的,
/// 「每个角色一条分录」的前提成立。验收门槛是过账复现:用回填后的交易与分项重新
/// 过账,必须逐条复现库中现存分录;不复现即回填错误或角色缺失。迁移不重算余额。
Future<void> migrateTransactionLines(
  AppDatabase database,
  Migrator migrator,
) async {
  await migrator.createTable(database.transactionLines);
  await createTransactionLineIndexes(database);
  await _backfillTransactionLines(database);
  await database.customStatement('DROP TABLE transaction_details');
  await _dropReimbursementExpenseColumn(database);
}

Future<void> createTransactionLineIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transaction_lines_transaction_idx '
    'ON transaction_lines (transaction_id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transaction_lines_account_role_idx '
    'ON transaction_lines (account_id, role)',
  );
}

const _uuid = Uuid();

class _MigrationIdGenerator implements IdGenerator {
  const _MigrationIdGenerator();

  @override
  String newId() => _uuid.v7();
}

Future<void> _backfillTransactionLines(AppDatabase database) async {
  final accountTypes = await _loadAccountTypes(database);
  final systemAccountIds = await _loadSystemAccountIds(database);
  final entriesByTransaction = await _loadEntries(database);
  final legacyAmountsByTransaction = await _loadLegacyAmounts(database);
  const engine = PostingEngine(idGenerator: _MigrationIdGenerator());

  final transactionRows = await database.customSelect('''
SELECT transaction_row.id,
       transaction_row.business_purpose,
       transaction_row.primary_amount_minor,
       transaction_row.reimbursement_expense_account_id,
       parent_row.business_purpose AS parent_business_purpose,
       parent_row.reimbursement_expense_account_id
         AS parent_reimbursement_expense_account_id
FROM transactions AS transaction_row
LEFT JOIN transactions AS parent_row
  ON parent_row.id = transaction_row.parent_transaction_id
ORDER BY transaction_row.id
''').get();

  final companions = <TransactionLinesCompanion>[];
  final primaryAmountCorrections = <String, int>{};
  for (final row in transactionRows) {
    final transactionId = row.read<String>('id');
    final businessPurpose = BusinessPurpose.values.byName(
      row.read<String>('business_purpose'),
    );
    if (businessPurpose == BusinessPurpose.reimbursementClose) {
      final legacyAmounts =
          legacyAmountsByTransaction[transactionId] ?? const <String, int>{};
      final actual =
          (legacyAmounts['reimbursementCloseMain'] ?? 0) +
          (legacyAmounts['reimbursementGapIncome'] ?? 0) -
          (legacyAmounts['reimbursementGapExpense'] ?? 0);
      primaryAmountCorrections[transactionId] = actual;
    }
    final entries = entriesByTransaction[transactionId] ?? const <Entry>[];
    final lines = _linesFor(
      transactionId: transactionId,
      businessPurpose: businessPurpose,
      primaryAmount: Money(minorUnits: row.read<int>('primary_amount_minor')),
      reimbursementExpenseAccountId: row.readNullable<String>(
        'reimbursement_expense_account_id',
      ),
      parentBusinessPurpose: switch (row.readNullable<String>(
        'parent_business_purpose',
      )) {
        final value? => BusinessPurpose.values.byName(value),
        null => null,
      },
      parentReimbursementExpenseAccountId: row.readNullable<String>(
        'parent_reimbursement_expense_account_id',
      ),
      entries: entries,
      legacyAmounts:
          legacyAmountsByTransaction[transactionId] ?? const <String, int>{},
      accountTypes: accountTypes,
      systemAccountIds: systemAccountIds,
    );

    _verifyPostingReplay(
      engine: engine,
      transactionId: transactionId,
      businessPurpose: businessPurpose,
      lines: lines,
      entries: entries,
      accountTypes: accountTypes,
      systemAccountIds: systemAccountIds,
    );

    companions.addAll([
      for (final line in lines)
        TransactionLinesCompanion.insert(
          id: line.id,
          transactionId: transactionId,
          lineNo: line.lineNo,
          role: line.role,
          accountId: Value(line.accountId),
          amountMinor: line.amount.minorUnits,
        ),
    ]);
  }

  if (companions.isNotEmpty) {
    await database.batch(
      (batch) => batch.insertAll(database.transactionLines, companions),
    );
  }
  for (final correction in primaryAmountCorrections.entries) {
    await database.customStatement(
      'UPDATE transactions SET primary_amount_minor = ? WHERE id = ?',
      [correction.value, correction.key],
    );
  }
}

void _verifyPostingReplay({
  required PostingEngine engine,
  required String transactionId,
  required BusinessPurpose businessPurpose,
  required List<TransactionLine> lines,
  required List<Entry> entries,
  required Map<String, AccountType> accountTypes,
  required Map<SystemKey, String> systemAccountIds,
}) {
  final replayed = engine.postEntries(
    transactionId: transactionId,
    businessPurpose: businessPurpose,
    lines: lines,
    systemAccountIds: systemAccountIds,
    accountTypes: accountTypes,
  );
  if (sameEntries(replayed, entries)) return;
  throw TransactionLineMigrationError(
    transactionId: transactionId,
    reason: TransactionLineMigrationFailureReason.postingReplayMismatch,
    businessPurpose: businessPurpose.name,
    detail:
        'replayed=${_describeEntries(replayed)} '
        'stored=${_describeEntries(entries)} '
        'lines=${_describeLines(lines)}',
  );
}

String _describeEntries(List<Entry> entries) {
  final shapes =
      entries
          .map(
            (entry) =>
                '${entry.accountId}:${entry.direction.name}:'
                '${entry.amount.minorUnits}',
          )
          .toList()
        ..sort();
  return shapes.join(',');
}

String _describeLines(List<TransactionLine> lines) {
  return lines
      .map(
        (line) =>
            '${line.role.name}:${line.accountId ?? '-'}:'
            '${line.amount.minorUnits}',
      )
      .join(',');
}

Future<Map<String, AccountType>> _loadAccountTypes(AppDatabase database) async {
  final rows = await database
      .customSelect('SELECT id, account_type FROM accounts')
      .get();
  return {
    for (final row in rows)
      row.read<String>('id'): AccountType.values.byName(
        row.read<String>('account_type'),
      ),
  };
}

Future<Map<SystemKey, String>> _loadSystemAccountIds(
  AppDatabase database,
) async {
  final rows = await database
      .customSelect(
        'SELECT id, system_key FROM accounts WHERE system_key IS NOT NULL',
      )
      .get();
  return {
    for (final row in rows)
      SystemKey.values.byName(row.read<String>('system_key')): row.read<String>(
        'id',
      ),
  };
}

Future<Map<String, List<Entry>>> _loadEntries(AppDatabase database) async {
  final rows = await database
      .customSelect(
        'SELECT id, transaction_id, account_id, direction, amount_minor '
        'FROM entries ORDER BY transaction_id, id',
      )
      .get();
  final result = <String, List<Entry>>{};
  for (final row in rows) {
    final transactionId = row.read<String>('transaction_id');
    result
        .putIfAbsent(transactionId, () => <Entry>[])
        .add(
          Entry(
            id: row.read<String>('id'),
            transactionId: transactionId,
            accountId: row.read<String>('account_id'),
            direction: EntryDirection.values.byName(
              row.read<String>('direction'),
            ),
            amount: Money(minorUnits: row.read<int>('amount_minor')),
          ),
        );
  }
  return result;
}

/// 旧分项只有类型与金额,不含账户;账户在下面从分录反推。
Future<Map<String, Map<String, int>>> _loadLegacyAmounts(
  AppDatabase database,
) async {
  final rows = await database
      .customSelect(
        'SELECT transaction_id, detail_type, SUM(amount_minor) AS total '
        'FROM transaction_details GROUP BY transaction_id, detail_type',
      )
      .get();
  final result = <String, Map<String, int>>{};
  for (final row in rows) {
    result.putIfAbsent(
      row.read<String>('transaction_id'),
      () => <String, int>{},
    )[row.read<String>('detail_type')] = row.read<int>(
      'total',
    );
  }
  return result;
}

Future<void> _dropReimbursementExpenseColumn(AppDatabase database) async {
  await database.customStatement('''
CREATE TABLE transactions_v29 (
  id TEXT NOT NULL PRIMARY KEY,
  business_purpose TEXT NOT NULL,
  occurred_at INTEGER NOT NULL,
  posted_at INTEGER NOT NULL,
  primary_amount_minor INTEGER NOT NULL,
  counterparty_name TEXT NULL,
  note TEXT NULL,
  parent_transaction_id TEXT NULL,
  is_excluded_from_stats INTEGER NOT NULL DEFAULT 0
    CHECK (is_excluded_from_stats IN (0, 1)),
  is_excluded_from_budget INTEGER NOT NULL DEFAULT 0
    CHECK (is_excluded_from_budget IN (0, 1)),
  source_kind TEXT NOT NULL,
  owner_type TEXT NULL,
  owner_id TEXT NULL,
  owner_role TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP)),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', CURRENT_TIMESTAMP))
)
''');
  await database.customStatement('''
INSERT INTO transactions_v29 (
  id, business_purpose, occurred_at, posted_at, primary_amount_minor,
  counterparty_name, note, parent_transaction_id, is_excluded_from_stats,
  is_excluded_from_budget, source_kind, owner_type, owner_id, owner_role,
  created_at, updated_at
)
SELECT
  id, business_purpose, occurred_at, posted_at, primary_amount_minor,
  counterparty_name, note, parent_transaction_id, is_excluded_from_stats,
  is_excluded_from_budget, source_kind, owner_type, owner_id, owner_role,
  created_at, updated_at
FROM transactions
''');
  await database.customStatement('DROP TABLE transactions');
  await database.customStatement(
    'ALTER TABLE transactions_v29 RENAME TO transactions',
  );
}

List<TransactionLine> _linesFor({
  required String transactionId,
  required BusinessPurpose businessPurpose,
  required Money primaryAmount,
  required String? reimbursementExpenseAccountId,
  required BusinessPurpose? parentBusinessPurpose,
  required String? parentReimbursementExpenseAccountId,
  required List<Entry> entries,
  required Map<String, int> legacyAmounts,
  required Map<String, AccountType> accountTypes,
  required Map<SystemKey, String> systemAccountIds,
}) {
  final builder = _LineBuilder(
    transactionId: transactionId,
    businessPurpose: businessPurpose,
    entries: entries,
    accountTypes: accountTypes,
  );
  Money legacy(String detailType) =>
      Money(minorUnits: legacyAmounts[detailType] ?? 0);

  switch (businessPurpose) {
    case BusinessPurpose.dailyExpense:
      builder
        ..add(TransactionRole.category, primaryAmount, builder.onlyDebit())
        ..add(
          TransactionRole.settlementOut,
          primaryAmount,
          builder.onlyCredit(),
        );
    case BusinessPurpose.dailyIncome:
      builder
        ..add(TransactionRole.category, primaryAmount, builder.onlyCredit())
        ..add(TransactionRole.settlementIn, primaryAmount, builder.onlyDebit());
    case BusinessPurpose.transfer:
      builder
        ..add(
          TransactionRole.settlementOut,
          primaryAmount,
          builder.onlyCredit(),
        )
        ..add(
          TransactionRole.settlementIn,
          primaryAmount,
          builder.debitWhere(typeIsNot: AccountType.expense),
        );
      final fee = legacy('transferFee');
      if (fee.minorUnits > 0) builder.add(TransactionRole.fee, fee, null);
    case BusinessPurpose.refund:
      builder.add(
        TransactionRole.settlementIn,
        primaryAmount,
        builder.onlyDebit(),
      );
      if (parentBusinessPurpose == BusinessPurpose.reimbursementAdvance) {
        if (parentReimbursementExpenseAccountId == null) {
          throw TransactionLineMigrationError(
            transactionId: transactionId,
            reason: TransactionLineMigrationFailureReason
                .missingReimbursementExpenseCategory,
            businessPurpose: businessPurpose.name,
          );
        }
        builder
          ..add(
            TransactionRole.reimbursementExpenseCategory,
            primaryAmount,
            parentReimbursementExpenseAccountId,
          )
          ..add(
            TransactionRole.receivable,
            primaryAmount,
            builder.onlyCredit(),
          );
      } else {
        builder.add(
          TransactionRole.refundOffset,
          primaryAmount,
          builder.onlyCredit(),
        );
      }
    case BusinessPurpose.reimbursementAdvance:
      if (reimbursementExpenseAccountId == null) {
        throw TransactionLineMigrationError(
          transactionId: transactionId,
          reason: TransactionLineMigrationFailureReason
              .missingReimbursementExpenseCategory,
          businessPurpose: businessPurpose.name,
        );
      }
      builder
        ..add(
          TransactionRole.reimbursementExpenseCategory,
          primaryAmount,
          reimbursementExpenseAccountId,
        )
        ..add(TransactionRole.receivable, primaryAmount, builder.onlyDebit())
        ..add(
          TransactionRole.settlementOut,
          primaryAmount,
          builder.onlyCredit(),
        );
    case BusinessPurpose.reimbursementReceipt:
      builder
        ..add(TransactionRole.settlementIn, primaryAmount, builder.onlyDebit())
        ..add(TransactionRole.receivable, primaryAmount, builder.onlyCredit());
    case BusinessPurpose.reimbursementClose:
      final outstanding = legacy('reimbursementCloseMain');
      final gapIncome = legacy('reimbursementGapIncome');
      final gapExpense = legacy('reimbursementGapExpense');
      final actual = outstanding + gapIncome - gapExpense;
      // 一分未收时旧数据没有收款分录,收款账户已丢失,按既有语义落到幽灵账户。
      builder.add(
        TransactionRole.settlementIn,
        actual,
        actual.minorUnits > 0
            ? builder.debitWhere(typeIsNot: AccountType.expense)
            : systemAccountIds[SystemKey.ghostAccount],
      );
      if (outstanding.minorUnits > 0) {
        builder.add(
          TransactionRole.receivable,
          outstanding,
          builder.creditWhere(typeIs: AccountType.asset),
        );
      }
      if (gapIncome.minorUnits > 0) {
        builder.add(TransactionRole.reimbursementGapIncome, gapIncome, null);
      }
      if (gapExpense.minorUnits > 0) {
        builder.add(
          TransactionRole.reimbursementGapExpense,
          gapExpense,
          builder.debitWhere(typeIs: AccountType.expense),
        );
      }
    case BusinessPurpose.debtRepayment:
      builder.add(
        TransactionRole.liability,
        legacy('repaymentPrincipal'),
        builder.debitWhere(typeIs: AccountType.liability),
      );
      for (final (role, detailType) in const [
        (TransactionRole.interest, 'repaymentInterest'),
        (TransactionRole.fee, 'repaymentFee'),
        (TransactionRole.discount, 'repaymentDiscount'),
      ]) {
        final amount = legacy(detailType);
        if (amount.minorUnits > 0) builder.add(role, amount, null);
      }
      builder.add(
        TransactionRole.settlementOut,
        primaryAmount,
        builder.creditWhere(typeIsNot: AccountType.income),
      );
    case BusinessPurpose.borrowing:
      builder
        ..add(TransactionRole.liability, primaryAmount, builder.onlyCredit())
        ..add(TransactionRole.settlementIn, primaryAmount, builder.onlyDebit());
    case BusinessPurpose.lending:
      builder
        ..add(TransactionRole.receivable, primaryAmount, builder.onlyDebit())
        ..add(
          TransactionRole.settlementOut,
          primaryAmount,
          builder.onlyCredit(),
        );
    case BusinessPurpose.receivableCollection:
      final interest = legacy('receivableCollectionInterest');
      builder.add(
        TransactionRole.receivable,
        legacy('receivableCollectionPrincipal'),
        builder.creditWhere(typeIs: AccountType.asset),
      );
      if (interest.minorUnits > 0) {
        builder.add(TransactionRole.interest, interest, null);
      }
      builder.add(
        TransactionRole.settlementIn,
        primaryAmount,
        builder.onlyDebit(),
      );
    case BusinessPurpose.badDebt:
      builder.add(
        TransactionRole.receivable,
        primaryAmount,
        builder.onlyCredit(),
      );
    case BusinessPurpose.debtRelief:
      builder.add(
        TransactionRole.liability,
        primaryAmount,
        builder.onlyDebit(),
      );
    case BusinessPurpose.openingBalance:
    case BusinessPurpose.balanceAdjustment:
      // 方向信息只存在于分录里,回填成带符号金额。
      final target = builder.entryWhere(typeIsNot: AccountType.equity);
      builder.add(
        businessPurpose == BusinessPurpose.openingBalance
            ? TransactionRole.openingBalance
            : TransactionRole.balanceAdjustment,
        Money(
          minorUnits: balanceDeltaMinor(
            accountType: builder.typeOf(target.accountId),
            direction: target.direction,
            amountMinor: target.amount.minorUnits,
          ),
        ),
        target.accountId,
      );
  }
  return builder.lines;
}

/// 按角色收集分项,并把「从分录反推账户」的模糊查找收在一处。
///
/// 存量数据每个角色恰好一条分录,查找不唯一即视为无法迁移的脏数据。
class _LineBuilder {
  _LineBuilder({
    required this.transactionId,
    required this.businessPurpose,
    required this.entries,
    required this.accountTypes,
  });

  final String transactionId;
  final BusinessPurpose businessPurpose;
  final List<Entry> entries;
  final Map<String, AccountType> accountTypes;
  final lines = <TransactionLine>[];

  void add(TransactionRole role, Money amount, String? accountId) {
    if (roleCarriesAccount(role) && accountId == null) {
      throw _shapeError('missing account for ${role.name}');
    }
    lines.add(
      TransactionLine(
        id: _uuid.v7(),
        transactionId: transactionId,
        lineNo: lines.length + 1,
        role: role,
        accountId: roleCarriesAccount(role) ? accountId : null,
        amount: amount,
      ),
    );
  }

  AccountType typeOf(String accountId) {
    final type = accountTypes[accountId];
    if (type == null) {
      throw TransactionLineMigrationError(
        transactionId: transactionId,
        reason: TransactionLineMigrationFailureReason.unknownAccount,
        businessPurpose: businessPurpose.name,
        detail: accountId,
      );
    }
    return type;
  }

  String onlyDebit() => _matching(EntryDirection.debit, null, null).accountId;

  String onlyCredit() => _matching(EntryDirection.credit, null, null).accountId;

  String debitWhere({AccountType? typeIs, AccountType? typeIsNot}) =>
      _matching(EntryDirection.debit, typeIs, typeIsNot).accountId;

  String creditWhere({AccountType? typeIs, AccountType? typeIsNot}) =>
      _matching(EntryDirection.credit, typeIs, typeIsNot).accountId;

  Entry entryWhere({AccountType? typeIs, AccountType? typeIsNot}) =>
      _matching(null, typeIs, typeIsNot);

  Entry _matching(
    EntryDirection? direction,
    AccountType? typeIs,
    AccountType? typeIsNot,
  ) {
    Entry? found;
    for (final entry in entries) {
      if (direction != null && entry.direction != direction) continue;
      final type = typeOf(entry.accountId);
      if (typeIs != null && type != typeIs) continue;
      if (typeIsNot != null && type == typeIsNot) continue;
      if (found != null) {
        throw _shapeError(
          _describeSelector(direction, typeIs, typeIsNot, 'ambiguous'),
        );
      }
      found = entry;
    }
    if (found == null) {
      throw _shapeError(_describeSelector(direction, typeIs, typeIsNot, 'no'));
    }
    return found;
  }

  String _describeSelector(
    EntryDirection? direction,
    AccountType? typeIs,
    AccountType? typeIsNot,
    String prefix,
  ) {
    return '$prefix ${direction?.name ?? 'entry'} '
        '(typeIs=${typeIs?.name}, typeIsNot=${typeIsNot?.name})';
  }

  TransactionLineMigrationError _shapeError(String detail) {
    return TransactionLineMigrationError(
      transactionId: transactionId,
      reason: TransactionLineMigrationFailureReason.unexpectedEntryShape,
      businessPurpose: businessPurpose.name,
      detail: detail,
    );
  }
}
