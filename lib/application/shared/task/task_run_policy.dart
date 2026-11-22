/// A task declares its eligibility policy; the scheduler owns execution state.
sealed class TaskRunPolicy {
  const TaskRunPolicy();

  /// Fixed windows on the local calendar clock, anchored at 1970-01-01 00:00.
  /// A one-day window therefore resets at local midnight, including DST days.
  factory TaskRunPolicy.oncePerWindow(
    Duration window, {
    Duration offset = Duration.zero,
  }) {
    if (window <= Duration.zero || offset < Duration.zero || offset >= window) {
      throw ArgumentError('Window must be positive and offset within it.');
    }
    return _OncePerWindow(window, offset);
  }

  /// Minimum elapsed time after a successful execution finishes.
  factory TaskRunPolicy.minInterval(Duration interval) {
    if (interval < Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must not be negative.');
    }
    return _MinInterval(interval);
  }

  bool allows({
    required DateTime now,
    required DateTime? lastSuccessfulRunAt,
    required DateTime? lastCompletedAt,
  });

  /// Earliest permitted attempt, without creating a timer or execution promise.
  DateTime nextAllowedAt({
    required DateTime now,
    required DateTime? lastSuccessfulRunAt,
    required DateTime? lastCompletedAt,
  });
}

final class _OncePerWindow extends TaskRunPolicy {
  const _OncePerWindow(this.window, this.offset);

  final Duration window;
  final Duration offset;

  @override
  bool allows({
    required DateTime now,
    required DateTime? lastSuccessfulRunAt,
    required DateTime? lastCompletedAt,
  }) =>
      lastSuccessfulRunAt == null ||
      _windowOf(now) != _windowOf(lastSuccessfulRunAt);

  @override
  DateTime nextAllowedAt({
    required DateTime now,
    required DateTime? lastSuccessfulRunAt,
    required DateTime? lastCompletedAt,
  }) {
    if (allows(
      now: now,
      lastSuccessfulRunAt: lastSuccessfulRunAt,
      lastCompletedAt: lastCompletedAt,
    )) {
      return now;
    }
    final boundary = DateTime.fromMicrosecondsSinceEpoch(
      (_windowOf(now) + 1) * window.inMicroseconds + offset.inMicroseconds,
      isUtc: true,
    );
    return DateTime(
      boundary.year,
      boundary.month,
      boundary.day,
      boundary.hour,
      boundary.minute,
      boundary.second,
      boundary.millisecond,
      boundary.microsecond,
    );
  }

  int _windowOf(DateTime instant) {
    final local = instant.toLocal();
    final calendar = DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
    final value = calendar.microsecondsSinceEpoch - offset.inMicroseconds;
    final size = window.inMicroseconds;
    final bucket = value ~/ size;
    return value < 0 && value.remainder(size) != 0 ? bucket - 1 : bucket;
  }
}

final class _MinInterval extends TaskRunPolicy {
  const _MinInterval(this.interval);

  final Duration interval;

  @override
  bool allows({
    required DateTime now,
    required DateTime? lastSuccessfulRunAt,
    required DateTime? lastCompletedAt,
  }) => lastCompletedAt == null || now.difference(lastCompletedAt) >= interval;

  @override
  DateTime nextAllowedAt({
    required DateTime now,
    required DateTime? lastSuccessfulRunAt,
    required DateTime? lastCompletedAt,
  }) {
    final at = lastCompletedAt?.add(interval);
    return at != null && at.isAfter(now) ? at : now;
  }
}
