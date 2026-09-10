import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/task/app_task.dart';
import 'package:smartflow/application/shared/task/pull_task_scheduler.dart';
import 'package:smartflow/application/shared/task/task_retry_policy.dart';

void main() {
  test(
    'waiting retries after cooldown and success completes the day',
    () async {
      final task = _Task(
        'waiting',
        (count) =>
            count == 1 ? AppTaskOutcome.retryLater : AppTaskOutcome.completed,
      );
      final scheduler = PullTaskScheduler(tasks: [task]);
      final now = DateTime(2026, 9, 20, 9);
      await scheduler.trigger(now: now);
      await scheduler.trigger(now: now);
      await scheduler.trigger(now: now.add(const Duration(minutes: 14)));
      expect(task.runCount, 1);
      await scheduler.trigger(now: now.add(const Duration(minutes: 15)));
      await scheduler.trigger(now: now.add(const Duration(hours: 1)));
      expect(task.runCount, 2);
      await scheduler.trigger(now: now.add(const Duration(days: 1)));
      expect(task.runCount, 3);
    },
  );

  test('backoff grows to its cap and survives midnight', () async {
    final task = _Task('waiting', (_) => AppTaskOutcome.retryLater);
    final scheduler = PullTaskScheduler(tasks: [task]);
    var now = DateTime(2026, 9, 20, 23, 55);
    await scheduler.trigger(now: now);
    for (final minutes in [15, 30, 60, 120, 240, 360, 360]) {
      final count = task.runCount;
      now = now.add(Duration(minutes: minutes));
      await scheduler.trigger(now: now.subtract(const Duration(seconds: 1)));
      expect(task.runCount, count);
      await scheduler.trigger(now: now);
      expect(task.runCount, count + 1);
    }
  });

  test(
    'success resets backoff and force bypasses cooldown and daily limit',
    () async {
      final task = _Task(
        'waiting',
        (count) =>
            count == 3 ? AppTaskOutcome.completed : AppTaskOutcome.retryLater,
      );
      final scheduler = PullTaskScheduler(tasks: [task]);
      final now = DateTime(2026, 9, 20, 9);
      await scheduler.trigger(now: now);
      await scheduler.trigger(now: now, force: true);
      await scheduler.trigger(now: now, force: true);
      await scheduler.trigger(now: now);
      expect(task.runCount, 3);
      await scheduler.trigger(now: now, force: true);
      await scheduler.trigger(now: now.add(const Duration(minutes: 14)));
      expect(task.runCount, 4);
      await scheduler.trigger(now: now.add(const Duration(minutes: 15)));
      expect(task.runCount, 5);
    },
  );

  test('exceptions back off without blocking other tasks', () async {
    final failing = _Task('fail-once', (count) {
      if (count == 1) throw Exception('transient failure');
      return AppTaskOutcome.completed;
    });
    final healthy = _Task('healthy');
    final scheduler = PullTaskScheduler(tasks: [failing, healthy]);
    final now = DateTime(2026, 7, 10, 9);
    await scheduler.trigger(now: now);
    await scheduler.trigger(now: now);
    expect(failing.runCount, 1);
    expect(healthy.runCount, 1);
    await scheduler.trigger(now: now.add(const Duration(minutes: 15)));
    expect(failing.runCount, 2);
    expect(healthy.runCount, 1);
  });

  test(
    'programming errors propagate without marking the task complete',
    () async {
      final task = _Task('fail-once', (count) {
        if (count == 1) throw StateError('programming error');
        return AppTaskOutcome.completed;
      });
      final scheduler = PullTaskScheduler(tasks: [task]);
      final now = DateTime(2026, 7, 10, 9);
      await expectLater(scheduler.trigger(now: now), throwsStateError);
      await scheduler.trigger(now: now);
      await scheduler.trigger(now: now);
      expect(task.runCount, 2);
    },
  );

  test(
    'cooldown begins at completion and accepts an injected policy',
    () async {
      var now = DateTime(2026, 9, 20, 9);
      final result = Completer<AppTaskOutcome>();
      final task = _Task(
        'slow',
        (count) => count == 1 ? result.future : AppTaskOutcome.completed,
      );
      final scheduler = PullTaskScheduler(
        tasks: [task],
        clock: () => now,
        retryPolicy: TaskRetryPolicy(initialDelay: const Duration(minutes: 30)),
      );
      final running = scheduler.trigger();
      now = now.add(const Duration(hours: 1));
      result.complete(AppTaskOutcome.retryLater);
      await running;
      now = now.add(const Duration(minutes: 29));
      await scheduler.trigger();
      expect(task.runCount, 1);
      now = now.add(const Duration(minutes: 1));
      await scheduler.trigger();
      expect(task.runCount, 2);
    },
  );

  test(
    'late completion cannot overwrite a newer overlapping execution',
    () async {
      final older = Completer<AppTaskOutcome>();
      final task = _Task(
        'overlapping',
        (count) => count == 1 ? older.future : AppTaskOutcome.completed,
      );
      final scheduler = PullTaskScheduler(tasks: [task]);
      final now = DateTime(2026, 9, 20, 9);
      final first = scheduler.trigger(now: now);
      await scheduler.trigger(now: now);
      older.complete(AppTaskOutcome.retryLater);
      await first;
      await scheduler.trigger(now: now.add(const Duration(hours: 1)));
      expect(task.runCount, 2);
    },
  );
}

class _Task implements AppTask {
  _Task(this.key, [this.action]);

  @override
  final String key;
  final FutureOr<AppTaskOutcome> Function(int count)? action;
  int runCount = 0;

  @override
  Future<AppTaskOutcome> run(DateTime now) async {
    runCount++;
    return action?.call(runCount) ?? AppTaskOutcome.completed;
  }
}
