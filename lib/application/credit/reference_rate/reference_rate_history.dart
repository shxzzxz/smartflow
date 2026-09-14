import '../../../domain/credit/valobj/reference_rate.dart';

/// One snapshot of confirmed history, first local and then supplemented online.
class ReferenceRateHistory {
  ReferenceRateHistory({
    required this.asOf,
    required List<ReferenceRate> rates,
    this.updating = false,
    Map<InterestRateType, ReferenceRateMissingReason> failures = const {},
  }) : rates = List.unmodifiable(rates),
       failures = Map.unmodifiable(failures);

  final DateTime asOf;
  final List<ReferenceRate> rates;
  final bool updating;
  final Map<InterestRateType, ReferenceRateMissingReason> failures;
}
