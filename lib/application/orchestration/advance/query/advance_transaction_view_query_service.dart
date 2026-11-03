import 'advance_transaction_view_read_models.dart';
import 'port/advance_transaction_view_source.dart';

abstract interface class AdvanceTransactionViewQueryService {
  Future<AdvanceTransactionViewAnchorPage> findAnchorPage(
    AdvanceTransactionViewQuery query,
  );

  Stream<AdvanceTransactionViewAnchorPage> watchAnchorPage(
    AdvanceTransactionViewQuery query,
  );
}

final class AdvanceTransactionViewQueryServiceImpl
    implements AdvanceTransactionViewQueryService {
  const AdvanceTransactionViewQueryServiceImpl(this._source);

  final AdvanceTransactionViewSource _source;

  @override
  Future<AdvanceTransactionViewAnchorPage> findAnchorPage(
    AdvanceTransactionViewQuery query,
  ) => _source.findAnchorPage(query);

  @override
  Stream<AdvanceTransactionViewAnchorPage> watchAnchorPage(
    AdvanceTransactionViewQuery query,
  ) => _source.watchAnchorPage(query);
}
