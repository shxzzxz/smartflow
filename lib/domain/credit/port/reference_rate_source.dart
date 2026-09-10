import '../../../core/collection/ordered.dart';
import '../valobj/reference_rate.dart';

abstract interface class ReferenceRateSource implements Ordered {
  /// Stable unique source key, also stored with its reference rate records.
  String get key;
  Set<ReferenceRateType> get supportedTypes;

  /// Fetches all requested types over the same inclusive date range.
  /// Each returned entry contains the complete history for that type in the
  /// range, including every page/segment. An empty entry means no history;
  /// an omitted type means it could not be parsed completely. Transport or
  /// shared response errors fail the call. Never return a partial type history.
  Future<Map<ReferenceRateType, List<ReferenceRate>>> fetch(
    List<ReferenceRateType> types, {
    required DateTime from,
    required DateTime through,
  });
}
