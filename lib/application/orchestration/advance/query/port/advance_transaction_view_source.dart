import '../advance_transaction_view_read_models.dart';

abstract interface class AdvanceTransactionViewSource {
  Future<AdvanceTransactionViewAnchorPage> findAnchorPage(
    AdvanceTransactionViewQuery query,
  );

  Stream<AdvanceTransactionViewAnchorPage> watchAnchorPage(
    AdvanceTransactionViewQuery query,
  );

  Future<Map<String, AdvanceTransactionViewSummarySource>> findSummaries(
    Set<String> ownerIds,
  );

  Stream<Map<String, AdvanceTransactionViewSummarySource>> watchSummaries(
    Set<String> ownerIds,
  );
}
