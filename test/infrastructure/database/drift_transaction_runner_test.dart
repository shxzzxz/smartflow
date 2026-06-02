import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_error_code.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_account_repository.dart';

import '../../helper/test_app_database.dart';

void main() {
  group('DriftTransactionRunner', () {
    test('runValue commits on success', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final runner = DriftTransactionRunner(database);
      final repository = DriftAccountRepository(database);

      final account = _account('account-1');
      final id = await runner.runValue<String>(() async {
        await repository.create(account);
        return account.id;
      });

      expect(id, 'account-1');
      expect(await repository.findById('account-1'), isNotNull);
    });

    test('runValue rolls back and rethrows BusinessException', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final runner = DriftTransactionRunner(database);
      final repository = DriftAccountRepository(database);
      final exception = BusinessException(_TestErrorCode.sample);

      await expectLater(
        () => runner.runValue<void>(() async {
          await repository.create(_account('account-2'));
          throw exception;
        }),
        throwsA(same(exception)),
      );
      expect(await repository.findById('account-2'), isNull);
    });

    test('runValue rolls back and rethrows unexpected exception', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final runner = DriftTransactionRunner(database);
      final repository = DriftAccountRepository(database);
      final exception = StateError('unexpected');

      await expectLater(
        () => runner.runValue<void>(() async {
          await repository.create(_account('account-3'));
          throw exception;
        }),
        throwsA(same(exception)),
      );
      expect(await repository.findById('account-3'), isNull);
    });

    test('run rolls back when body returns FailureResult', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final runner = DriftTransactionRunner(database);
      final repository = DriftAccountRepository(database);

      final result = await runner.run<void>(() async {
        await repository.create(_account('account-4'));
        return const Result.failure(
          Failure(code: 'test.failure', message: 'Failed.'),
        );
      });

      expect(result, isA<FailureResult<void>>());
      expect((result as FailureResult<void>).failure.code, 'test.failure');
      expect(await repository.findById('account-4'), isNull);
    });
  });
}

Account _account(String id) {
  return Account(
    id: id,
    name: id,
    type: AccountType.asset,
    balance: const Money(minorUnits: 0),
  );
}

enum _TestErrorCode implements AppErrorCode {
  sample;

  @override
  String get code => 'test.business';

  @override
  String get defaultMessage => 'Business failure.';
}
