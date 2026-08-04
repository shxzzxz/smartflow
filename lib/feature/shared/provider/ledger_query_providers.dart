import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import '../../../shared/account_profile/account_selection_policy.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'current_date_time_provider.dart';

part 'ledger_query_providers.g.dart';

// 全局小列表 provider（全 app 高频消费、体量小、参数为有限枚举）统一 keepAlive，
// 消除「autodispose provider 在回调 read(.future) 期间被回收」一类时序问题;
// 按 id / 分页参数展开或依赖 currentDateTime 的仍保持 autodispose。
@Riverpod(keepAlive: true)
Stream<List<Account>> accountList(Ref ref) {
  return ref.watch(accountQueryServiceProvider).watchAccounts({
    AccountType.asset,
    AccountType.liability,
  });
}

@Riverpod(keepAlive: true)
Stream<List<AccountGroup>> accountGroups(Ref ref) {
  return ref.watch(accountGroupQueryServiceProvider).watchGroups();
}

@Riverpod(keepAlive: true)
Stream<Map<String, CreditLiabilityAccountReadModel>>
creditLiabilityAccountsByAccountId(Ref ref) {
  return ref
      .watch(creditAccountQueryServiceProvider)
      .watchCreditLiabilityAccountsByAccountId();
}

/// 全量账户索引。覆盖 5 种 account_type,供 UI 层把 entries 的 accountId
/// 解析为 Account 元数据(type / name / iconKey 等)。
///
/// 新 UI 优先使用 `accountLookupProvider`; 仍保留 Map 形式给表单解析等旧路径使用。
@Riverpod(keepAlive: true)
Stream<Map<String, Account>> accountsById(Ref ref) {
  return ref.watch(accountQueryServiceProvider).watchAccountsById();
}

@Riverpod(keepAlive: true)
Stream<AccountLookup> accountLookup(Ref ref) {
  return ref
      .watch(accountQueryServiceProvider)
      .watchAccountsById()
      .map(AccountLookup.new);
}

@Riverpod(keepAlive: true)
Stream<List<Account>> accountsForSelectionPurpose(
  Ref ref,
  AccountSelectionPurpose purpose,
) {
  return ref
      .watch(accountQueryServiceProvider)
      .watchAccounts({AccountType.asset, AccountType.liability})
      .map((accounts) {
        return accounts
            .where(
              (account) => accountMatchesSelectionPurpose(account, purpose),
            )
            .toList();
      });
}

@riverpod
Stream<List<Account>> accountsByTypes(Ref ref, Set<AccountType> types) {
  return ref.watch(accountQueryServiceProvider).watchAccounts(types);
}

@Riverpod(keepAlive: true)
Stream<List<CategoryNode>> categoryTree(Ref ref, AccountType type) {
  return ref.watch(categoryQueryServiceProvider).watchCategoryTree(type);
}

@riverpod
Stream<List<TransactionListReadModel>> transactionList(
  Ref ref, {
  String? settlementAccountId,
  int limit = 50,
  int offset = 0,
}) {
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(
        TransactionListQuery(
          settlementAccountIds:
              settlementAccountId == null ? null : {settlementAccountId},
          topLevelOnly: settlementAccountId == null,
          limit: limit,
          offset: offset,
        ),
      );
}

@riverpod
Stream<BalanceSheetComparison> balanceSheetComparison(Ref ref) {
  final now = ref.watch(currentDateTimeProvider);
  final todayEndExclusive = DateTime(now.year, now.month, now.day + 1);
  return ref
      .watch(financialMetricsServiceProvider)
      .watchBalanceSheetComparison(
        BalanceSheetComparisonQuery(
          month: MonthKey.fromDate(now),
          asOfExclusive: todayEndExclusive,
        ),
      );
}

@riverpod
Stream<List<NetAssetTrendPoint>> netAssetTrend(Ref ref, {int months = 6}) {
  final now = ref.watch(currentDateTimeProvider);
  final todayEndExclusive = DateTime(now.year, now.month, now.day + 1);
  return ref
      .watch(financialMetricsServiceProvider)
      .watchNetAssetTrend(
        NetAssetTrendQuery(
          endMonth: MonthKey.fromDate(now),
          months: months,
          currentAsOfExclusive: todayEndExclusive,
        ),
      );
}

@riverpod
Stream<TransactionDetail?> transactionDetail(Ref ref, String transactionId) {
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactionDetail(transactionId);
}
