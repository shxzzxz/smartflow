import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/valobj/repayment_dates_strategy.dart';

void main() {
  group('IntervalRepaymentDates', () {
    test('单期计划采用末期日', () {
      final dates = IntervalRepaymentDates(
        firstDate: DateTime(2026, 2, 10),
        lastDate: DateTime(2026, 12, 10),
        count: 1,
      ).getDates();
      expect(dates, [DateTime(2026, 12, 10)]);
    });

    test('中间期按首期日逐月推进，末期采用约定日期', () {
      final dates = IntervalRepaymentDates(
        firstDate: DateTime(2026, 1, 15),
        lastDate: DateTime(2026, 12, 20),
        count: 12,
      ).getDates();
      expect(dates.first, DateTime(2026, 1, 15));
      expect(dates.last, DateTime(2026, 12, 20));
      for (var i = 1; i < dates.length - 1; i++) {
        expect(dates[i].day, 15);
      }
      expect(dates, hasLength(12));
    });

    test('期数不为正数时拒绝生成日期', () {
      expect(
        () => IntervalRepaymentDates(
          firstDate: DateTime(2026, 1, 1),
          lastDate: DateTime(2026, 6, 1),
          count: 0,
        ).getDates(),
        throwsArgumentError,
      );
    });
  });
}
