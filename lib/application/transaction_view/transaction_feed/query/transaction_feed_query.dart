import '../../../ledger/ledger_query_api.dart';

/// 交易明细视图的应用查询语义。
///
/// 该查询只包含 [TransactionImpactMatch]，结果单位是一笔实际交易。默认
/// 包含父交易和子交易；需要顶层汇总时可显式关闭子交易。实际数据访问继续
/// 复用 [TransactionQueryService]，不复制仓储或 SQL。
final class TransactionFeedQuery {
  TransactionFeedQuery({
    this.match = const TransactionImpactMatch(),
    this.occurredFrom,
    this.occurredUntil,
    this.includeChildTransactions = true,
    this.limit = 50,
    this.offset = 0,
    this.before,
    this.scope = TransactionScopeFilter.assetLiability,
    this.tagIds,
    this.counterpartyId,
    this.untaggedOnly = false,
  }) : assert(limit == null || limit > 0),
       assert(offset >= 0),
       assert(before == null || offset == 0),
       assert(!untaggedOnly || tagIds == null),
       assert(
         occurredFrom == null ||
             occurredUntil == null ||
             occurredUntil.isAfter(occurredFrom),
       );

  final TransactionImpactMatch match;
  final DateTime? occurredFrom;
  final DateTime? occurredUntil;
  final bool includeChildTransactions;
  final int? limit;
  final int offset;
  final TransactionListCursor? before;
  final TransactionScopeFilter scope;
  final Set<String>? tagIds;
  final String? counterpartyId;
  final bool untaggedOnly;

  TransactionListQuery toTransactionListQuery() {
    return TransactionListQuery(
      match: match,
      occurredFrom: occurredFrom,
      occurredUntil: occurredUntil,
      topLevelOnly: !includeChildTransactions,
      limit: limit,
      offset: offset,
      before: before,
      scope: scope,
      tagIds: tagIds,
      counterpartyId: counterpartyId,
      untaggedOnly: untaggedOnly,
    );
  }
}
