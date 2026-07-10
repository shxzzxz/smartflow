import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../infrastructure/database/database_provider.dart';
import '../infrastructure/ledger/repository/drift_account_query_repository.dart';
import '../infrastructure/ledger/repository/drift_account_repository.dart';
import '../infrastructure/ledger/repository/drift_balance_aggregate_repository.dart';
import '../infrastructure/ledger/repository/drift_entry_read_repository.dart';
import '../infrastructure/credit/repository/drift_credit_account_repository.dart';
import '../infrastructure/credit/repository/drift_bill_repository.dart';
import '../infrastructure/credit/repository/drift_credit_bill_source_repository.dart';
import '../infrastructure/credit/repository/drift_installment_repository.dart';
import '../infrastructure/credit/repository/drift_repayment_repository.dart';
import '../infrastructure/credit/adapter/ledger_credit_ledger_port.dart';
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
import 'package:smartflow/application/credit/credit_port_api.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import '../application/shared/app_task.dart';
import '../domain/ledger/port/account_repository.dart';
import '../domain/credit/port/bill_repository.dart';
import '../domain/credit/port/credit_account_repository.dart';
import '../domain/credit/port/credit_bill_source_repository.dart';
import '../domain/credit/port/installment_repository.dart';
import '../domain/credit/port/repayment_repository.dart';
import '../domain/ledger/port/system_account_resolver.dart';
import '../domain/ledger/service/account/account_role_policy.dart';
import '../domain/ledger/service/posting/account_posting_service.dart';
import '../domain/ledger/service/posting/ledger_posting_service.dart';
import '../domain/ledger/service/posting/posting_engine.dart';
import '../application/shared/transaction_runner.dart';
import '../application/shared/update_channel_store.dart';
import '../core/id/id_generator.dart';

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

@Riverpod(keepAlive: true)
CreditAccountRepository creditAccountRepository(Ref ref) {
  return DriftCreditAccountRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
BillRepository billRepository(Ref ref) {
  return DriftBillRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
CreditBillSourceRepository creditBillSourceRepository(Ref ref) {
  return DriftCreditBillSourceRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
CreditAccountAppService creditAccountAppService(Ref ref) {
  return CreditAccountAppServiceImpl(
    accountAppService: ref.watch(accountAppServiceProvider),
    creditAccounts: ref.watch(creditAccountRepositoryProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
}

@Riverpod(keepAlive: true)
CreditAccountQueryService creditAccountQueryService(Ref ref) {
  return CreditAccountQueryServiceImpl(
    creditAccounts: ref.watch(creditAccountRepositoryProvider),
    bills: ref.watch(billRepositoryProvider),
    installments: ref.watch(installmentRepositoryProvider),
    repayments: ref.watch(repaymentRepositoryProvider),
    accountQueryService: ref.watch(accountQueryServiceProvider),
    transactionQueryService: ref.watch(transactionQueryServiceProvider),
  );
}

@Riverpod(keepAlive: true)
InstallmentRepository installmentRepository(Ref ref) {
  return DriftInstallmentRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
RepaymentRepository repaymentRepository(Ref ref) {
  return DriftRepaymentRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
CreditLedgerPort creditLedgerPort(Ref ref) {
  return LedgerCreditLedgerPort(
    accountQueryService: ref.watch(accountQueryServiceProvider),
    postingService: ref.watch(transactionPostingAppServiceProvider),
    correctionService: ref.watch(transactionCorrectionAppServiceProvider),
    updateService: ref.watch(transactionUpdateAppServiceProvider),
    transactionQueryService: ref.watch(transactionQueryServiceProvider),
  );
}

@Riverpod(keepAlive: true)
RepaymentAppService repaymentAppService(Ref ref) {
  return RepaymentAppServiceImpl(
    bills: ref.watch(billRepositoryProvider),
    repayments: ref.watch(repaymentRepositoryProvider),
    installments: ref.watch(installmentRepositoryProvider),
    ledger: ref.watch(creditLedgerPortProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
}

@Riverpod(keepAlive: true)
InstallmentAppService installmentAppService(Ref ref) {
  return InstallmentAppServiceImpl(
    repository: ref.watch(installmentRepositoryProvider),
    bills: ref.watch(billRepositoryProvider),
    creditAccounts: ref.watch(creditAccountRepositoryProvider),
    repayments: ref.watch(repaymentRepositoryProvider),
    ledger: ref.watch(creditLedgerPortProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
}

@Riverpod(keepAlive: true)
InstallmentQueryService installmentQueryService(Ref ref) {
  return InstallmentQueryServiceImpl(
    repository: ref.watch(installmentRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
CreditBillGenerationAppService creditBillGenerationAppService(Ref ref) {
  return CreditBillGenerationAppServiceImpl(
    creditAccounts: ref.watch(creditAccountRepositoryProvider),
    ledger: ref.watch(creditLedgerPortProvider),
    installments: ref.watch(installmentRepositoryProvider),
    repayments: ref.watch(repaymentRepositoryProvider),
    bills: ref.watch(billRepositoryProvider),
    billSources: ref.watch(creditBillSourceRepositoryProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
}

@Riverpod(keepAlive: true)
CreditBillGenerationTask creditBillGenerationTask(Ref ref) {
  return CreditBillGenerationTask(
    ref.watch(creditBillGenerationAppServiceProvider),
  );
}

@Riverpod(keepAlive: true)
PullTaskScheduler pullTaskScheduler(Ref ref) {
  return PullTaskScheduler(
    tasks: [ref.watch(creditBillGenerationTaskProvider)],
  );
}

@Riverpod(keepAlive: true)
BillQueryService billQueryService(Ref ref) {
  return BillQueryServiceImpl(
    bills: ref.watch(billRepositoryProvider),
    creditAccounts: ref.watch(creditAccountRepositoryProvider),
    installments: ref.watch(installmentRepositoryProvider),
    repayments: ref.watch(repaymentRepositoryProvider),
    transactionQueryService: ref.watch(transactionQueryServiceProvider),
  );
}
