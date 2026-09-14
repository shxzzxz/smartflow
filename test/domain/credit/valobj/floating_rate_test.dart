import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/domain/credit/valobj/reference_rate.dart';

void main() {
  test('calendar recurrence preserves month-end anchor', () {
    final config = FloatingRateRule(
      referenceRateType: InterestRateType.lprOneYear,
      spreadBp: 0,
      firstResetDate: DateTime.utc(2026, 8, 31),
      firstEffectiveDate: DateTime.utc(2026, 8, 31),
      cycleMonths: 3,
    );
    expect(config.resetDate(1), DateTime.utc(2026, 11, 30));
    expect(config.resetDate(2), DateTime.utc(2027, 2, 28));
    expect(config.resetDate(3), DateTime.utc(2027, 5, 31));
  });
}
