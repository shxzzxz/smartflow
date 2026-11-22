import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/task/app_task.dart';
import 'package:smartflow/application/shared/task/pull_task_scheduler.dart';

void main() {
  final start = DateTime(2026, 11, 22, 10);

  test('expected time cannot bypass a task minimum interval', () async {
    final task = _Task(
      'hourly',
      policy: TaskRunPolicy.minInterval(const Duration(hours: 1)),
      result: AppTaskResult.completed(
        nextCheckAt: start.add(const Duration(minutes: 2)),
      ),
    );
    final scheduler = PullTaskScheduler(tasks: [task]);
    addTearDown(scheduler.dispose);
    await scheduler.trigger(now: start);
    expect(
      scheduler.nextExpectedCheckAt(now: start),
      start.add(const Duration(hours: 1)),
    );
    await scheduler.triggerExpected(now: start.add(const Duration(minutes: 2)));
    expect(task.count, 1);
  });

  test(
    'explicit execution affects the selected task only and accepts its new hint',
    () async {
      final selected = _Task(
        'selected',
        policy: TaskRunPolicy.minInterval(const Duration(hours: 1)),
      );
      final other = _Task('other');
      final scheduler = PullTaskScheduler(tasks: [selected, other]);
      addTearDown(scheduler.dispose);
      await scheduler.trigger(now: start);
      selected.result = AppTaskResult.completed(
        nextCheckAt: start.add(const Duration(minutes: 10)),
      );
      await scheduler.executeNow(
        selected.key,
        now: start.add(const Duration(minutes: 1)),
      );
      expect(selected.count, 2);
      expect(other.count, 1);
    },
  );

  test(
    'a schedule updated during I/O is not overwritten by an older run result',
    () async {
      final completion = Completer<AppTaskResult>();
      final task = _Task('task')..pending = completion.future;
      final scheduler = PullTaskScheduler(tasks: [task]);
      addTearDown(scheduler.dispose);
      final running = scheduler.trigger(now: start);
      final newer = start.add(const Duration(minutes: 2));
      scheduler.updateTaskSchedule(task.key, newer);
      completion.complete(
        AppTaskResult.completed(
          nextCheckAt: start.add(const Duration(hours: 2)),
        ),
      );
      await running;
      expect(scheduler.nextExpectedCheckAt(now: start), newer);
    },
  );

  test(
    'stale past hints are consumed instead of repeatedly scheduling immediate checks',
    () async {
      final task = _Task(
        'task',
        result: AppTaskResult.completed(nextCheckAt: start),
      );
      final scheduler = PullTaskScheduler(tasks: [task]);
      addTearDown(scheduler.dispose);
      await scheduler.trigger(now: start);
      expect(scheduler.nextExpectedCheckAt(now: start), isNull);
    },
  );

  test(
    'retry time gates further attempts and success replaces it with a fresh hint',
    () async {
      final task = _Task('task', result: const AppTaskResult.retryLater());
      final scheduler = PullTaskScheduler(tasks: [task]);
      addTearDown(scheduler.dispose);
      await scheduler.trigger(now: start);
      final retryAt = start.add(const Duration(minutes: 15));
      expect(scheduler.nextExpectedCheckAt(now: start), retryAt);
      await scheduler.triggerExpected(
        now: retryAt.subtract(const Duration(seconds: 1)),
      );
      expect(task.count, 1);
      task.result = AppTaskResult.completed(
        nextCheckAt: start.add(const Duration(hours: 1)),
      );
      await scheduler.triggerExpected(now: retryAt);
      expect(task.count, 2);
      expect(
        scheduler.nextExpectedCheckAt(now: retryAt),
        start.add(const Duration(hours: 1)),
      );
    },
  );

  test('fixed-window eligibility exposes the next aligned boundary', () {
    final policy = TaskRunPolicy.oncePerWindow(
      const Duration(hours: 1),
      offset: const Duration(minutes: 15),
    );
    final previous = DateTime(2026, 11, 22, 10, 58);
    expect(
      policy.nextAllowedAt(
        now: DateTime(2026, 11, 22, 11, 2),
        lastSuccessfulRunAt: previous,
        lastCompletedAt: previous,
      ),
      DateTime(2026, 11, 22, 11, 15),
    );
  });
}

class _Task implements AppTask {
  _Task(
    this.key, {
    TaskRunPolicy? policy,
    this.result = const AppTaskResult.completed(),
  }) : runPolicy = policy ?? TaskRunPolicy.minInterval(Duration.zero);

  @override
  final String key;
  @override
  final TaskRunPolicy runPolicy;
  AppTaskResult result;
  Future<AppTaskResult>? pending;
  int count = 0;

  @override
  Future<AppTaskResult> run(DateTime now) async {
    count++;
    if (pending case final future?) return await future;
    return result;
  }
}
