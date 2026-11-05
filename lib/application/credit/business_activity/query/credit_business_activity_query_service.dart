import '../../installment/query/port/installment_statistics_change_source.dart';
import 'credit_business_activity_read_models.dart';
import 'port/credit_business_activity_source.dart';

/// Credit-domain query used by the cross-domain transaction view.
abstract interface class CreditBusinessActivityQueryService {
  Future<CreditBusinessActivityAnchorPage> findAnchorPage(
    CreditBusinessActivityQuery query,
  );

  Stream<CreditBusinessActivityAnchorPage> watchAnchorPage(
    CreditBusinessActivityQuery query,
  );

  Future<Map<String, CreditRepaymentBusinessActivitySummary>>
  findRepaymentSummaries(Set<String> repaymentIds);

  Stream<CreditRepaymentBusinessActivitySummary?> watchRepaymentSummary(
    String repaymentId,
  );
}

final class CreditBusinessActivityQueryServiceImpl
    implements CreditBusinessActivityQueryService {
  CreditBusinessActivityQueryServiceImpl({
    required CreditBusinessActivitySource source,
    required InstallmentStatisticsChangeSource changes,
  }) : _source = source,
       _changes = changes;

  final CreditBusinessActivitySource _source;
  final InstallmentStatisticsChangeSource _changes;

  @override
  Future<CreditBusinessActivityAnchorPage> findAnchorPage(
    CreditBusinessActivityQuery query,
  ) => _source.findAnchorPage(query);

  @override
  Stream<CreditBusinessActivityAnchorPage> watchAnchorPage(
    CreditBusinessActivityQuery query,
  ) => _source.watchAnchorPage(query);

  @override
  Future<Map<String, CreditRepaymentBusinessActivitySummary>>
  findRepaymentSummaries(Set<String> repaymentIds) {
    return _source.findRepaymentSummaries(repaymentIds);
  }

  @override
  Stream<CreditRepaymentBusinessActivitySummary?> watchRepaymentSummary(
    String repaymentId,
  ) {
    return _changes.watchChanges().asyncMap((_) async {
      final summaries = await findRepaymentSummaries({repaymentId});
      return summaries[repaymentId];
    });
  }
}
