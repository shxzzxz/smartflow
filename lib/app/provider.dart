import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../infrastructure/database/database_provider.dart';
import '../infrastructure/ledger/repository/drift_account_query_repository.dart';
import '../infrastructure/ledger/repository/drift_account_repository.dart';
import '../infrastructure/ledger/repository/drift_balance_aggregate_repository.dart';
import '../infrastructure/ledger/repository/drift_entry_read_repository.dart';
import '../infrastructure/credit/repository/drift_installment_repository.dart';
import '../infrastructure/ledger/repository/drift_posting_repository.dart';
import '../infrastructure/ledger/repository/drift_system_account_resolver.dart';
import '../infrastructure/ledger/repository/drift_transaction_detail_read_repository.dart';
import '../infrastructure/ledger/repository/drift_transaction_read_repository.dart';
import '../infrastructure/database/drift_transaction_runner.dart';
import '../infrastructure/database/drift_update_channel_store.dart';
import '../infrastructure/shared/uuid_id_generator.dart';
import '../application/ledger/ledger_command_api.dart';
import '../application/ledger/ledger_query_api.dart';
import '../application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import '../domain/ledger/port/account_repository.dart';
import '../domain/credit/port/installment_repository.dart';
import '../domain/ledger/port/system_account_resolver.dart';
import '../domain/ledger/service/account/account_role_policy.dart';
import '../domain/ledger/service/posting/account_posting_service.dart';
import '../domain/ledger/service/posting/ledger_posting_service.dart';
import '../domain/ledger/service/posting/posting_engine.dart';
import '../application/shared/transaction_runner.dart';
import '../application/shared/update_channel_store.dart';
import '../core/id/id_generator.dart';
import '../core/time/month_key.dart';
import '../core/money/money.dart';
import '../widget/business/account_lookup.dart';

part 'provider.g.dart';

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) {
  return const UuidIdGenerator();
}

@Riverpod(keepAlive: true)
SystemAccountResolver systemAccountResolver(Ref ref) {
  return DriftSystemAccountResolver(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) {
  return DriftAccountRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
AccountQueryRepository accountQueryRepository(Ref ref) {
  return DriftAccountQueryRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
AccountQueryService accountQueryService(Ref ref) {
  return AccountQueryServiceImpl(
    accounts: ref.watch(accountQueryRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
DriftPostingRepository ledgerRepository(Ref ref) {
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
AccountAppService accountAppService(Ref ref) {
  return AccountAppServiceImpl(
    ref.watch(accountRepositoryProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
    ledgerPostingService: ref.watch(ledgerPostingServiceProvider),
    transactionRepository: ref.watch(ledgerRepositoryProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
}

@Riverpod(keepAlive: true)
CategoryAppService categoryAppService(Ref ref) {
  return CategoryAppServiceImpl(
    repository: ref.watch(accountRepositoryProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
}

@Riverpod(keepAlive: true)
CategoryQueryService categoryQueryService(Ref ref) {
  return CategoryQueryServiceImpl(
    accounts: ref.watch(accountQueryServiceProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionLedgerWriter transactionLedgerWriter(Ref ref) {
  return TransactionLedgerWriter(
    transactionRunner: ref.watch(transactionRunnerProvider),
    transactionRepository: ref.watch(ledgerRepositoryProvider),
    accountRepository: ref.watch(accountRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
LedgerPostingService ledgerPostingService(Ref ref) {
  return LedgerPostingService(
    accountRepository: ref.watch(accountRepositoryProvider),
    systemAccountResolver: ref.watch(systemAccountResolverProvider),
    postingEngine: PostingEngine(idGenerator: ref.watch(idGeneratorProvider)),
    accountPostingService: const DefaultAccountPostingService(),
    accountRolePolicy: AccountRolePolicy(
      accountRepository: ref.watch(accountRepositoryProvider),
    ),
  );
}

@Riverpod(keepAlive: true)
TransactionPostingAppService transactionPostingAppService(Ref ref) {
  return TransactionPostingAppServiceImpl(
    accountRepository: ref.watch(accountRepositoryProvider),
    rootGroupRepository: ref.watch(ledgerRepositoryProvider),
    systemAccountResolver: ref.watch(systemAccountResolverProvider),
    ledgerWriter: ref.watch(transactionLedgerWriterProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    ledgerPostingService: ref.watch(ledgerPostingServiceProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionCorrectionAppService transactionCorrectionAppService(Ref ref) {
  return TransactionCorrectionAppServiceImpl(
    accountRepository: ref.watch(accountRepositoryProvider),
    rootGroupRepository: ref.watch(ledgerRepositoryProvider),
    systemAccountResolver: ref.watch(systemAccountResolverProvider),
    ledgerWriter: ref.watch(transactionLedgerWriterProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionUpdateAppService transactionUpdateAppService(Ref ref) {
  return TransactionUpdateAppServiceImpl(
    transactionRepository: ref.watch(ledgerRepositoryProvider),
    rootGroupRepository: ref.watch(ledgerRepositoryProvider),
    ledgerWriter: ref.watch(transactionLedgerWriterProvider),
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
Stream<List<TransactionListItem>> transactionList(
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

@Riverpod(keepAlive: true)
InstallmentRepository installmentRepository(Ref ref) {
  return DriftInstallmentRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
InstallmentService installmentService(Ref ref) {
  return InstallmentServiceImpl(
    repository: ref.watch(installmentRepositoryProvider),
    postingService: ref.watch(transactionPostingAppServiceProvider),
    correctionService: ref.watch(transactionCorrectionAppServiceProvider),
    updateService: ref.watch(transactionUpdateAppServiceProvider),
    transactionQueryService: ref.watch(transactionQueryServiceProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
  );
}

@Riverpod(keepAlive: true)
CreditService creditService(Ref ref) {
  return CreditServiceImpl(
    installmentService: ref.watch(installmentServiceProvider),
    postingService: ref.watch(transactionPostingAppServiceProvider),
    correctionService: ref.watch(transactionCorrectionAppServiceProvider),
    transactionQueryService: ref.watch(transactionQueryServiceProvider),
    accountQueryService: ref.watch(accountQueryServiceProvider),
  );
}

@riverpod
Future<List<InstallmentContract>> installmentContractsByAccount(
  Ref ref,
  String accountId,
) {
  return ref
      .watch(installmentServiceProvider)
      .listContractsByLiabilityAccount(accountId);
}

@riverpod
Future<InstallmentContract?> installmentContract(Ref ref, String contractId) {
  return ref.watch(installmentServiceProvider).findContract(contractId);
}

@riverpod
Future<List<InstallmentSchedule>> installmentSchedules(
  Ref ref,
  String contractId,
) {
  return ref.watch(installmentServiceProvider).listSchedules(contractId);
}

@riverpod
Future<List<InstallmentRepayment>> installmentRepayments(
  Ref ref,
  String contractId,
) {
  return ref.watch(installmentServiceProvider).listRepayments(contractId);
}

/// 提供 metrics 模块所需的 RepaymentCashflow 列表。
/// 内部读取每张 repayment 关联交易的 details，把本金 / 利息 / 手续费拆出。
@riverpod
Future<List<RepaymentCashflow>> installmentRepaymentCashflows(
  Ref ref,
  String contractId,
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
  String contractId,
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
