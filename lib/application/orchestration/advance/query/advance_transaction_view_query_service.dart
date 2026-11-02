import '../../../../domain/ledger/entity/transaction_group.dart';
import 'advance_transaction_view_read_models.dart';
import 'port/advance_transaction_view_source.dart';

abstract interface class AdvanceTransactionViewQueryService {
  Future<AdvanceTransactionViewAnchorPage> findAnchorPage(
    AdvanceTransactionViewQuery query,
  );

  Stream<AdvanceTransactionViewAnchorPage> watchAnchorPage(
    AdvanceTransactionViewQuery query,
  );

  Future<Map<String, AdvanceTransactionViewSummary>> findSummaries(
    Set<String> ownerIds,
  );

  Stream<AdvanceTransactionViewSummary?> watchSummary(String ownerId);
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

  @override
  Future<Map<String, AdvanceTransactionViewSummary>> findSummaries(
    Set<String> ownerIds,
  ) async {
    final sources = await _source.findSummaries(ownerIds);
    return {
      for (final entry in sources.entries)
        entry.key: AdvanceTransactionViewSummary(
          scenario: entry.value.scenario,
          trackingMode: entry.value.trackingMode,
          advanceAmount: entry.value.advanceAmount,
          receivedAmount: entry.value.receivedAmount,
          outstanding: calculateAdvanceOutstanding(
            advanceAmount: entry.value.advanceAmount,
            refundedAdvanceAmount: entry.value.refundedAdvanceAmount,
            receivedTotal: entry.value.receivedAmount,
            isClosed: entry.value.isClosed,
          ),
          isClosed: entry.value.isClosed,
          aaPeopleCount: entry.value.aaPeopleCount,
        ),
    };
  }

  @override
  Stream<AdvanceTransactionViewSummary?> watchSummary(String ownerId) {
    return _source.watchSummaries({ownerId}).map((sources) {
      final source = sources[ownerId];
      if (source == null) return null;
      return AdvanceTransactionViewSummary(
        scenario: source.scenario,
        trackingMode: source.trackingMode,
        advanceAmount: source.advanceAmount,
        receivedAmount: source.receivedAmount,
        outstanding: calculateAdvanceOutstanding(
          advanceAmount: source.advanceAmount,
          refundedAdvanceAmount: source.refundedAdvanceAmount,
          receivedTotal: source.receivedAmount,
          isClosed: source.isClosed,
        ),
        isClosed: source.isClosed,
        aaPeopleCount: source.aaPeopleCount,
      );
    });
  }
}
