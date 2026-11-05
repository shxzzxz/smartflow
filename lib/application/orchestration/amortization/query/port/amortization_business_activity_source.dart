import '../amortization_business_activity_read_models.dart';

abstract interface class AmortizationBusinessActivitySource {
  Future<AmortizationBusinessActivityAnchorPage> findAnchorPage(
    AmortizationBusinessActivityQuery query,
  );

  Stream<AmortizationBusinessActivityAnchorPage> watchAnchorPage(
    AmortizationBusinessActivityQuery query,
  );
}
