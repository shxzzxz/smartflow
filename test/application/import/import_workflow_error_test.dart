import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/import/import_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/import/port/import_batch_repository.dart';
import 'package:smartflow/domain/import/port/import_ledger_port.dart';
import 'package:smartflow/domain/import/port/import_mapping_repository.dart';

import '../../helper/sequential_id_generator.dart';

void main() {
  for (final stage in _FailureStage.values) {
    test(
      '${stage.name} preserves an existing infrastructure failure',
      () async {
        final stack = StackTrace.fromString('original infrastructure stack');
        final error = InfrastructureException(
          ImportErrorCode.commitFailed,
          cause: Exception('storage failure'),
          stackTrace: stack,
        );

        await expectLater(
          _runFailure(stage, error, stack),
          throwsA(same(error)),
        );
      },
    );

    test('${stage.name} classifies unknown exceptions as technical', () async {
      final error = Exception('storage failure');
      final stack = StackTrace.fromString('original storage stack');

      await expectLater(
        _runFailure(stage, error, stack),
        throwsA(
          isA<InfrastructureException>()
              .having(
                (error) => error.code,
                'code',
                stage == _FailureStage.revert
                    ? ImportErrorCode.revertFailed.code
                    : ImportErrorCode.commitFailed.code,
              )
              .having((error) => error.cause, 'cause', same(error))
              .having((error) => error.stackTrace, 'stackTrace', same(stack)),
        ),
      );
    });

    test('${stage.name} lets programming errors escape unchanged', () async {
      final error = StateError('broken invariant');
      final stack = StackTrace.fromString('original programming error stack');

      await expectLater(_runFailure(stage, error, stack), throwsA(same(error)));
    });
  }
}

enum _FailureStage { preflight, group, batch, revert }

Future<void> _runFailure(
  _FailureStage stage,
  Object error,
  StackTrace stack,
) async {
  void fail() => Error.throwWithStackTrace(error, stack);
  final service = ImportWorkflowAppServiceImpl(
    mappings: _UnusedMappings(),
    batches: _Batches(stage, fail),
    ledger: _Ledger(stage, fail),
    transactionRunner: _Runner(),
    idGenerator: SequentialIdGenerator(),
    now: () => DateTime(2026, 9, 7),
  );
  if (stage == _FailureStage.revert) {
    await service.revertBatch('batch');
    return;
  }
  await service.commit(
    ImportCommitCommand(
      plan: ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [],
        groups: [
          ImportTransactionGroupDraft(
            topLevel: ImportTransferDraft(
              amount: const Money(minorUnits: 1000),
              fromAccount: const ImportAccountReference.source(
                sourceEntityKey: 'from',
                displayName: 'From',
              ),
              toAccount: const ImportAccountReference.source(
                sourceEntityKey: 'to',
                displayName: 'To',
              ),
              occurredAt: DateTime(2026, 9, 7),
            ),
            sourceOperationKey: 'operation',
            sourceOperationFingerprint: 'fingerprint',
            fingerprintVersion: 1,
          ),
        ],
      ),
      mappings: {
        for (final id in ['from', 'to'])
          ImportMappingKey(
            source: ImportSource.yimu,
            entityKind: ImportEntityKind.account,
            sourceEntityKey: id,
          ): id,
      },
      selectedGroupIndexes: {0},
    ),
  );
}

class _Runner implements TransactionRunner {
  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _UnusedMappings implements ImportMappingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Batches implements ImportBatchRepository {
  _Batches(this.stage, this.fail);

  final _FailureStage stage;
  final void Function() fail;

  @override
  Future<ImportDuplicateMatch> findDuplicates({
    required ImportSource source,
    required String? sourceOperationKey,
    required String sourceOperationFingerprint,
    required int fingerprintVersion,
  }) async {
    if (stage == _FailureStage.preflight) fail();
    return const ImportDuplicateMatch();
  }

  @override
  Future<void> saveImportedBatch({
    required ImportBatch batch,
    required Iterable<ImportBatchItem> items,
  }) async {
    if (stage == _FailureStage.batch) fail();
  }

  @override
  Future<ImportBatch?> findById(String batchId) async {
    fail();
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ledger implements ImportLedgerPort {
  _Ledger(this.stage, this.fail);

  final _FailureStage stage;
  final void Function() fail;

  @override
  Future<List<ImportLedgerTarget>> listTargets() async => [];

  @override
  Future<ImportLedgerTarget?> findTarget(String targetId) async {
    return ImportLedgerTarget(
      id: targetId,
      name: targetId,
      displayPath: targetId,
      kind: ImportLedgerTargetKind.asset,
      isArchived: false,
    );
  }

  @override
  Future<String> createTransfer({
    required Money amount,
    required String fromAccountId,
    required String toAccountId,
    required DateTime occurredAt,
    required DateTime postedAt,
    Money? feeAmount,
    String? note,
  }) async {
    if (stage == _FailureStage.group) fail();
    return 'transaction';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
