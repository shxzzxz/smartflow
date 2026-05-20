import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database_provider.dart';
import '../data/accounting/repositories/drift_account_repository.dart';
import '../data/accounting/repositories/drift_financial_metrics_repository.dart';
import '../data/credit/repositories/drift_installment_repository.dart';
import '../data/accounting/repositories/drift_posting_repository.dart';
import '../data/accounting/repositories/drift_system_account_resolver.dart';
import '../data/accounting/repositories/drift_transaction_query_repository.dart';
import '../domain/accounting/entities/account_usage.dart';
import '../domain/accounting/entities/account.dart';
import '../domain/credit/entities/installment_contract.dart';
import '../domain/credit/entities/installment_repayment.dart';
import '../domain/credit/entities/installment_schedule.dart';
import '../domain/accounting/enums/accounting_enums.dart';
import '../domain/accounting/repositories/account_repository.dart';
import '../domain/accounting/repositories/financial_metrics_repository.dart';
import '../domain/credit/repositories/installment_repository.dart';
import '../domain/accounting/repositories/posting_repository.dart';
import '../domain/accounting/repositories/system_account_resolver.dart';
import '../domain/accounting/repositories/transaction_query_repository.dart';
import '../domain/accounting/services/account_service.dart';
import '../domain/accounting/services/category_service.dart';
import '../domain/accounting/services/financial_metrics_service.dart';
import '../domain/credit/services/credit_service.dart';
import '../domain/credit/services/installment_metrics.dart';
import '../domain/credit/services/installment_service.dart';
import '../domain/accounting/services/posting_service.dart';
import '../domain/accounting/services/transaction_query_service.dart';
import '../domain/accounting/services/transaction_service.dart';
import '../core/time/month_key.dart';
import '../core/money/money.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SystemAccountResolver systemAccountResolver(Ref ref) {
  return DriftSystemAccountResolver(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) {
  return DriftAccountRepository(
    ref.watch(appDatabaseProvider),
    systemAccounts: ref.watch(systemAccountResolverProvider),
  );
}

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) {
  return DriftAccountRepository(
    ref.watch(appDatabaseProvider),
    systemAccounts: ref.watch(systemAccountResolverProvider),
  );
}

@Riverpod(keepAlive: true)
PostingRepository postingRepository(Ref ref) {
  return DriftPostingRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
TransactionQueryRepository transactionQueryRepository(Ref ref) {
  return DriftTransactionQueryRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
FinancialMetricsRepository financialMetricsRepository(Ref ref) {
  return DriftFinancialMetricsRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
AccountService accountService(Ref ref) {
  return AccountServiceImpl(ref.watch(accountRepositoryProvider));
}

@Riverpod(keepAlive: true)
CategoryService categoryService(Ref ref) {
  return CategoryServiceImpl(ref.watch(categoryRepositoryProvider));
}

@Riverpod(keepAlive: true)
PostingService postingService(Ref ref) {
  return PostingServiceImpl(ref.watch(postingRepositoryProvider));
}

@Riverpod(keepAlive: true)
TransactionService transactionService(Ref ref) {
  return TransactionServiceImpl(
    ref.watch(postingServiceProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
    transactionQueryRepository: ref.watch(transactionQueryRepositoryProvider),
    systemAccountResolver: ref.watch(systemAccountResolverProvider),
    postingRepository: ref.watch(postingRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionQueryService transactionQueryService(Ref ref) {
  return TransactionQueryServiceImpl(
    ref.watch(transactionQueryRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
FinancialMetricsService financialMetricsService(Ref ref) {
  return FinancialMetricsServiceImpl(
    ref.watch(financialMetricsRepositoryProvider),
  );
}

@riverpod
Stream<List<Account>> accountList(Ref ref) {
  return ref.watch(accountServiceProvider).watchAccounts();
}

@riverpod
Stream<List<Account>> accountsForUsage(Ref ref, AccountUsage usage) {
  return ref
      .watch(accountServiceProvider)
      .watchAccounts()
      .map(
        (accounts) =>
            accounts
                .where((account) => accountMatchesUsage(account, usage))
                .toList(),
      );
}

@riverpod
Stream<List<Account>> accountsByTypes(Ref ref, Set<AccountType> types) {
  return ref.watch(accountRepositoryProvider).watchAccounts(types);
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
Stream<TransactionDetailView?> transactionDetail(Ref ref, int transactionId) {
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
    postingRepository: ref.watch(postingRepositoryProvider),
    transactionService: ref.watch(transactionServiceProvider),
    queryRepository: ref.watch(transactionQueryRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
CreditService creditService(Ref ref) {
  return CreditServiceImpl(
    installmentService: ref.watch(installmentServiceProvider),
    transactionService: ref.watch(transactionServiceProvider),
    transactionQueryService: ref.watch(transactionQueryServiceProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
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
  final queryRepository = ref.watch(transactionQueryRepositoryProvider);
  final result = <RepaymentCashflow>[];
  for (final r in repayments) {
    final view =
        await queryRepository.watchTransactionDetail(r.transactionId).first;
    if (view == null) continue;
    final currency = view.transaction.currencyCode;
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
        principal: Money(minorUnits: principalMinor, currency: currency),
        interest: Money(minorUnits: interestMinor, currency: currency),
        fee: Money(minorUnits: feeMinor, currency: currency),
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
