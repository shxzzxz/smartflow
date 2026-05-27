import 'package:smartflow/domain/ledger/entity/entry.dart';

/// entries 表的纯读能力。
abstract interface class EntryReadRepository {
  /// 按 transactionId 集合取关联 entries。返回 `Map<transactionId, entries>`。
  Future<Map<String, List<Entry>>> findByTransactionIds(
    Set<String> transactionIds,
  );
}
