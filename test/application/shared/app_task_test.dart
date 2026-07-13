import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/app_task.dart';

void main() {
  test('records a task run only after it succeeds', () async {
    final task = _FailOnceTask();
    final scheduler = PullTaskScheduler(tasks: [task]);
    final now = DateTime(2026, 7, 10, 9);

    await expectLater(scheduler.trigger(now: now), throwsStateError);

    await scheduler.trigger(now: now);
    await scheduler.trigger(now: now);

    expect(task.runCount, 2);
  });
}

class _FailOnceTask implements AppTask {
  @override
  String get key => 'fail-once';

  var runCount = 0;

  @override
  Future<void> run(DateTime now) async {
    runCount++;
    if (runCount == 1) {
      throw StateError('transient failure');
    }
  }
}
