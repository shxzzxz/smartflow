/// 账务读侧 application API。
///
/// UI 和兄弟业务域通过这里调用查询用例并消费 read model；读侧 port 由
/// `ledger_query_port_api.dart` 单独导出给 infrastructure / 装配层。
library;

export '../../domain/ledger/entity/account.dart';
export '../../domain/ledger/entity/entry.dart';
export '../../domain/ledger/entity/transaction.dart';
export '../../domain/ledger/entity/transaction_detail_record.dart';
export '../../domain/ledger/valobj/account_usage.dart';
export '../../domain/ledger/valobj/ledger_enum.dart';
export '../../domain/ledger/valobj/transaction_ownership.dart';
export 'account/query/account_query_service.dart';
export 'category/query/category_query_service.dart';
export 'category/query/category_read_models.dart';
export 'metrics/query/financial_metrics_queries.dart';
export 'metrics/query/financial_metrics_read_models.dart';
export 'metrics/query/financial_metrics_service.dart';
export 'transaction/query/transaction_queries.dart';
export 'transaction/query/transaction_query_service.dart';
export 'transaction/query/transaction_read_models.dart';
export 'transaction/query/transaction_scope.dart';
