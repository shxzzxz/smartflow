import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/logging/app_log_file_sink.dart';
import '../core/logging/app_log_reader.dart';
import '../infrastructure/database/database_provider.dart';
import '../infrastructure/import/ledger_import_port.dart';
import '../infrastructure/import/platform_import_file_picker.dart';
import '../infrastructure/import/repository/drift_import_batch_repository.dart';
import '../infrastructure/import/repository/drift_import_mapping_repository.dart';
import '../infrastructure/import/yimu_excel2003_workbook_reader.dart';
import '../infrastructure/ledger/repository/drift_account_query_repository.dart';
import '../infrastructure/ledger/repository/drift_account_repository.dart';
import '../infrastructure/ledger/repository/drift_ledger_metrics_source.dart';
import '../infrastructure/ledger/repository/drift_entry_read_repository.dart';
import '../infrastructure/credit/repository/drift_credit_account_repository.dart';
import '../infrastructure/credit/repository/drift_bill_repository.dart';
import '../infrastructure/credit/repository/drift_credit_bill_source_repository.dart';
import '../infrastructure/credit/repository/drift_installment_repository.dart';
import '../infrastructure/credit/repository/drift_repayment_repository.dart';
import '../infrastructure/credit/adapter/ledger_credit_ledger_port.dart';
import '../infrastructure/credit/adapter/ledger_credit_account_port.dart';
import '../infrastructure/ledger/repository/drift_posting_repository.dart';
import '../infrastructure/ledger/repository/drift_system_account_resolver.dart';
import '../infrastructure/ledger/repository/drift_transaction_detail_read_repository.dart';
import '../infrastructure/ledger/repository/drift_transaction_read_repository.dart';
import '../infrastructure/database/drift_app_settings_store.dart';
import '../infrastructure/database/drift_transaction_runner.dart';
import '../infrastructure/database/drift_update_channel_store.dart';
import '../infrastructure/shared/uuid_id_generator.dart';
import '../application/ledger/ledger_command_api.dart';
import '../application/ledger/ledger_query_api.dart';
import '../application/ledger/ledger_query_port_api.dart';
import '../application/import/import_plan_app_service.dart';
import '../application/import/import_parser_registry.dart';
import '../application/import/import_file_picker.dart';
import '../application/import/import_workflow_app_service.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import '../application/shared/app_task.dart';
import '../domain/ledger/port/account_repository.dart';
import '../domain/import/port/import_batch_repository.dart';
import '../domain/import/port/import_ledger_port.dart';
import '../domain/import/port/import_mapping_repository.dart';
import '../domain/import/port/yimu_workbook_reader.dart';
import '../domain/import/service/yimu_import_parser.dart';
import '../domain/credit/port/bill_repository.dart';
import '../domain/credit/port/credit_account_repository.dart';
import '../domain/credit/port/credit_bill_source_repository.dart';
import '../domain/credit/port/installment_repository.dart';
import '../domain/credit/port/repayment_repository.dart';
import '../domain/credit/port/credit_ledger_port.dart';
import '../domain/ledger/port/system_account_resolver.dart';
import '../domain/ledger/service/account/account_role_policy.dart';
import '../domain/ledger/service/posting/account_posting_service.dart';
import '../domain/ledger/service/posting/ledger_posting_service.dart';
import '../domain/ledger/service/posting/posting_engine.dart';
import '../application/shared/app_settings_store.dart';
import '../application/shared/transaction_runner.dart';
import '../application/shared/update_channel_store.dart';
import '../core/id/id_generator.dart';

part 'provider.g.dart';

/// 由 main() 用 bootstrap 创建的实例 override。
@Riverpod(keepAlive: true)
AppLogFileSink appLogFileSink(Ref ref) {
  throw UnimplementedError('appLogFileSink 必须在 ProviderScope 中 override。');
}

@Riverpod(keepAlive: true)
AppLogReader appLogReader(Ref ref) {
  return AppLogReader(directory: ref.watch(appLogFileSinkProvider).directory);
}

@Riverpod(keepAlive: true)
ImportFilePicker importFilePicker(Ref ref) {
  return const PlatformImportFilePicker();
}

@Riverpod(keepAlive: true)
YimuWorkbookReader yimuWorkbookReader(Ref ref) {
  return const YimuExcel2003WorkbookReader();
}

@Riverpod(keepAlive: true)
YimuImportParser yimuImportParser(Ref ref) {
  return YimuImportParser(reader: ref.watch(yimuWorkbookReaderProvider));
}

@Riverpod(keepAlive: true)
ImportPlanAppService importPlanAppService(Ref ref) {
  return ImportPlanAppServiceImpl(
    parsers: ImportParserRegistry([ref.watch(yimuImportParserProvider)]),
  );
}

@Riverpod(keepAlive: true)
ImportMappingRepository importMappingRepository(Ref ref) {
  return DriftImportMappingRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
ImportBatchRepository importBatchRepository(Ref ref) {
  return DriftImportBatchRepository(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
ImportLedgerPort importLedgerPort(Ref ref) {
  return LedgerImportPort(
    posting: ref.watch(transactionPostingAppServiceProvider),
    editing: ref.watch(transactionEditAppServiceProvider),
    transactions: ref.watch(transactionQueryServiceProvider),
    accounts: ref.watch(accountQueryServiceProvider),
    accountCommands: ref.watch(accountAppServiceProvider),
    categoryCommands: ref.watch(categoryAppServiceProvider),
    systemAccounts: ref.watch(systemAccountResolverProvider),
    creditAccounts: ref.watch(creditAccountAppServiceProvider),
  );
}

@Riverpod(keepAlive: true)
ImportWorkflowAppService importWorkflowAppService(Ref ref) {
  return ImportWorkflowAppServiceImpl(
    mappings: ref.watch(importMappingRepositoryProvider),
    batches: ref.watch(importBatchRepositoryProvider),
    ledger: ref.watch(importLedgerPortProvider),
    transactionRunner: ref.watch(transactionRunnerProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
}

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
LedgerMetricsSource ledgerMetricsSource(Ref ref) {
  return DriftLedgerMetricsSource(ref.watch(appDatabaseProvider));
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
AppSettingsStore appSettingsStore(Ref ref) {
  return DriftAppSettingsStore(ref.watch(appDatabaseProvider));
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
    transactionGroupRepository: ref.watch(ledgerRepositoryProvider),
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
    transactionGroupRepository: ref.watch(ledgerRepositoryProvider),
    systemAccountResolver: ref.watch(systemAccountResolverProvider),
    ledgerWriter: ref.watch(transactionLedgerWriterProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    ledgerPostingService: ref.watch(ledgerPostingServiceProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionEditAppService transactionEditAppService(Ref ref) {
  return TransactionEditAppServiceImpl(
    accountRepository: ref.watch(accountRepositoryProvider),
    transactionGroupRepository: ref.watch(ledgerRepositoryProvider),
    systemAccountResolver: ref.watch(systemAccountResolverProvider),
    ledgerWriter: ref.watch(transactionLedgerWriterProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionUpdateAppService transactionUpdateAppService(Ref ref) {
  return TransactionUpdateAppServiceImpl(
    transactionRepository: ref.watch(ledgerRepositoryProvider),
    transactionGroupRepository: ref.watch(ledgerRepositoryProvider),
    ledgerWriter: ref.watch(transactionLedgerWriterProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionCleanupAppService transactionCleanupAppService(Ref ref) {
  return TransactionCleanupAppServiceImpl(
    transactionRunner: ref.watch(transactionRunnerProvider),
    transactionReadRepository: ref.watch(transactionReadRepositoryProvider),
    editService: ref.watch(transactionEditAppServiceProvider),
  );
}

@Riverpod(keepAlive: true)
TransactionQueryService transactionQueryService(Ref ref) {
  return TransactionQueryServiceImpl(
    transactionRead: ref.watch(transactionReadRepositoryProvider),
    entryRead: ref.watch(entryReadRepositoryProvider),
    detailRead: ref.watch(transactionDetailReadRepositoryProvider),
    metricsSource: ref.watch(ledgerMetricsSourceProvider),
  );
}

@Riverpod(keepAlive: true)
FinancialMetricsService financialMetricsService(Ref ref) {
  return FinancialMetricsServiceImpl(ref.watch(ledgerMetricsSourceProvider));
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
    ledger: ref.watch(creditAccountLedgerPortProvider),
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
    ledger: ref.watch(creditLedgerPortProvider),
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
CreditAccountLedgerPort creditAccountLedgerPort(Ref ref) {
  return LedgerCreditAccountPort(ref.watch(accountAppServiceProvider));
}

@Riverpod(keepAlive: true)
CreditLedgerPort creditLedgerPort(Ref ref) {
  return LedgerCreditLedgerPort(
    accountQueryService: ref.watch(accountQueryServiceProvider),
    postingService: ref.watch(transactionPostingAppServiceProvider),
    editService: ref.watch(transactionEditAppServiceProvider),
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
ContractMetricsQuery contractMetricsQuery(Ref ref) {
  return ContractMetricsQueryImpl(
    installments: ref.watch(installmentRepositoryProvider),
  );
}

@Riverpod(keepAlive: true)
ContractRepaymentQuery contractRepaymentQuery(Ref ref) {
  return ContractRepaymentQueryImpl(
    repayments: ref.watch(repaymentRepositoryProvider),
    ledger: ref.watch(creditLedgerPortProvider),
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
    ledger: ref.watch(creditLedgerPortProvider),
  );
}
