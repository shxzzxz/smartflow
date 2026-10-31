import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/service/amortization_schedule.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:test/test.dart';

void main() {
  test('monthly cadence is anchored and equal with the remainder last', () {
    final entries = buildAmortizationSchedule(
      planId: 'plan',
      total: const Money(minorUnits: 100000),
      firstRecognitionAt: DateTime(2026, 1, 31, 9, 30),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      cadenceInterval: 1,
      recognitionCount: 3,
    );

    expect(entries.map((entry) => entry.dueAt), [
      DateTime(2026, 1, 31, 9, 30),
      DateTime(2026, 2, 28, 9, 30),
      DateTime(2026, 3, 31, 9, 30),
    ]);
    expect(entries.map((entry) => entry.amount.minorUnits), [
      33333,
      33333,
      33334,
    ]);
    expect(
      entries.fold<int>(0, (sum, entry) => sum + entry.amount.minorUnits),
      100000,
    );
  });

  test('daily and yearly cadences preserve the anchor semantics', () {
    final daily = buildAmortizationSchedule(
      planId: 'daily',
      total: const Money(minorUnits: 3),
      firstRecognitionAt: DateTime(2026, 1, 1),
      cadenceUnit: AmortizationCadenceUnit.daily,
      cadenceInterval: 7,
      recognitionCount: 3,
    );
    expect(daily.map((entry) => entry.dueAt), [
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 8),
      DateTime(2026, 1, 15),
    ]);

    final yearly = buildAmortizationSchedule(
      planId: 'yearly',
      total: const Money(minorUnits: 3),
      firstRecognitionAt: DateTime(2024, 2, 29),
      cadenceUnit: AmortizationCadenceUnit.yearly,
      cadenceInterval: 1,
      recognitionCount: 3,
    );
    expect(yearly.map((entry) => entry.dueAt), [
      DateTime(2024, 2, 29),
      DateTime(2025, 2, 28),
      DateTime(2026, 2, 28),
    ]);
  });

  test('schedule rejects a period count larger than available cents', () {
    expect(
      () => buildAmortizationSchedule(
        planId: 'plan',
        total: const Money(minorUnits: 2),
        firstRecognitionAt: DateTime(2026, 1, 1),
        cadenceUnit: AmortizationCadenceUnit.daily,
        cadenceInterval: 1,
        recognitionCount: 3,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
