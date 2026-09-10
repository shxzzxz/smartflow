/// Exponential backoff shared by incomplete tasks and failed executions.
class TaskRetryPolicy {
  TaskRetryPolicy({
    this.initialDelay = const Duration(minutes: 15),
    this.maxDelay = const Duration(hours: 6),
  }) {
    if (initialDelay <= Duration.zero || maxDelay < initialDelay) {
      throw ArgumentError('Retry delays must be positive and ordered.');
    }
  }

  final Duration initialDelay;
  final Duration maxDelay;

  Duration delayForAttempt(int attempt) {
    if (attempt < 1) throw ArgumentError.value(attempt, 'attempt');
    var delay = initialDelay;
    for (var i = 1; i < attempt && delay < maxDelay; i++) {
      delay *= 2;
    }
    return delay > maxDelay ? maxDelay : delay;
  }
}
