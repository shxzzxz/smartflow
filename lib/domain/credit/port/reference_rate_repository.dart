import '../valobj/reference_rate.dart';

abstract interface class ReferenceRateRepository {
  Future<List<ReferenceRate>> read(InterestRateType type);

  /// Participates in the application transaction; rejects conflicting same-day values.
  Future<void> merge(InterestRateType type, List<ReferenceRate> rates);
}
