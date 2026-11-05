import '../advance_business_activity_read_models.dart';

abstract interface class AdvanceBusinessActivitySource {
  Future<AdvanceBusinessActivityAnchorPage> findAnchorPage(
    AdvanceBusinessActivityQuery query,
  );

  Stream<AdvanceBusinessActivityAnchorPage> watchAnchorPage(
    AdvanceBusinessActivityQuery query,
  );
}
