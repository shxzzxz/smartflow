abstract interface class AppTask {
  String get key;

  Future<void> run(DateTime now);
}

class PullTaskScheduler {
  PullTaskScheduler({required List<AppTask> tasks}) : _tasks = tasks;

  final List<AppTask> _tasks;
  final Map<String, DateTime> _lastRunDayByTask = {};

  Future<void> trigger({DateTime? now, bool force = false}) async {
    final instant = now ?? DateTime.now();
    final day = DateTime(instant.year, instant.month, instant.day);
    for (final task in _tasks) {
      if (!force && _lastRunDayByTask[task.key] == day) {
        continue;
      }
      await task.run(instant);
      _lastRunDayByTask[task.key] = day;
    }
  }
}
