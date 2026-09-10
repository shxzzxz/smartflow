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
       _clock = clock ?? DateTime.now;

  final List<AppTask> _tasks;
  final TaskRetryPolicy _retryPolicy;
  final DateTime Function() _clock;
  final Map<String, _TaskSchedule> _schedules = {};

  /// A cooldown only gates later triggers; it never starts a timer.
  Future<void> trigger({DateTime? now, bool force = false}) async {
    final instant = now ?? _clock();
    final day = DateTime(instant.year, instant.month, instant.day);
    for (final task in _tasks) {
      final state = _schedules.putIfAbsent(task.key, _TaskSchedule.new);
      final attemptAt = now ?? _clock();
      if (!force &&
          (state.lastRunDay == day ||
              (state.retryAfter != null &&
                  attemptAt.isBefore(state.retryAfter!)))) {
        continue;
      }
      final revision = ++state.revision;
      AppTaskOutcome outcome;
      try {
        outcome = await task.run(instant);
      } on Exception catch (error, stackTrace) {
        _logger.severe(
          'Task ${task.key} failed; it will retry after its cooldown.',
          error,
          stackTrace,
        );
        outcome = AppTaskOutcome.retryLater;
      }
      // An older execution must not overwrite a newer execution's schedule.
      if (revision != state.revision) continue;
      if (outcome == AppTaskOutcome.retryLater) {
        state.lastRunDay = null;
        state.retryAfter = (now ?? _clock()).add(
          _retryPolicy.delayForAttempt(++state.retryCount),
        );
        _logger.info(
          'Task ${task.key} is waiting for its next eligible trigger.',
        );
      } else {
        state.lastRunDay = day;
        state.retryAfter = null;
        state.retryCount = 0;
        _logger.info('Task ${task.key} completed.');
      }
    }
  }
}

class _TaskSchedule {
  DateTime? lastRunDay, retryAfter;
  int retryCount = 0;
  int revision = 0;
}
