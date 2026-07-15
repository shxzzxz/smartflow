import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/widget/business/account/account_endpoint.dart';

class AccountLookup {
  const AccountLookup(this.byId);

  final Map<String, Account> byId;

  Account? find(String id) => byId[id];

  Account? accountOf(Entry entry) => find(entry.accountId);

  AccountType? typeOf(String id) => byId[id]?.type;

  AccountType? typeOfEntry(Entry entry) => typeOf(entry.accountId);

  bool isSettlement(String id) {
    final type = typeOf(id);
    return type == AccountType.asset || type == AccountType.liability;
  }

  bool isSettlementEntry(Entry entry) => isSettlement(entry.accountId);

  AccountEndpoint endpointOf(String id) {
    final account = find(id);
    return AccountEndpoint(
      label: account?.name ?? '—',
      iconKey: account?.iconKey,
    );
  }

  AccountEndpoint endpointOfEntry(Entry entry) => endpointOf(entry.accountId);

  Entry? firstEntryByType(
    Iterable<Entry> entries, {
    required AccountType accountType,
    EntryDirection? direction,
  }) {
    for (final entry in entries) {
      if (typeOfEntry(entry) != accountType) continue;
      if (direction != null && entry.direction != direction) continue;
      return entry;
    }
    return null;
  }

  Entry? firstSettlementEntry(
    Iterable<Entry> entries, {
    EntryDirection? direction,
  }) {
    for (final entry in entries) {
      if (!isSettlementEntry(entry)) continue;
      if (direction != null && entry.direction != direction) continue;
      return entry;
    }
    return null;
  }

  /// 给定一个账户视角,计算该账户在当前交易中的余额变动。
  ///
  /// 用于「账户交易」场景:列表项展示对当前账户的 ±delta。
  /// 公式与 `balance_expressions.dart` 中 SQL 公式一致(asset/expense 借增贷减,
  /// liability/income 贷增借减,equity 同 liability 方向)。
  Money? balanceDeltaForAccount({
    required String accountId,
    required Iterable<Entry> entries,
  }) {
    final accountType = typeOf(accountId);
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
