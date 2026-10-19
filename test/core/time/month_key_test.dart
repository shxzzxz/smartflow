import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/time/month_key.dart';

void main() {
  group('MonthKey', () {
    test('formats month keys as yyyy-MM', () {
      expect(MonthKey(year: 2026, month: 5).toString(), '2026-05');
    });

    test('creates a month key from local DateTime', () {
      final key = MonthKey.fromDate(DateTime(2026, 5, 7, 23, 30));

      expect(key.year, 2026);
      expect(key.month, 5);
    });

    test('calculates month boundaries', () {
      final key = MonthKey(year: 2026, month: 12);

      expect(key.start, DateTime(2026, 12));
      expect(key.nextMonthStart, DateTime(2027));
      expect(key.next, MonthKey(year: 2027, month: 1));
      expect(key.previous, MonthKey(year: 2026, month: 11));
      expect(key.previousYear, MonthKey(year: 2025, month: 12));
    });

    test('moves January to the previous December', () {
      final key = MonthKey(year: 2026, month: 1);

      expect(key.previous, MonthKey(year: 2025, month: 12));
    });

    test('rejects invalid month keys', () {
      expect(() => MonthKey.parse('2026-13'), throwsFormatException);
      expect(() => MonthKey.parse('202605'), throwsFormatException);
      expect(() => MonthKey(year: 2026, month: 13), throwsArgumentError);
    });
  });
}
