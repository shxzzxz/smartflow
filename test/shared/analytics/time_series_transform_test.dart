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

  test('selects a granularity from both the date span and plot width', () {
    TimeSeriesGranularity resolve(DateTime from, DateTime until, double width) {
      return resolveTimeSeriesGranularity(
        from: from,
        until: until,
        plotWidth: width,
      );
    }

    expect(
      resolve(DateTime(2026, 1, 1), DateTime(2026, 1, 31), 300),
      TimeSeriesGranularity.day,
    );
    expect(
      resolve(DateTime(2026, 1, 1), DateTime(2026, 5, 1), 300),
      TimeSeriesGranularity.week,
    );
    expect(
      resolve(DateTime(2026, 1, 1), DateTime(2027, 1, 1), 300),
      TimeSeriesGranularity.month,
    );
    expect(
      resolve(DateTime(2026, 1, 1), DateTime(2027, 1, 1), 800),
      TimeSeriesGranularity.week,
    );
    expect(
      resolve(DateTime(2026, 1, 1), DateTime(2029, 1, 1), 800),
      TimeSeriesGranularity.month,
    );
    expect(
      resolve(DateTime(2016, 1, 1), DateTime(2026, 1, 1), 300),
      TimeSeriesGranularity.year,
    );
  });

  test('counts calendar buckets for a half-open range', () {
    expect(
      timeSeriesBucketCount(
        from: DateTime(2026, 1, 1),
        until: DateTime(2026, 2, 1),
        granularity: TimeSeriesGranularity.day,
      ),
      31,
    );
    expect(
      timeSeriesBucketCount(
        from: DateTime(2026, 1, 1),
        until: DateTime(2026, 2, 1),
        granularity: TimeSeriesGranularity.month,
      ),
      1,
    );
    expect(
      timeSeriesBucketCount(
        from: DateTime(2025, 12, 31),
        until: DateTime(2026, 1, 2),
        granularity: TimeSeriesGranularity.year,
      ),
      2,
    );
  });
}
