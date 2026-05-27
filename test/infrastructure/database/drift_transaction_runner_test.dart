import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/failure.dart';
import 'package:smartflow/core/result/result.dart';
import 'package:smartflow/data/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

import '../../helper/test_app_database.dart';

void main() {
  group('DriftTransactionRunner', () {
    late AppDatabase database;
    late DriftTransactionRunner runner;

    setUp(() {
      database = createTestDatabase();
      runner = DriftTransactionRunner(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('commits writes when body returns success', () async {
      final result = await runner.run<void>(() async {
        await _insertAccount(database, 'Wallet');
        return const Result.success(null);
      });

      expect(result, isA<Success<void>>());
      expect(await _testAccountCount(database), 1);
    });

    test('rolls back writes when body returns failure', () async {
      const failure = Failure(
        code: 'expected_failure',
        message: 'Expected failure.',
      );

      final result = await runner.run<void>(() async {
        await _insertAccount(database, 'Wallet');
        return const Result.failure(failure);
      });

      expect(result, isA<FailureResult<void>>());
      expect((result as FailureResult<void>).failure, same(failure));
      expect(await _testAccountCount(database), 0);
    });

    test('rolls back writes and rethrows unexpected exceptions', () async {
      await expectLater(
        runner.run<void>(() async {
          await _insertAccount(database, 'Wallet');
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await _testAccountCount(database), 0);
    });

    test('rolls back inner success when outer body returns failure', () async {
      const failure = Failure(code: 'outer_failure', message: 'Outer failure.');

      final result = await runner.run<void>(() async {
        await _insertAccount(database, 'Outer');

        final inner = await runner.run<void>(() async {
          await _insertAccount(database, 'Inner');
          return const Result.success(null);
        });
        expect(inner, isA<Success<void>>());

        return const Result.failure(failure);
      });

      expect(result, isA<FailureResult<void>>());
      expect((result as FailureResult<void>).failure, same(failure));
      expect(await _testAccountCount(database), 0);
    });

    test('rolls back all writes when inner failure is propagated', () async {
      const failure = Failure(code: 'inner_failure', message: 'Inner failure.');

      final result = await runner.run<void>(() async {
        await _insertAccount(database, 'Outer');

        final inner = await runner.run<void>(() async {
          await _insertAccount(database, 'Inner');
          return const Result.failure(failure);
        });
        expect(inner, isA<FailureResult<void>>());

        return inner;
      });

      expect(result, isA<FailureResult<void>>());
      expect((result as FailureResult<void>).failure, same(failure));
      expect(await _testAccountCount(database), 0);
    });

    test('can commit outer writes when inner failure is handled', () async {
      const failure = Failure(
        code: 'handled_inner_failure',
        message: 'Handled inner failure.',
      );

      final result = await runner.run<void>(() async {
        await _insertAccount(database, 'Outer');

        final inner = await runner.run<void>(() async {
          await _insertAccount(database, 'Inner');
          return const Result.failure(failure);
        });
        expect(inner, isA<FailureResult<void>>());

        return const Result.success(null);
      });

      expect(result, isA<Success<void>>());
      expect(await _accountNames(database), ['Outer']);
    });
  });
}

Future<String> _insertAccount(AppDatabase database, String name) {
  return database
      .into(database.accounts)
      .insert(
        AccountsCompanion.insert(name: name, accountType: AccountType.asset),
      );
}

Future<String> _testAccountCount(AppDatabase database) async {
  final names = await _accountNames(database);
  return names.length;
}

Future<List<String>> _accountNames(AppDatabase database) async {
  final rows = await database.select(database.accounts).get();
  return rows
      .map((row) => row.name)
      .where((name) => name == 'Wallet' || name == 'Outer' || name == 'Inner')
      .toList();
}
