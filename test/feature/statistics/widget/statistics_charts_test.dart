import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/widget/business/analytics/chart/app_chart_scale.dart';

void main() {
  test('snaps chart range to clean tick multiples', () {
    final scale = AppChartScale.fromValues([120, 840, 1160], includeZero: true);

    expect(scale.min, 0);
    expect(scale.max, 1500);
    expect(scale.interval, 500);
  });

  test('spans negative and positive values around zero', () {
    final scale = AppChartScale.fromValues([-1234, 2600], includeZero: true);

    expect(scale.min, -2000);
    expect(scale.max, 4000);
    expect(scale.interval, 2000);
    expect(scale.min % scale.interval, 0);
  });

  test('pads a flat series into a readable band', () {
    final scale = AppChartScale.fromValues([5000, 5000]);

    expect(scale.min, lessThan(5000));
    expect(scale.max, greaterThan(5000));
    expect((scale.max - scale.min) / scale.interval, lessThanOrEqualTo(5));
  });

  test('formats axis amounts compactly', () {
    expect(appChartAxisLabel(0), '0');
    expect(appChartAxisLabel(500), '500');
    expect(appChartAxisLabel(-500), '-500');
    expect(appChartAxisLabel(15000), '1.5万');
    expect(appChartAxisLabel(20000), '2万');
    expect(appChartAxisLabel(-25000), '-2.5万');
    expect(appChartAxisLabel(120000000), '1.2亿');
  });
}
