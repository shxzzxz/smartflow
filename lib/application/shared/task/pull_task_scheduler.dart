import 'dart:async';

import 'package:logging/logging.dart';

import 'app_task.dart';
import 'task_retry_policy.dart';

final _logger = Logger('application.task');

class PullTaskScheduler {
  PullTaskScheduler({
    required List<AppTask> tasks,
    TaskRetryPolicy? retryPolicy,
    DateTime Function()? clock,
  }) : _tasks = List.unmodifiable(tasks),
       _retryPolicy = retryPolicy ?? TaskRetryPolicy(),
       _clock = clock ?? DateTime.now {
    if (tasks.map((task) => task.key).toSet().length != tasks.length) {
      throw ArgumentError('Task keys must be unique.');
    }
  }

  final List<AppTask> _tasks;
  final TaskRetryPolicy _retryPolicy;
  final DateTime Function() _clock;
  final Map<String, _TaskSchedule> _schedules = {};
  final _changes = StreamController<void>.broadcast();

  Stream<void> get scheduleChanges => _changes.stream;

  /// Full discovery opportunities still honor each task's execution policy.
  Future<void> trigger({DateTime? now, bool force = false}) =>
      _trigger(now: now, force: force);

  /// Additional wakes only check tasks whose effective hints have arrived.
  Future<void> triggerExpected({DateTime? now}) {
    final instant = now ?? _clock();
    final keys = <String>{};
    for (final task in _tasks) {
      final at = _effectiveCheckAt(task, instant);
      if (at != null && !at.isAfter(instant)) keys.add(task.key);
    }
    return _trigger(now: now, keys: keys);
  }

  /// Explicit user work bypasses automatic timing limits for this task only.
  Future<void> executeNow(String taskKey, {DateTime? now}) {
    _requireTask(taskKey);
    return _trigger(now: now, force: true, keys: {taskKey});
  }

  void updateTaskSchedule(String taskKey, DateTime? nextCheckAt) {
    _requireTask(taskKey);
    final state = _schedules.putIfAbsent(taskKey, _TaskSchedule.new);
    if (state.nextCheckAt == nextCheckAt) return;
    state.nextCheckAt = nextCheckAt;
    state.hintRevision++;
    _notifyChanged();
  }

  DateTime? nextExpectedCheckAt({DateTime? now}) {
    final instant = now ?? _clock();
    DateTime? next;
    for (final task in _tasks) {
      final at = _effectiveCheckAt(task, instant);
      if (at != null && (next == null || at.isBefore(next))) next = at;
    }
    return next;
  }

  DateTime? _effectiveCheckAt(AppTask task, DateTime now) {
    final state = _schedules[task.key];
    if (state == null) return null;
    var at = state.retryAfter ?? state.nextCheckAt;
    if (at == null) return null;
    final allowedAt = task.runPolicy.nextAllowedAt(
      now: now,
      lastSuccessfulRunAt: state.lastSuccessfulRunAt,
      lastCompletedAt: state.lastCompletedAt,
    );
    if (allowedAt.isAfter(at)) at = allowedAt;
    if (state.retryAfter case final retryAt?) {
      if (retryAt.isAfter(at)) at = retryAt;
    }
    return at;
  }

  void _requireTask(String key) {
    if (!_tasks.any((task) => task.key == key)) {
      throw ArgumentError.value(key, 'taskKey', 'Unknown task.');
    }
  }

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();

  Future<void> _trigger({
    DateTime? now,
    bool force = false,
    Set<String>? keys,
  }) async {
    final instant = now ?? _clock();
    for (final task in _tasks) {
      if (keys != null && !keys.contains(task.key)) continue;
      final state = _schedules.putIfAbsent(task.key, _TaskSchedule.new);
      final attemptAt = now ?? _clock();
      if (!force &&
          (!task.runPolicy.allows(
                now: attemptAt,
                lastSuccessfulRunAt: state.lastSuccessfulRunAt,
                lastCompletedAt: state.lastCompletedAt,
              ) ||
              (state.retryAfter != null &&
                  attemptAt.isBefore(state.retryAfter!)))) {
        continue;
      }
      final revision = ++state.revision;
      final hintRevision = state.hintRevision;
      AppTaskResult result;
      try {
        result = await task.run(instant);
      } on Exception catch (error, stackTrace) {
        _logger.severe(
          'Task ${task.key} failed; it will retry after its cooldown.',
          error,
          stackTrace,
        );
        result = const AppTaskResult.retryLater();
      }
      // An older execution must not overwrite a newer execution's schedule.
      if (revision != state.revision) continue;
      if (result.outcome == AppTaskOutcome.retryLater) {
        state.lastSuccessfulRunAt = null;
        state.lastCompletedAt = null;
        state.retryAfter = (now ?? _clock()).add(
          _retryPolicy.delayForAttempt(++state.retryCount),
        );
        _logger.info(
          'Task ${task.key} is waiting for its next eligible trigger.',
        );
      } else {
        state.lastSuccessfulRunAt = instant;
        state.lastCompletedAt = now ?? _clock();
        state.retryAfter = null;
        state.retryCount = 0;
        // A schedule updated while this run was awaiting I/O is newer than
        // its result. Keep the newer hint while still recording completion.
        if (state.hintRevision == hintRevision) {
          final at = result.nextCheckAt;
          state.nextCheckAt = at != null && at.isAfter(instant) ? at : null;
        }
        _logger.info('Task ${task.key} completed.');
      }
      _notifyChanged();
    }
  }
}

class _TaskSchedule {
  DateTime? lastSuccessfulRunAt, lastCompletedAt, retryAfter;
  DateTime? nextCheckAt;
  int retryCount = 0;
  int revision = 0;
  int hintRevision = 0;
}
