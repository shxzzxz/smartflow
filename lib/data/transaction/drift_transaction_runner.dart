import '../../core/errors/failure.dart';
import '../../core/result/result.dart';
import '../../core/transaction/transaction_runner.dart';
import '../app_database.dart';

class DriftTransactionRunner implements TransactionRunner {
  const DriftTransactionRunner(this._database);

  final AppDatabase _database;

  @override
  Future<Result<T>> run<T>(Future<Result<T>> Function() body) async {
    try {
      return await _database.transaction(() async {
        final result = await body();
        if (result is FailureResult<T>) {
          throw _Rollback(result.failure);
        }
        return result;
      });
    } on _Rollback catch (rollback) {
      return Result.failure(rollback.failure);
    }
  }
}

class _Rollback implements Exception {
  const _Rollback(this.failure);

  final Failure failure;
}
