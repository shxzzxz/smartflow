import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import '../../../widget/business/account_lookup.dart';

part 'ledger_query_providers.g.dart';

@riverpod
Stream<List<Account>> accountList(Ref ref) {
  return ref.watch(accountQueryServiceProvider).watchAccounts({
    AccountType.asset,
    AccountType.liability,
  });
}

/// 全量账户索引。覆盖 5 种 account_type,供 UI 层把 entries 的 accountId
/// 解析为 Account 元数据(type / name / iconKey 等)。
///
/// 新 UI 优先使用 `accountLookupProvider`; 仍保留 Map 形式给表单解析等旧路径使用。
@riverpod
Stream<Map<String, Account>> accountsById(Ref ref) {
  return ref.watch(accountQueryServiceProvider).watchAccountsById();
}

@riverpod
Stream<AccountLookup> accountLookup(Ref ref) {
  return ref
      .watch(accountQueryServiceProvider)
      .watchAccountsById()
      .map(AccountLookup.new);
}

@riverpod
Stream<List<Account>> accountsForUsage(Ref ref, AccountUsage usage) {
  return ref.watch(accountQueryServiceProvider).watchAccountsForUsage(usage);
}

@riverpod
Stream<List<Account>> accountsByTypes(Ref ref, Set<AccountType> types) {
  return ref.watch(accountQueryServiceProvider).watchAccounts(types);
}

@riverpod
Stream<List<CategoryNode>> categoryTree(Ref ref, AccountType type) {
  return ref.watch(categoryQueryServiceProvider).watchCategoryTree(type);
}

@riverpod
Stream<List<TransactionListReadModel>> transactionList(
  Ref ref, {
  String? accountId,
}) {
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(
        TransactionListQuery(
          accountId: accountId,
          topLevelOnly: accountId == null,
        ),
      );
}

@riverpod
Stream<BalanceSheetComparison> balanceSheetComparison(Ref ref) {
  final now = DateTime.now();
  return ref
      .watch(financialMetricsServiceProvider)
      .watchBalanceSheetComparison(
        BalanceSheetComparisonQuery(
          month: MonthKey.fromDate(now),
          asOfExclusive: now,
        ),
      );
}

@riverpod
Stream<List<NetAssetTrendPoint>> netAssetTrend(Ref ref, {int months = 6}) {
  final now = DateTime.now();
  return ref
      .watch(financialMetricsServiceProvider)
      .watchNetAssetTrend(
        NetAssetTrendQuery(
          endMonth: MonthKey.fromDate(now),
          months: months,
          currentAsOfExclusive: now,
        ),
      );
}

@riverpod
Stream<TransactionDetail?> transactionDetail(Ref ref, String transactionId) {
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactionDetail(transactionId);
}
