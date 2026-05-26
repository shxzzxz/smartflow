import '../../core/money/money.dart';
import '../../application/ledger/ledger_api.dart';

/// `Entry` 在 UI 层的查表能力。
///
/// 域实体 `Entry` 仅持有 `accountId`,UI 派生(如「找设算账户」「分流出/流入」)
/// 需要 account 元数据(type / name / iconKey)。UI 层通过 accountsByIdProvider
/// 拿到全量 `Map<int, Account>`,再借这些 extension 在 entries 上做投影。
extension EntryAccountLookup on Entry {
  AccountType? resolveType(Map<int, Account> accountsById) =>
      accountsById[accountId]?.type;

  Account? resolveAccount(Map<int, Account> accountsById) =>
      accountsById[accountId];
}

/// 按账户类型从一组 entries 里挑第一条匹配项(direction 可空,空表示不限方向)。
Entry? firstEntryByType(
  Iterable<Entry> entries, {
  required Map<int, Account> accountsById,
  required AccountType accountType,
  EntryDirection? direction,
}) {
  for (final entry in entries) {
    if (accountsById[entry.accountId]?.type != accountType) continue;
    if (direction != null && entry.direction != direction) continue;
    return entry;
  }
  return null;
}

/// 从 entries 找第一条「结算账户」(asset / liability)。
Entry? firstSettlementEntry(
  Iterable<Entry> entries, {
  required Map<int, Account> accountsById,
  EntryDirection? direction,
}) {
  for (final entry in entries) {
    final type = accountsById[entry.accountId]?.type;
    final isSettlement =
        type == AccountType.asset || type == AccountType.liability;
    if (!isSettlement) continue;
    if (direction != null && entry.direction != direction) continue;
    return entry;
  }
  return null;
}

/// 给定一个账户视角,计算该账户在当前交易中的余额变动。
///
/// 用于「账户流水」场景:列表项展示对当前账户的 ±delta。
/// 公式与 `balance_expressions.dart` 中 SQL 公式一致(asset/expense 借增贷减,
/// liability/income 贷增借减,equity 同 liability 方向)。
Money? balanceDeltaForAccount({
  required int accountId,
  required Iterable<Entry> entries,
  required Map<int, Account> accountsById,
}) {
  final accountType = accountsById[accountId]?.type;
  if (accountType == null) return null;

  var deltaMinor = 0;
  var matched = false;
  for (final entry in entries) {
    if (entry.accountId != accountId) continue;
    matched = true;
    final signed = _signedAmount(
      accountType: accountType,
      direction: entry.direction,
      amountMinor: entry.amount.minorUnits,
    );
    deltaMinor += signed;
  }
  if (!matched) return null;
  return Money(minorUnits: deltaMinor);
}

int _signedAmount({
  required AccountType accountType,
  required EntryDirection direction,
  required int amountMinor,
}) {
  final increasesOnDebit =
      accountType == AccountType.asset || accountType == AccountType.expense;
  if (increasesOnDebit) {
    return direction == EntryDirection.debit ? amountMinor : -amountMinor;
  }
  return direction == EntryDirection.credit ? amountMinor : -amountMinor;
}
