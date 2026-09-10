import '../valobj/reference_rate.dart';

abstract interface class ReferenceRateRepository {
  Future<List<ReferenceRate>> read(ReferenceRateType type);

  /// Participates in the application transaction; rejects conflicting same-day values.
  Future<void> merge(ReferenceRateType type, List<ReferenceRate> rates);
}
