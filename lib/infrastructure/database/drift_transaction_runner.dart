import '../../core/error/failure.dart';
import '../../core/result/result.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

class DriftTransactionRunner implements TransactionRunner {
  const DriftTransactionRunner(this._database);

  final AppDatabase _database;

  @override
  Future<Result<T>> run<T>(Future<Result<T>> Function() body) async {
    try {
      return await _database.transaction(() async {
        final result = await body();
        if (result is FailureResult<T>) {
          // Drift rolls back on exceptions. Convert expected domain/application
          // failures to an internal signal, then restore them as Result values.
          throw _Rollback(result.failure);
        }
        return result;
      });
    } on _Rollback catch (rollback) {
      return Result.failure(rollback.failure);
    }
  }

  @override
  Future<T> runValue<T>(Future<T> Function() body) {
    return _database.transaction(body);
  }
}

class _Rollback implements Exception {
  const _Rollback(this.failure);

  final Failure failure;
}
