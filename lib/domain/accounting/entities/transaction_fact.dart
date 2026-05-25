import 'entry.dart';
import 'transaction.dart';
import 'transaction_detail_record.dart';

/// 写路径所需的单笔账务事实。
///
/// 只包含 Transaction 聚合事实，不包含 UI 详情页的 children/history/projection。
class TransactionFact {
  const TransactionFact({
    required this.transaction,
    required this.details,
    required this.entries,
  });

  final Transaction transaction;
  final List<TransactionDetailRecord> details;
  final List<Entry> entries;
}
