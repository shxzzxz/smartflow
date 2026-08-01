import 'package:logging/logging.dart';

final _logger = Logger('application.task');

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
      try {
        await task.run(instant);
      } on Exception catch (error, stackTrace) {
        _logger.severe(
          'Task ${task.key} failed; it will retry on the next trigger.',
          error,
          stackTrace,
        );
        continue;
      }
      _lastRunDayByTask[task.key] = day;
      _logger.info('Task ${task.key} completed.');
    }
  }
}
