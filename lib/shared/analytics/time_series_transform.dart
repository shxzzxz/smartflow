enum TimeSeriesGranularity { day, week, month, year }

enum TimeSeriesAggregation { flowSum, periodEnd }

enum TimeSeriesDensity {
  line(8.5),
  bar(10);

  const TimeSeriesDensity(this.minimumSlotWidth);

  /// 相邻时间桶在绘图区内至少需要的逻辑像素宽度。
  final double minimumSlotWidth;
}

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

/// 选择当前绘图区能够清楚承载的最细时间粒度。
///
/// 粒度的判断同时依赖观察区间和实际可视宽度，而不是只看天数。这样同一份
/// 日级数据在竖屏和横屏放大视图中可以获得不同的时间点密度。
TimeSeriesGranularity resolveTimeSeriesGranularity({
  required DateTime from,
  required DateTime until,
  required double plotWidth,
  TimeSeriesDensity density = TimeSeriesDensity.line,
}) {
  if (!until.isAfter(from)) {
    throw ArgumentError('until must be after from');
  }
  if (!plotWidth.isFinite || plotWidth <= 0) {
    return TimeSeriesGranularity.year;
  }
  for (final granularity in TimeSeriesGranularity.values) {
    final bucketCount = timeSeriesBucketCount(
      from: from,
      until: until,
      granularity: granularity,
    );
    if (bucketCount > 0 &&
        bucketCount * density.minimumSlotWidth <= plotWidth) {
      return granularity;
    }
  }
  return TimeSeriesGranularity.year;
}

int timeSeriesBucketCount({
  required DateTime from,
  required DateTime until,
  required TimeSeriesGranularity granularity,
}) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(until.year, until.month, until.day);
  if (!end.isAfter(start)) return 0;

  final spanDays = end.difference(start).inDays;
  return switch (granularity) {
    TimeSeriesGranularity.day => spanDays,
    TimeSeriesGranularity.week => (spanDays + 6) ~/ 7,
    TimeSeriesGranularity.month => _monthBucketCount(start, end),
    TimeSeriesGranularity.year => _yearBucketCount(start, end),
  };
}

int _monthBucketCount(DateTime start, DateTime end) {
  final last = end.subtract(const Duration(days: 1));
  return (last.year - start.year) * 12 + last.month - start.month + 1;
}

int _yearBucketCount(DateTime start, DateTime end) {
  final last = end.subtract(const Duration(days: 1));
  return last.year - start.year + 1;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
