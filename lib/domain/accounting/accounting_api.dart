/// 账务核心（accounting）对外门面。
///
/// - 兄弟业务域只能通过此文件 import accounting 的能力。
/// - 暴露：commands / queries / views / entities / enums / services。
/// - 不暴露：repositories（数据访问接口）、ledger（过账内核）。
library;

export 'commands/account_commands.dart';
export 'commands/category_commands.dart';
export 'commands/transaction_commands.dart';
export 'entities/account.dart';
export 'entities/account_usage.dart';
export 'entities/entry.dart';
export 'entities/transaction.dart';
export 'entities/transaction_detail.dart';
export 'entities/transaction_ownership.dart';
export 'enums/accounting_enums.dart';
export 'queries/financial_metrics_queries.dart';
export 'queries/transaction_queries.dart';
export 'services/account_service.dart';
export 'services/category_service.dart';
export 'services/financial_metrics_service.dart';
export 'services/transaction_query_service.dart';
export 'services/transaction_service.dart';
export 'views/category_views.dart';
export 'views/financial_metrics_views.dart';
export 'views/transaction_views.dart';
