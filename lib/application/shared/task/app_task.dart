/// Outcome belongs to one execution, including when executions overlap.
enum AppTaskOutcome { completed, retryLater }

abstract interface class AppTask {
  String get key;

  /// Catch up through [now]. Implementations own idempotency and concurrency.
  Future<AppTaskOutcome> run(DateTime now);
}
