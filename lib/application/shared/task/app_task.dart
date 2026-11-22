import 'task_run_policy.dart';

export 'task_run_policy.dart';

/// Outcome belongs to one execution, including when executions overlap.
enum AppTaskOutcome { completed, retryLater }

/// One execution's outcome and an optional request for an additional check.
class AppTaskResult {
  const AppTaskResult({required this.outcome, this.nextCheckAt});

  const AppTaskResult.completed({this.nextCheckAt})
    : outcome = AppTaskOutcome.completed;

  const AppTaskResult.retryLater()
    : outcome = AppTaskOutcome.retryLater,
      nextCheckAt = null;

  final AppTaskOutcome outcome;
  final DateTime? nextCheckAt;
}

abstract interface class AppTask {
  String get key;

  TaskRunPolicy get runPolicy;

  /// Catch up through [now]. Implementations own idempotency and concurrency.
  Future<AppTaskResult> run(DateTime now);
}
