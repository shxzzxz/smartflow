/// 账务应用层对外门面。
///
/// UI 和兄弟业务域通过 application facade 使用账务能力；domain 内部端口与
/// ledger 过账内核不从这里导出。
library;

export 'commands/account_commands.dart';
export 'commands/category_commands.dart';
export 'commands/transaction_commands.dart';
export '../../domain/accounting/entities/account.dart';
export '../../domain/accounting/entities/account_usage.dart';
export '../../domain/accounting/entities/entry.dart';
export '../../domain/accounting/entities/transaction.dart';
export '../../domain/accounting/entities/transaction_detail_record.dart';
export '../../domain/accounting/entities/transaction_fact.dart';
export '../../domain/accounting/entities/transaction_ownership.dart';
export '../../domain/accounting/enums/accounting_enums.dart';
export 'queries/financial_metrics_queries.dart';
export 'queries/transaction_queries.dart';
export 'queries/transaction_scope.dart';
export 'read_models/category_read_models.dart';
export 'read_models/financial_metrics_read_models.dart';
export 'read_models/transaction_read_models.dart';
export 'queries/financial_metrics_service.dart';
export 'queries/transaction_query_service.dart';
export 'use_cases/account_service.dart';
export 'use_cases/category_service.dart';
export 'use_cases/transaction_service.dart';
