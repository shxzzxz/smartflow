import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

class DriftTransactionRunner implements TransactionRunner {
  const DriftTransactionRunner(this._database);

  final AppDatabase _database;

  @override
  Future<T> run<T>(Future<T> Function() body) {
    return _database.transaction(body);
  }
}
