import 'amortization_business_activity_read_models.dart';
import 'port/amortization_business_activity_source.dart';

abstract interface class AmortizationBusinessActivityQueryService {
  Future<AmortizationBusinessActivityAnchorPage> findAnchorPage(
    AmortizationBusinessActivityQuery query,
  );

  Stream<AmortizationBusinessActivityAnchorPage> watchAnchorPage(
    AmortizationBusinessActivityQuery query,
  );
}

final class AmortizationBusinessActivityQueryServiceImpl
    implements AmortizationBusinessActivityQueryService {
  const AmortizationBusinessActivityQueryServiceImpl(this._source);

  final AmortizationBusinessActivitySource _source;

  @override
  Future<AmortizationBusinessActivityAnchorPage> findAnchorPage(
    AmortizationBusinessActivityQuery query,
  ) => _source.findAnchorPage(query);

  @override
  Stream<AmortizationBusinessActivityAnchorPage> watchAnchorPage(
    AmortizationBusinessActivityQuery query,
  ) => _source.watchAnchorPage(query);
}
