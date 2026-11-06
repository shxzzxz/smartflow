import 'insurance_enums.dart';

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class CoverageTerm {
  const CoverageTerm({
    required this.startDate,
    this.endDate,
    this.lifetime = false,
  });

  final DateTime startDate;
  final DateTime? endDate;
  final bool lifetime;

  void validate() {
    if (lifetime && endDate != null) {
      throw ArgumentError('Lifetime coverage cannot have an end date.');
    }
    if (endDate != null && _dateOnly(endDate!).isBefore(_dateOnly(startDate))) {
      throw ArgumentError('Coverage end date must not precede the start date.');
    }
  }

  InsuranceCoverageStatus statusAt(DateTime date) {
    if (lifetime) return InsuranceCoverageStatus.lifetime;
    final today = _dateOnly(date);
    if (today.isBefore(_dateOnly(startDate))) {
      return InsuranceCoverageStatus.notStarted;
    }
    if (endDate != null && today.isAfter(_dateOnly(endDate!))) {
      return InsuranceCoverageStatus.ended;
    }
    return InsuranceCoverageStatus.active;
  }
}
