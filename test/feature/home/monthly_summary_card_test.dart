import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/application/ledger/ledger_api.dart';
import 'package:smartflow/feature/home/widget/monthly_summary_card.dart';

void main() {
  group('formatPeriodChangeMetrics', () {
    test('formats amount delta and both ratios', () {
      final caption = formatPeriodChangeMetrics(
        const PeriodChange(
          current: Money(minorUnits: 12500),
          previous: Money(minorUnits: 10000),
          previousFullPeriod: Money(minorUnits: 25000),
        ),
      );

      expect(caption, '+25/25%/50%');
    });

    test('formats zero baseline states', () {
      expect(
        formatPeriodChangeMetrics(
          const PeriodChange(
            current: Money(minorUnits: 0),
            previous: Money(minorUnits: 0),
            previousFullPeriod: Money(minorUnits: 0),
          ),
        ),
        '+0/--%/--%',
      );
      expect(
        formatPeriodChangeMetrics(
          const PeriodChange(
            current: Money(minorUnits: 2000),
            previous: Money(minorUnits: 0),
            previousFullPeriod: Money(minorUnits: 6000),
          ),
        ),
        '+20/--%/33%',
      );
    });
  });
}
