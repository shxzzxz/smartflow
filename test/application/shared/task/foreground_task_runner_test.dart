import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/task/app_task.dart';
import 'package:smartflow/application/shared/task/foreground_task_runner.dart';
import 'package:smartflow/application/shared/task/pull_task_scheduler.dart';

DateTime at(int minute) => DateTime(2026, 11, 22, 10, minute);

void main() {
  late _Clock clock;
  late _Task timed;
  late _Task periodic;
  late PullTaskScheduler scheduler;
  late ForegroundTaskRunner runner;

  setUp(() {
    clock = _Clock(at(0));
    timed = _Task('timed');
    periodic = _Task('periodic');
    scheduler = PullTaskScheduler(
      tasks: [timed, periodic],
      clock: () => clock.now,
    );
    runner = ForegroundTaskRunner(
      scheduler: scheduler,
      clock: () => clock.now,
      timerFactory: clock.createTimer,
    );
  });

  tearDown(() async {
    await runner.dispose();
    await scheduler.dispose();
  });

  Future<void> start() async {
    runner.start();
    await pumpEventQueue();
  }

  test(
    'minimum interval postpones an expected check without running null-hint tasks',
    () async {
      timed.next = at(2);
      await start();
      expect(clock.timer.at, at(3));
      await clock.fireNext();
      expect(timed.checks, [at(0), at(3)]);
      expect(periodic.checks, [at(0)]);
      expect(clock.timer.at, at(15));
      await clock.fireNext();
      expect(periodic.checks, [at(0), at(15)]);
    },
  );

  test(
    'C equal to P minus M preserves both the expected and periodic checks',
    () async {
      timed.next = at(9);
      await start();
      timed.next = at(11);
      await clock.fireNext();
      expect(clock.now, at(9));
      expect(clock.timer.at, at(12));
      timed.next = null;
      await clock.fireNext();
      expect(timed.checks, [at(0), at(9), at(12)]);
      expect(periodic.checks, [at(0)]);
      expect(clock.timer.at, at(15));
      await clock.fireNext();
      expect(periodic.checks, [at(0), at(15)]);
      expect(clock.timer.at, at(30));
    },
  );

  test(
    'a candidate strictly inside the final interval becomes a full periodic check',
    () async {
      timed.next = at(10);
      await start();
      timed.next = at(11);
      await clock.fireNext();
      expect(clock.timer.at, at(13));
      timed.next = null;
      await clock.fireNext();
      expect(periodic.checks, [at(0), at(13)]);
      expect(clock.timer.at, at(28));
    },
  );

  test('a hint after P leaves the periodic check first', () async {
    timed.next = at(18);
    await start();
    expect(clock.timer.at, at(15));
    await clock.fireNext();
    expect(periodic.checks, [at(0), at(15)]);
    expect(clock.timer.at, at(18));
  });

  test(
    'updating a plan reschedules the shared timer without executing the task',
    () async {
      timed.next = at(12);
      await start();
      final original = clock.timer;
      scheduler.updateTaskSchedule(timed.key, at(5));
      await pumpEventQueue();
      expect(original.isActive, isFalse);
      expect(clock.timer.at, at(5));
      expect(timed.checks, [at(0)]);
      timed.next = null;
      await clock.fireNext();
      expect(timed.checks.last, at(5));
      expect(periodic.checks, [at(0)]);
    },
  );

  test(
    'background stops timers and resume performs one current-time discovery',
    () async {
      timed.next = at(2);
      await start();
      runner.stop();
      expect(clock.activeTimers, isEmpty);
      clock.now = at(7);
      runner.start();
      await pumpEventQueue();
      expect(timed.checks, [at(0), at(7)]);
      expect(periodic.checks, [at(0), at(7)]);
      expect(clock.timer.at, at(22));
    },
  );

  test(
    'a late callback performs one full catch-up check at the actual time',
    () async {
      timed.next = at(2);
      await start();
      timed.next = null;
      await clock.fireNext(actualAt: at(16));
      expect(timed.checks, [at(0), at(16)]);
      expect(periodic.checks, [at(0), at(16)]);
      expect(clock.timer.at, at(31));
    },
  );

  test('invalid interval configuration is rejected', () {
    expect(
      () => ForegroundTaskRunner(
        scheduler: scheduler,
        checkInterval: const Duration(minutes: 2),
        minimumTriggerInterval: const Duration(minutes: 3),
      ),
      throwsArgumentError,
    );
  });
}

class _Task implements AppTask {
  _Task(this.key);

  @override
  final String key;
  DateTime? next;
  final checks = <DateTime>[];

  @override
  TaskRunPolicy get runPolicy => TaskRunPolicy.minInterval(Duration.zero);

  @override
  Future<AppTaskResult> run(DateTime now) async {
    checks.add(now);
    return AppTaskResult.completed(nextCheckAt: next);
  }
}

class _Clock {
  _Clock(this.now);

  DateTime now;
  final timers = <_Timer>[];
  List<_Timer> get activeTimers =>
      timers.where((timer) => timer.isActive).toList();
  _Timer get timer => activeTimers.single;

  Timer createTimer(Duration delay, void Function() run) {
    final timer = _Timer(now.add(delay), run);
    timers.add(timer);
    return timer;
  }

  Future<void> fireNext({DateTime? actualAt}) async {
    final next = timer;
    now = actualAt ?? next.at;
    next.fire();
    await pumpEventQueue();
  }
}

class _Timer implements Timer {
  _Timer(this.at, this.run);

  final DateTime at;
  final void Function() run;
  bool _active = true;
  int _tick = 0;

  @override
  bool get isActive => _active;
  @override
  int get tick => _tick;
  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    _tick++;
    run();
  }
}
