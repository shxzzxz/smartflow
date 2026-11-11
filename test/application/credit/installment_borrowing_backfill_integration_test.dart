import 'package:drift/drift.dart' show DatabaseConnection, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_contract_origination_service.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';

import '../../helper/sequential_id_generator.dart';

void main() {
  test(
    'links the borrowing transaction and contract in one transaction',
    () async {
      final database = _database();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);
      await _insertRecordedContract(repository);
      final service = _service(
        repository,
        database,
        _DatabaseWritingLedger(database),
      );

      final result = await service.createBorrowingTransaction(
        CreateDisbursementTransactionCommand(
          contractId: 'contract-1',
          receiveAccountId: 'cash',
          occurredAt: DateTime(2026, 8, 20, 14, 30),
        ),
      );

      expect(result.transactionId, 'borrowing-transaction');
      expect(
        (await repository.findContract('contract-1'))!.sourceRefId,
        result.transactionId,
      );
      expect(await _metadataCount(database, 'borrowing'), 1);
      expect(await _metadataCount(database, 'ownership'), 1);
    },
  );

  test('contract save failure rolls back the borrowing transaction', () async {
    final database = _database();
    addTearDown(database.close);
    final repository = DriftInstallmentRepository(database);
    await _insertRecordedContract(repository);
    final service = _service(
      _FailingSaveInstallments(repository),
      database,
      _DatabaseWritingLedger(database),
    );

    await expectLater(
      () => service.createBorrowingTransaction(
        CreateDisbursementTransactionCommand(
          contractId: 'contract-1',
          receiveAccountId: 'cash',
          occurredAt: DateTime(2026, 6, 1),
        ),
      ),
      throwsA(isA<BusinessException>()),
    );

    expect((await repository.findContract('contract-1'))!.sourceRefId, isNull);
    expect(await _metadataCount(database, 'borrowing'), 0);
    expect(await _metadataCount(database, 'ownership'), 0);
  });
}

AppDatabase _database() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

Future<void> _insertRecordedContract(InstallmentRepository repository) {
  var scheduleId = 1;
  final aggregate = const InstallmentContractOriginationService()
      .originateDisbursement(
        contractId: 'contract-1',
        liabilityAccountId: 'loan',
        terms: InstallmentOriginationTerms(
          principal: const Money(minorUnits: 120000),
          borrowingDate: DateTime(2026, 6, 1),
          note: '历史贷款',
          stageTerms: InstallmentContractTerms.singleStage(
            totalPeriods: 2,
            firstDate: DateTime(2026, 7, 1),
            lastDate: DateTime(2026, 8, 1),
            method: InstallmentRepaymentMethod.equalPrincipal,
            accrual: InterestAccrualMethod.daily,
          ),
        ),
        createdAt: DateTime(2026, 6, 1),
        newScheduleId: () => 'schedule-${scheduleId++}',
      );
  return repository.insertAggregate(aggregate.contract);
}

DisbursementInstallmentAppService _service(
  InstallmentRepository installments,
  AppDatabase database,
  CreditLedgerPort ledger,
) {
  final runner = DriftTransactionRunner(database);
  return DisbursementInstallmentAppServiceImpl(
    installments: installments,
    bills: _UnusedBills(),
    repayments: _UnusedRepayments(),
    ledger: ledger,
    runner: runner,
    idGenerator: SequentialIdGenerator(prefix: 'test'),
  );
}

Future<int> _metadataCount(AppDatabase database, String key) async {
  final row = await database
      .customSelect(
        'SELECT COUNT(*) AS count FROM app_metadata WHERE key = ?',
        variables: [Variable.withString(key)],
      )
      .getSingle();
  return row.read<int>('count');
}

class _DatabaseWritingLedger implements CreditLedgerPort {
  _DatabaseWritingLedger(this.database);

  final AppDatabase database;

  @override
  Future<CreditLedgerPostedTransaction> postBorrowing(
    CreditLedgerPostBorrowingCommand command,
  ) async {
    await _writeMetadata('borrowing');
    return const CreditLedgerPostedTransaction(
      transactionId: 'borrowing-transaction',
    );
  }

  @override
  Future<void> updateOwnership({
    required String transactionId,
    required CreditLedgerOwnership ownership,
  }) => _writeMetadata('ownership');

  Future<void> _writeMetadata(String key) {
    return database.customStatement(
      'INSERT INTO app_metadata (key, value, updated_at) VALUES (?, ?, ?)',
      [key, 'written', DateTime(2026, 6, 1).millisecondsSinceEpoch],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FailingSaveInstallments implements InstallmentRepository {
  _FailingSaveInstallments(this.delegate);

  final InstallmentRepository delegate;

  @override
  Future<InstallmentContract?> findContract(String id) =>
      delegate.findContract(id);

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) => delegate.listContractsByLiabilityAccount(liabilityAccountId);

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) =>
      delegate.listSchedules(contractId);

  @override
  Future<List<InstallmentSchedule>> listSchedulesByLiabilityAccount(
    String liabilityAccountId,
  ) => delegate.listSchedulesByLiabilityAccount(liabilityAccountId);

  @override
  Future<InstallmentSchedule?> findSchedule(String scheduleId) =>
      delegate.findSchedule(scheduleId);

  @override
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    String transactionId,
  ) => delegate.findContractByDisbursementTransaction(transactionId);

  @override
  Future<void> insertAggregate(InstallmentContract contract) =>
      delegate.insertAggregate(contract);

  @override
  Future<void> saveAggregate(InstallmentContract contract) async {
    throw BusinessException(
      CreditErrorCode.contractPersistenceConflict,
      message: '合同回写失败',
    );
  }

  @override
  Future<void> deleteContract(String contractId) =>
      delegate.deleteContract(contractId);
}

class _UnusedBills implements BillRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedRepayments implements RepaymentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
