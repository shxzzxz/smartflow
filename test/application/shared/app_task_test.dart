import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/app_task.dart';

void main() {
  test('records a task run only after it succeeds', () async {
    final task = _FailOnceTask(StateError('transient failure'));
    final scheduler = PullTaskScheduler(tasks: [task]);
    final now = DateTime(2026, 7, 10, 9);

    await expectLater(scheduler.trigger(now: now), throwsStateError);

    await scheduler.trigger(now: now);
    await scheduler.trigger(now: now);

    expect(task.runCount, 2);
  });

  test('a failing task is retried and does not block later tasks', () async {
    final failing = _FailOnceTask(Exception('transient failure'));
    final healthy = _CountingTask('healthy');
    final scheduler = PullTaskScheduler(tasks: [failing, healthy]);
    final now = DateTime(2026, 7, 10, 9);

    await scheduler.trigger(now: now);

    expect(failing.runCount, 1);
    expect(healthy.runCount, 1);

    await scheduler.trigger(now: now);

    expect(failing.runCount, 2, reason: '失败任务应在下次触发时重试');
    expect(healthy.runCount, 1, reason: '成功任务当天不再重复执行');
  });
}

class _FailOnceTask implements AppTask {
  _FailOnceTask(this.failure);

  final Object failure;

  @override
  String get key => 'fail-once';

  var runCount = 0;

  @override
  Future<void> run(DateTime now) async {
    runCount++;
    if (runCount == 1) {
      throw failure;
    }
  }
}

class _CountingTask implements AppTask {
  _CountingTask(this.key);

  @override
  final String key;

  var runCount = 0;

  @override
  Future<void> run(DateTime now) async {
    runCount++;
  }
}
