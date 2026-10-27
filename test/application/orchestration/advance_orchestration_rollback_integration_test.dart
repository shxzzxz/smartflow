import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/orchestration/orchestration_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';
import 'package:smartflow/domain/orchestration/port/advance_ledger_port.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/orchestration/repository/drift_advance_case_repository.dart';

import '../../helper/sequential_id_generator.dart';

void main() {
  test('ledger failure rolls back the advance case write', () async {
    final database = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);
    final service = AdvanceOrchestrationAppServiceImpl(
      cases: DriftAdvanceCaseRepository(database),
      ledger: _FailingLedgerPort(),
      transactionRunner: DriftTransactionRunner(database),
      idGenerator: SequentialIdGenerator(prefix: 'case'),
    );

    await expectLater(
      service.createAdvance(
        CreateAdvanceWorkflowCommand(
          amount: Money.parse('100'),
          scenario: AdvanceScenario.reimbursement,
          trackingMode: AdvanceTrackingMode.account,
          aaPeopleCount: 2,
          receivableAccountId: 'receivable',
          categoryAllocations: [
            AccountAmountAllocation(
              accountId: 'food',
              amount: Money.parse('100'),
            ),
          ],
          settlementAllocations: [
            AccountAmountAllocation(
              accountId: 'cash',
              amount: Money.parse('100'),
            ),
          ],
          occurredAt: DateTime(2026, 10, 23),
        ),
      ),
      throwsA(isA<Exception>()),
    );

    expect(await database.select(database.advanceCases).get(), isEmpty);
  });
}

class _FailingLedgerPort implements AdvanceLedgerPort {
  @override
  Future<String> postAdvance({
    required Money amount,
    required Money advanceAmount,
    required String receivableAccountId,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> selfBorneAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required TransactionOwnership ownership,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? counterpartyId,
    String? note,
    bool isExcludedFromStats = false,
    bool isExcludedFromBudget = false,
    SourceKind sourceKind = SourceKind.manual,
    Set<String> tagIds = const {},
  }) {
    throw Exception('ledger failed');
  }

  @override
  Future<TransactionGroup?> findGroup(String transactionId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
