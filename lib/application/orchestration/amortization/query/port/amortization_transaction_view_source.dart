import '../amortization_transaction_view_read_models.dart';

abstract interface class AmortizationTransactionViewSource {
  Future<AmortizationTransactionViewAnchorPage> findAnchorPage(
    AmortizationTransactionViewQuery query,
  );

  Stream<AmortizationTransactionViewAnchorPage> watchAnchorPage(
    AmortizationTransactionViewQuery query,
  );
}
