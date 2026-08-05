enum TimeSeriesGranularity { day, week, month, year }

enum TimeSeriesAggregation { flowSum, periodEnd }

class MinorTimeSeriesPoint<K> {
  MinorTimeSeriesPoint({required this.date, required Map<K, int> values})
    : values = Map.unmodifiable(values);

  final DateTime date;
  final Map<K, int> values;
}

class MinorTimeSeriesBucket<K> {
  MinorTimeSeriesBucket({required this.start, required Map<K, int> values})
    : values = Map.unmodifiable(values);

  final DateTime start;
  final Map<K, int> values;
}

List<MinorTimeSeriesBucket<K>> aggregateMinorTimeSeries<K>(
  List<MinorTimeSeriesPoint<K>> points, {
  required TimeSeriesGranularity granularity,
  required TimeSeriesAggregation aggregation,
}) {
  if (points.isEmpty) return const [];

  final sorted = [...points]
    ..sort((left, right) => left.date.compareTo(right.date));
  final anchor = _dateOnly(sorted.first.date);
  final buckets = <DateTime, Map<K, int>>{};
  for (final point in sorted) {
    final start = timeSeriesBucketStart(
      point.date,
      granularity: granularity,
      anchor: anchor,
    );
    switch (aggregation) {
      case TimeSeriesAggregation.flowSum:
        final values = buckets.putIfAbsent(start, () => <K, int>{});
        for (final entry in point.values.entries) {
          values.update(
            entry.key,
            (current) => current + entry.value,
            ifAbsent: () => entry.value,
          );
        }
      case TimeSeriesAggregation.periodEnd:
        buckets[start] = Map<K, int>.from(point.values);
    }
  }
  return [
    for (final entry in buckets.entries)
      MinorTimeSeriesBucket(start: entry.key, values: entry.value),
  ];
}

DateTime timeSeriesBucketStart(
  DateTime date, {
  required TimeSeriesGranularity granularity,
  required DateTime anchor,
}) {
  final normalized = _dateOnly(date);
  return switch (granularity) {
    TimeSeriesGranularity.day => normalized,
    TimeSeriesGranularity.week => anchor.add(
      Duration(days: normalized.difference(anchor).inDays ~/ 7 * 7),
    ),
    TimeSeriesGranularity.month => DateTime(date.year, date.month),
    TimeSeriesGranularity.year => DateTime(date.year),
  };
}

List<T> sampleEveryNthPreservingLast<T>(List<T> items, {required int step}) {
  if (step <= 0) {
    throw ArgumentError.value(step, 'step', 'must be positive');
  }
  if (items.isEmpty || step == 1) return List<T>.of(items);

  final sampled = <T>[];
  var lastIndex = -1;
  for (var index = 0; index < items.length; index += step) {
    sampled.add(items[index]);
    lastIndex = index;
  }
  if (lastIndex != items.length - 1) sampled.add(items.last);
  return sampled;
}

List<T> topNWithOther<T>(
  Iterable<T> items, {
  required int maxItems,
  required int Function(T left, T right) compare,
  required T Function(List<T> tail) buildOther,
}) {
  if (maxItems <= 0) {
    throw ArgumentError.value(maxItems, 'maxItems', 'must be positive');
  }
  final ranked = items.toList()..sort(compare);
  if (ranked.length <= maxItems) return ranked;
  return [
    ...ranked.take(maxItems - 1),
    buildOther(ranked.skip(maxItems - 1).toList(growable: false)),
  ];
}

class TimeSeriesResolution {
  const TimeSeriesResolution({
    required this.granularity,
    required this.snapshotSampleIntervalDays,
  });

  factory TimeSeriesResolution.forSpanDays(int spanDays) {
    if (spanDays <= 0) {
      throw ArgumentError.value(spanDays, 'spanDays', 'must be positive');
    }
    return TimeSeriesResolution(
      granularity: switch (spanDays) {
        <= 45 => TimeSeriesGranularity.day,
        <= 180 => TimeSeriesGranularity.week,
        <= 730 => TimeSeriesGranularity.month,
        _ => TimeSeriesGranularity.year,
      },
      snapshotSampleIntervalDays: switch (spanDays) {
        <= 45 => 1,
        <= 180 => 7,
        <= 730 => 1,
        _ => 30,
      },
    );
  }

  final TimeSeriesGranularity granularity;
  final int snapshotSampleIntervalDays;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
