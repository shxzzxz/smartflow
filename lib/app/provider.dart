import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database_provider.dart';
import '../infrastructure/ledger/repository/drift_account_repository.dart';
import '../infrastructure/ledger/repository/drift_balance_aggregate_repository.dart';
import '../infrastructure/ledger/repository/drift_entry_read_repository.dart';
import '../data/credit/repository/drift_installment_repository.dart';
import '../infrastructure/ledger/repository/drift_posting_repository.dart';
import '../infrastructure/ledger/repository/drift_system_account_resolver.dart';
import '../infrastructure/ledger/repository/drift_transaction_detail_read_repository.dart';
import '../infrastructure/ledger/repository/drift_transaction_read_repository.dart';
import '../infrastructure/database/drift_transaction_runner.dart';
import '../infrastructure/database/drift_update_channel_store.dart';
import '../application/ledger/ledger_api.dart';
import 'package:smartflow/application/credit/credit_api.dart';
import '../domain/ledger/port/account_repository.dart';
import '../application/ledger/query/balance_aggregate_repository.dart';
import '../application/ledger/query/entry_read_repository.dart';
import '../domain/credit/repository/installment_repository.dart';
import '../domain/ledger/port/posting_repository.dart';
import '../domain/ledger/port/system_account_resolver.dart';
import '../application/ledger/query/transaction_detail_read_repository.dart';
import '../application/ledger/query/transaction_read_repository.dart';
import '../application/share/transaction_runner.dart';
import '../application/share/update_channel_store.dart';
import '../domain/ledger/ledger/poster.dart';
import '../application/ledger/use_case/receipt_builder.dart';
import '../core/time/month_key.dart';
import '../core/money/money.dart';

part 'provider.g.dart';

@Riverpod(keepAlive: true)
SystemAccountResolver systemAccountResolver(Ref ref) {
  return DriftSystemAccountResolver(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) {
  return DriftAccountRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) {
  return DriftAccountRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
PostingRepository postingRepository(Ref ref) {
  return DriftPostingRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
TransactionReadRepository transactionReadRepository(Ref ref) {
  return DriftTransactionReadRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
EntryReadRepository entryReadRepository(Ref ref) {
  return DriftEntryReadRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
TransactionDetailReadRepository transactionDetailReadRepository(Ref ref) {
  return DriftTransactionDetailReadRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
BalanceAggregateRepository balanceAggregateRepository(Ref ref) {
  return DriftBalanceAggregateRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
TransactionRunner transactionRunner(Ref ref) {
  return DriftTransactionRunner(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
UpdateChannelStore updateChannelStore(Ref ref) {
  return DriftUpdateChannelStore(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
AccountService accountService(Ref ref) {
  return AccountServiceImpl(
    ref.watch(accountRepositoryProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
    transactions: ref.watch(transactionServiceProvider),
  );
}

@Riverpod(keepAlive: true)
CategoryService categoryService(Ref ref) {
  return CategoryServiceImpl(ref.watch(categoryRepositoryProvider));
}

@Riverpod(keepAlive: true)
Poster poster(Ref ref) {
  return PosterImpl(ref.watch(postingRepositoryProvider));
}

@Riverpod(keepAlive: true)
ReceiptBuilder receiptBuilder(Ref ref) {
  return ReceiptBuilder(
    accounts: ref.watch(accountRepositoryProvider),
    query: ref.watch(transactionQueryServiceProvider),
    systemAccounts: ref.watch(systemAccountResolverProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionService transactionService(Ref ref) {
  return TransactionServiceImpl(
    poster: ref.watch(posterProvider),
    receiptBuilder: ref.watch(receiptBuilderProvider),
    transactionQueryService: ref.watch(transactionQueryServiceProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    postingRepository: ref.watch(postingRepositoryProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionQueryService transactionQueryService(Ref ref) {
  return TransactionQueryServiceImpl(
    transactionRead: ref.watch(transactionReadRepositoryProvider),
    entryRead: ref.watch(entryReadRepositoryProvider),
    detailRead: ref.watch(transactionDetailReadRepositoryProvider),
    balanceAggregate: ref.watch(balanceAggregateRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
FinancialMetricsService financialMetricsService(Ref ref) {
  return FinancialMetricsServiceImpl(
    ref.watch(balanceAggregateRepositoryProvider),
  );
}

@riverpod
Stream<List<Account>> accountList(Ref ref) {
  return ref.watch(accountServiceProvider).watchAccounts({
    AccountType.asset,
    AccountType.liability,
  });
}

/// 全量账户索引。覆盖 5 种 account_type,供 UI 层把 entries 的 accountId
/// 解析为 Account 元数据(type / name / iconKey 等)。
///
/// 用法:在 widget 内 `ref.watch(accountsByIdProvider).value ?? const {}`,
/// 配合 `widget/business/account_lookup.dart` 的 extension 使用。
@riverpod
Stream<Map<int, Account>> accountsById(Ref ref) {
  return ref
      .watch(accountServiceProvider)
      .watchAccounts({
        AccountType.asset,
        AccountType.liability,
        AccountType.equity,
        AccountType.income,
        AccountType.expense,
      })
      .map((accounts) => {for (final a in accounts) a.id: a});
}

@riverpod
Stream<List<Account>> accountsForUsage(Ref ref, AccountUsage usage) {
  return ref
      .watch(accountServiceProvider)
      .watchAccounts({AccountType.asset, AccountType.liability})
      .map(
        (accounts) =>
            accounts
                .where((account) => accountMatchesUsage(account, usage))
                .toList(),
      );
}

@riverpod
Stream<List<Account>> accountsByTypes(Ref ref, Set<AccountType> types) {
  return ref.watch(accountServiceProvider).watchAccounts(types);
}

@riverpod
Stream<List<CategoryNode>> categoryTree(Ref ref, AccountType type) {
  return ref.watch(categoryServiceProvider).watchCategoryTree(type);
}

@riverpod
Stream<List<TransactionListItem>> transactionList(Ref ref, {int? accountId}) {
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
Stream<List<TransactionListItem>> homeMonthTransactions(
  Ref ref, {
  required int year,
  required int month,
}) {
  final from = DateTime(year, month);
  final until = DateTime(year, month + 1);
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(
        TransactionListQuery(
          topLevelOnly: true,
          occurredFrom: from,
          occurredUntil: until,
        ),
      );
}

@riverpod
Stream<CashflowComparison> homeMonthCashflowComparison(
  Ref ref, {
  required int year,
  required int month,
}) {
  final now = DateTime.now();
  final selectedMonth = MonthKey(year: year, month: month);
  return ref
      .watch(financialMetricsServiceProvider)
      .watchCashflowComparison(
        CashflowComparisonQuery(
          month: selectedMonth,
          asOfDate:
              now.year == selectedMonth.year && now.month == selectedMonth.month
                  ? now
                  : null,
        ),
      );
}

@riverpod
Stream<List<DailyCashflowSummary>> homeMonthDailyCashflowSummaries(
  Ref ref, {
  required int year,
  required int month,
}) {
  return ref
      .watch(financialMetricsServiceProvider)
      .watchDailyCashflowSummaries(
        DailyCashflowSummaryQuery(month: MonthKey(year: year, month: month)),
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
Stream<TransactionDetail?> transactionDetail(Ref ref, int transactionId) {
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactionDetail(transactionId);
}

@Riverpod(keepAlive: true)
InstallmentRepository installmentRepository(Ref ref) {
  return DriftInstallmentRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
InstallmentService installmentService(Ref ref) {
  return InstallmentServiceImpl(
    repository: ref.watch(installmentRepositoryProvider),
    transactionService: ref.watch(transactionServiceProvider),
    transactionQueryService: ref.watch(transactionQueryServiceProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
  );
}

@Riverpod(keepAlive: true)
CreditService creditService(Ref ref) {
  return CreditServiceImpl(
    installmentService: ref.watch(installmentServiceProvider),
    transactionService: ref.watch(transactionServiceProvider),
    transactionQueryService: ref.watch(transactionQueryServiceProvider),
    accountService: ref.watch(accountServiceProvider),
  );
}

@riverpod
Future<List<InstallmentContract>> installmentContractsByAccount(
  Ref ref,
  int accountId,
) {
  return ref
      .watch(installmentServiceProvider)
      .listContractsByLiabilityAccount(accountId);
}

@riverpod
Future<InstallmentContract?> installmentContract(Ref ref, int contractId) {
  return ref.watch(installmentServiceProvider).findContract(contractId);
}

@riverpod
Future<List<InstallmentSchedule>> installmentSchedules(
  Ref ref,
  int contractId,
) {
  return ref.watch(installmentServiceProvider).listSchedules(contractId);
}

@riverpod
Future<List<InstallmentRepayment>> installmentRepayments(
  Ref ref,
  int contractId,
) {
  return ref.watch(installmentServiceProvider).listRepayments(contractId);
}

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 内部读取每张 repayment 关联交易的 details，把本金 / 利息 / 手续费拆出。
@riverpod
Future<List<RepaymentCashflow>> installmentRepaymentCashflows(
  Ref ref,
  int contractId,
) async {
  final repayments = await ref.watch(
    installmentRepaymentsProvider(contractId).future,
  );
  final queryService = ref.watch(transactionQueryServiceProvider);
  final result = <RepaymentCashflow>[];
  for (final r in repayments) {
    final view = await queryService.findTransactionDetail(r.transactionId);
    if (view == null) continue;
    var principalMinor = 0;
    var interestMinor = 0;
    var feeMinor = 0;
    for (final d in view.details) {
      switch (d.type) {
        case TransactionDetailType.repaymentPrincipal:
          principalMinor += d.amount.minorUnits;
        case TransactionDetailType.repaymentInterest:
          interestMinor += d.amount.minorUnits;
        case TransactionDetailType.repaymentFee:
          feeMinor += d.amount.minorUnits;
        case TransactionDetailType.repaymentDiscount:
          // 折扣抵减本金对外现金流（折扣不计入支出），可视为本金减项。
          principalMinor -= d.amount.minorUnits;
        default:
          break;
      }
    }
    result.add(
      RepaymentCashflow(
        id: r.id,
        transactionId: r.transactionId,
        repaymentType: r.repaymentType,
        scheduleId: r.scheduleId,
        occurredAt: view.transaction.occurredAt,
        principal: Money(minorUnits: principalMinor),
        interest: Money(minorUnits: interestMinor),
        fee: Money(minorUnits: feeMinor),
      ),
    );
  }
  return result;
}

/// 计算 designed / actual 两个视图的 metrics 一并返回，UI 选择展示。
@riverpod
Future<({ContractMetrics designed, ContractMetrics actual})> installmentMetrics(
  Ref ref,
  int contractId,
) async {
  final contract = await ref.watch(
    installmentContractProvider(contractId).future,
  );
  final schedules = await ref.watch(
    installmentSchedulesProvider(contractId).future,
  );
  final repayments = await ref.watch(
    installmentRepaymentCashflowsProvider(contractId).future,
  );
  if (contract == null) {
    throw StateError('Contract $contractId not found');
  }
  const calc = InstallmentMetricsCalculator();
  return (
    designed: calc.compute(
      contract: contract,
      schedules: schedules,
      repayments: repayments,
    ),
    actual: calc.compute(
      contract: contract,
      schedules: schedules,
      repayments: repayments,
      view: ContractMetricsView.actual,
    ),
  );
}
