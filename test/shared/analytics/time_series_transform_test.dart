import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/shared/analytics/time_series_transform.dart';

void main() {
  test('sums flow values into calendar buckets', () {
    final buckets = aggregateMinorTimeSeries(
      [
        MinorTimeSeriesPoint(
          date: DateTime(2026, 1, 31),
          values: const {'income': 100, 'expense': 40},
        ),
        MinorTimeSeriesPoint(
          date: DateTime(2026, 2, 1),
          values: const {'income': 30, 'expense': 10},
        ),
        MinorTimeSeriesPoint(
          date: DateTime(2026, 2, 28),
          values: const {'income': 20, 'expense': 5},
        ),
      ],
      granularity: TimeSeriesGranularity.month,
      aggregation: TimeSeriesAggregation.flowSum,
    );

    expect(buckets.map((bucket) => bucket.values).toList(), [
      {'income': 100, 'expense': 40},
      {'income': 50, 'expense': 15},
    ]);
  });

  test('keeps the last snapshot in each time bucket', () {
    final buckets = aggregateMinorTimeSeries(
      [
        MinorTimeSeriesPoint(
          date: DateTime(2026, 1, 1),
          values: const {'assets': 100},
        ),
        MinorTimeSeriesPoint(
          date: DateTime(2026, 1, 31),
          values: const {'assets': 140},
        ),
        MinorTimeSeriesPoint(
          date: DateTime(2026, 2, 15),
          values: const {'assets': 120},
        ),
      ],
      granularity: TimeSeriesGranularity.month,
      aggregation: TimeSeriesAggregation.periodEnd,
    );

    expect(buckets.map((bucket) => bucket.values['assets']).toList(), [
      140,
      120,
    ]);
  });

  test('index sampling preserves the final item', () {
    final sampled = sampleEveryNthPreservingLast([1, 2, 3, 4, 5, 6], step: 2);

    expect(sampled, [1, 3, 5, 6]);
  });

  test('keeps the highest ranked values and folds the tail into other', () {
    final values = topNWithOther<int>(
      [10, 50, 20, 5],
      maxItems: 3,
      compare: (left, right) => right.compareTo(left),
      buildOther: (tail) => tail.fold(0, (sum, value) => sum + value),
    );

    expect(values, [50, 20, 15]);
  });

  test('selects one shared resolution for a visible date span', () {
    expect(
      TimeSeriesResolution.forSpanDays(30).granularity,
      TimeSeriesGranularity.day,
    );
    expect(
      TimeSeriesResolution.forSpanDays(120).granularity,
      TimeSeriesGranularity.week,
    );
    expect(
      TimeSeriesResolution.forSpanDays(365).granularity,
      TimeSeriesGranularity.month,
    );
    expect(
      TimeSeriesResolution.forSpanDays(900).granularity,
      TimeSeriesGranularity.year,
    );
    expect(
      TimeSeriesResolution.forSpanDays(900).snapshotSampleIntervalDays,
      30,
    );
  });
}
