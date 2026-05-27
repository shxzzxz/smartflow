/// 账务应用层对外门面。
///
/// UI 和兄弟业务域通过 application facade 使用账务能力；domain 内部端口与
/// ledger 过账内核不从这里导出。
library;

export 'command/account_command.dart';
export 'command/category_command.dart';
export 'command/transaction_command.dart';
export '../../domain/ledger/entity/account.dart';
export '../../domain/ledger/valobj/account_usage.dart';
export '../../domain/ledger/entity/entry.dart';
export '../../domain/ledger/entity/transaction.dart';
export '../../domain/ledger/entity/transaction_detail_record.dart';
export '../../domain/ledger/valobj/transaction_fact.dart';
export '../../domain/ledger/valobj/transaction_ownership.dart';
export '../../domain/ledger/valobj/ledger_enum.dart';
export 'query/financial_metrics_queries.dart';
export 'query/account_query_repository.dart';
export 'query/transaction_queries.dart';
export 'query/transaction_scope.dart';
export 'read_model/category_read_models.dart';
export 'read_model/financial_metrics_read_models.dart';
export 'read_model/transaction_read_models.dart';
export 'query/financial_metrics_service.dart';
export 'query/transaction_query_service.dart';
export 'use_case/account_app_service.dart';
export 'use_case/category_service.dart';
export 'use_case/posting_app_service.dart';
