import 'dart:async';

import 'pull_task_scheduler.dart';

typedef TaskTimerFactory = Timer Function(Duration delay, void Function() run);

/// Owns foreground timing. Task execution and OS notifications stay separate.
class ForegroundTaskRunner {
  ForegroundTaskRunner({
    required PullTaskScheduler scheduler,
    this.checkInterval = const Duration(minutes: 15),
    this.minimumTriggerInterval = const Duration(minutes: 3),
    DateTime Function()? clock,
    TaskTimerFactory? timerFactory,
  }) : _scheduler = scheduler,
       _clock = clock ?? DateTime.now,
       _timerFactory = timerFactory ?? ((delay, run) => Timer(delay, run)) {
    if (minimumTriggerInterval <= Duration.zero ||
        checkInterval < minimumTriggerInterval) {
      throw ArgumentError('Trigger intervals must be positive and ordered.');
    }
    _changes = _scheduler.scheduleChanges.listen((_) => _schedule());
  }

  final Duration checkInterval;
  final Duration minimumTriggerInterval;
  final PullTaskScheduler _scheduler;
  final DateTime Function() _clock;
  final TaskTimerFactory _timerFactory;
  late final StreamSubscription<void> _changes;
  Timer? _timer;
  _NextWake? _planned;
  DateTime? _lastTriggerAt;
  DateTime? _nextPeriodicAt;
  bool _active = false;
  bool _checking = false;
  int _generation = 0;
  int _timerRevision = 0;

  void start() {
    if (_active) return;
    _active = true;
    _checking = false;
    _generation++;
    unawaited(_check(periodic: true));
  }

  void stop() {
    _active = false;
    _generation++;
    _cancelTimer();
  }

  Future<void> dispose() async {
    stop();
    await _changes.cancel();
  }

  Future<void> _check({required bool periodic}) async {
    final generation = _generation;
    _checking = true;
    final now = _clock();
    _lastTriggerAt = now;
    if (periodic) _nextPeriodicAt = now.add(checkInterval);
    try {
      if (periodic) {
        await _scheduler.trigger();
      } else {
        await _scheduler.triggerExpected();
      }
    } finally {
      if (_active && generation == _generation) {
        _checking = false;
        _schedule();
      }
    }
  }

  void _schedule() {
    if (!_active || _checking) return;
    final now = _clock();
    // A backward wall-clock change must not postpone discovery indefinitely.
    if (_lastTriggerAt != null && now.isBefore(_lastTriggerAt!)) {
      _lastTriggerAt = null;
      _nextPeriodicAt = now.add(checkInterval);
    }
    final periodicAt = _nextPeriodicAt ?? now.add(checkInterval);
    final minimumAt = _lastTriggerAt?.add(minimumTriggerInterval) ?? now;
    final earliestAt = minimumAt.isAfter(now) ? minimumAt : now;
    final expectedAt = _scheduler.nextExpectedCheckAt(now: now);
    final candidate = expectedAt == null
        ? null
        : expectedAt.isAfter(earliestAt)
        ? expectedAt
        : earliestAt;
    final _NextWake next;
    if (candidate == null || !candidate.isBefore(periodicAt)) {
      next = _NextWake(
        at: periodicAt.isAfter(earliestAt) ? periodicAt : earliestAt,
        periodic: true,
      );
    } else {
      next = _NextWake(
        at: candidate,
        // Equality keeps both checks: P - M < C < P is strictly open.
        periodic: candidate.isAfter(
          periodicAt.subtract(minimumTriggerInterval),
        ),
      );
    }
    if (_timer?.isActive == true &&
        _planned?.at == next.at &&
        _planned?.periodic == next.periodic) {
      return;
    }
    _cancelTimer();
    _planned = next;
    final revision = _timerRevision;
    _timer = _timerFactory(next.at.difference(now), () {
      if (!_active || revision != _timerRevision) return;
      _timer = null;
      _planned = null;
      final actualNow = _clock();
      if (actualNow.isBefore(next.at)) {
        _schedule();
        return;
      }
      // If a callback is late enough to pass the periodic deadline, perform
      // one full catch-up check using the actual current time.
      final periodic =
          next.periodic ||
          (_nextPeriodicAt != null && !actualNow.isBefore(_nextPeriodicAt!));
      unawaited(_check(periodic: periodic));
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _planned = null;
    _timerRevision++;
  }
}

class _NextWake {
  const _NextWake({required this.at, required this.periodic});

  final DateTime at;
  final bool periodic;
}
