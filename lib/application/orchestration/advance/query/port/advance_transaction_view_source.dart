import '../advance_transaction_view_read_models.dart';

abstract interface class AdvanceTransactionViewSource {
  Future<AdvanceTransactionViewAnchorPage> findAnchorPage(
    AdvanceTransactionViewQuery query,
  );

  Stream<AdvanceTransactionViewAnchorPage> watchAnchorPage(
    AdvanceTransactionViewQuery query,
  );
}
