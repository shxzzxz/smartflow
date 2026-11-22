import '../application/shared/task/app_task.dart';

/// Date-dependent UI refresh is independent of bill generation success.
class DateBoundaryTask implements AppTask {
  const DateBoundaryTask({required this.onChanged});

  final void Function() onChanged;

  @override
  String get key => 'app.date_boundary';

  @override
  TaskRunPolicy get runPolicy =>
      TaskRunPolicy.oncePerWindow(const Duration(days: 1));

  @override
  Future<AppTaskResult> run(DateTime now) async {
    onChanged();
    return AppTaskResult.completed(
      nextCheckAt: runPolicy.nextAllowedAt(
        now: now,
        lastSuccessfulRunAt: now,
        lastCompletedAt: now,
      ),
    );
  }
}
