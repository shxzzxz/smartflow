import 'advance_business_activity_read_models.dart';
import 'port/advance_business_activity_source.dart';

abstract interface class AdvanceBusinessActivityQueryService {
  Future<AdvanceBusinessActivityAnchorPage> findAnchorPage(
    AdvanceBusinessActivityQuery query,
  );

  Stream<AdvanceBusinessActivityAnchorPage> watchAnchorPage(
    AdvanceBusinessActivityQuery query,
  );
}

final class AdvanceBusinessActivityQueryServiceImpl
    implements AdvanceBusinessActivityQueryService {
  const AdvanceBusinessActivityQueryServiceImpl(this._source);

  final AdvanceBusinessActivitySource _source;

  @override
  Future<AdvanceBusinessActivityAnchorPage> findAnchorPage(
    AdvanceBusinessActivityQuery query,
  ) => _source.findAnchorPage(query);

  @override
  Stream<AdvanceBusinessActivityAnchorPage> watchAnchorPage(
    AdvanceBusinessActivityQuery query,
  ) => _source.watchAnchorPage(query);
}
