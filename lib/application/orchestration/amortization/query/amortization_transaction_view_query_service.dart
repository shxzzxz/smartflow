import 'amortization_transaction_view_read_models.dart';
import 'port/amortization_transaction_view_source.dart';

abstract interface class AmortizationTransactionViewQueryService {
  Future<AmortizationTransactionViewAnchorPage> findAnchorPage(
    AmortizationTransactionViewQuery query,
  );

  Stream<AmortizationTransactionViewAnchorPage> watchAnchorPage(
    AmortizationTransactionViewQuery query,
  );
}

final class AmortizationTransactionViewQueryServiceImpl
    implements AmortizationTransactionViewQueryService {
  const AmortizationTransactionViewQueryServiceImpl(this._source);

  final AmortizationTransactionViewSource _source;

  @override
  Future<AmortizationTransactionViewAnchorPage> findAnchorPage(
    AmortizationTransactionViewQuery query,
  ) => _source.findAnchorPage(query);

  @override
  Stream<AmortizationTransactionViewAnchorPage> watchAnchorPage(
    AmortizationTransactionViewQuery query,
  ) => _source.watchAnchorPage(query);
}
