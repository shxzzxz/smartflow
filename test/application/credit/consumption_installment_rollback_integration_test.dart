import 'package:drift/drift.dart' show DatabaseConnection, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_contract_origination_service.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';

import '../../helper/sequential_id_generator.dart';

void main() {
  test('ledger failure leaves no purchase contract', () async {
    final database = _database();
    addTearDown(database.close);
    final service = _service(
      database,
      _DatabaseWritingLedger(database, failOnPost: true),
    );

    await expectLater(
      () => service.create(_command()),
      throwsA(isA<BusinessException>()),
    );

    expect(await database.select(database.installmentContracts).get(), isEmpty);
    expect(await database.select(database.installmentSchedules).get(), isEmpty);
    expect(await _sentinelRows(database), 0);
  });

  test(
    'credit failure rolls back a ledger write from the outer transaction',
    () async {
      final database = _database();
      addTearDown(database.close);
      final service = _service(database, _DatabaseWritingLedger(database));
      final invalidTerms = InstallmentContractTerms.singleStage(
        totalPeriods: 2,
        firstDate: DateTime(2026, 5, 31),
        lastDate: DateTime(2026, 8, 10),
        method: InstallmentRepaymentMethod.equalPrincipal,
        accrual: InterestAccrualMethod.daily,
      );

      await expectLater(
        () => service.create(_command(stageTerms: invalidTerms)),
        throwsA(isA<BusinessException>()),
      );

      expect(
        await database.select(database.installmentContracts).get(),
        isEmpty,
      );
      expect(
        await database.select(database.installmentSchedules).get(),
        isEmpty,
      );
      expect(await _sentinelRows(database), 0);
    },
  );

  test(
    'refund failure rolls back the refund transaction and principal reduction',
    () async {
      final database = _database();
      addTearDown(database.close);
      final installments = DriftInstallmentRepository(database);
      final bills = DriftBillRepository(database);
      final repayments = DriftRepaymentRepository(database);
      final runner = DriftTransactionRunner(database);
      final ids = SequentialIdGenerator(prefix: 'refund');
      final aggregate = const InstallmentContractOriginationService()
          .originatePurchase(
            contractId: 'purchase-contract',
            liabilityAccountId: 'credit',
            purchaseTransactionId: 'purchase-transaction',
            terms: InstallmentOriginationTerms(
              principal: const Money(minorUnits: 10000),
              borrowingDate: DateTime(2026, 6, 1),
              stageTerms: InstallmentContractTerms.singleStage(
                totalPeriods: 2,
                firstDate: DateTime(2026, 7, 10),
                lastDate: DateTime(2026, 8, 10),
                method: InstallmentRepaymentMethod.equalPrincipal,
                accrual: InterestAccrualMethod.daily,
              ),
            ),
            createdAt: DateTime(2026, 6, 1),
            newScheduleId: ids.newId,
          );
      await installments.insertAggregate(aggregate.contract);
      final plans = InstallmentPlanAppService(
        installments: installments,
        bills: bills,
        repayments: repayments,
        refundReductions: installments,
        runner: runner,
        idGenerator: ids,
      );
      final service = ConsumptionInstallmentAppServiceImpl(
        installments: installments,
        creditAccounts: _CreditAccounts(),
        refundReductions: installments,
        bills: bills,
        repayments: repayments,
        ledger: _DatabaseWritingLedger(database),
        plans: _FailingAutomaticPlan(plans),
        runner: runner,
        idGenerator: ids,
      );

      await expectLater(
        () => service.createRefund(
          CreateConsumptionInstallmentRefundCommand(
            contractId: 'purchase-contract',
            parentTransactionId: 'purchase-transaction',
            amount: const Money(minorUnits: 10000),
            categoryAllocations: const [
              ConsumptionInstallmentAllocation(
                accountId: 'food',
                amount: Money(minorUnits: 10000),
              ),
            ],
            settlementAllocations: const [
              ConsumptionInstallmentAllocation(
                accountId: 'credit',
                amount: Money(minorUnits: 10000),
              ),
            ],
            occurredAt: DateTime(2026, 6, 20),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );

      expect(
        await database.select(database.installmentRefundReductions).get(),
        isEmpty,
      );
      expect(
        await database.select(database.installmentSchedules).get(),
        hasLength(2),
      );
      expect(await _sentinelRows(database, key: 'refund'), 0);
    },
  );
}

AppDatabase _database() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

ConsumptionInstallmentAppService _service(
  AppDatabase database,
  CreditLedgerPort ledger,
) {
  final installments = DriftInstallmentRepository(database);
  final bills = _UnusedBills();
  final repayments = _UnusedRepayments();
  final runner = DriftTransactionRunner(database);
  final ids = SequentialIdGenerator(prefix: 'purchase');
  return ConsumptionInstallmentAppServiceImpl(
    installments: installments,
    creditAccounts: _CreditAccounts(),
    refundReductions: installments,
    bills: bills,
    repayments: repayments,
    ledger: ledger,
    plans: InstallmentPlanAppService(
      installments: installments,
      bills: bills,
      repayments: repayments,
      runner: runner,
      idGenerator: ids,
    ),
    runner: runner,
    idGenerator: ids,
  );
}

CreateConsumptionInstallmentCommand _command({
  InstallmentContractTerms? stageTerms,
}) {
  return CreateConsumptionInstallmentCommand(
    liabilityAccountId: 'credit',
    amount: const Money(minorUnits: 10000),
    categoryAllocations: const [
      ConsumptionInstallmentAllocation(
        accountId: 'food',
        amount: Money(minorUnits: 10000),
      ),
    ],
    settlementAllocations: const [
      ConsumptionInstallmentAllocation(
        accountId: 'credit',
        amount: Money(minorUnits: 10000),
      ),
    ],
    borrowingDate: DateTime(2026, 6, 1),
    occurredAt: DateTime(2026, 6, 1, 12),
    stageTerms:
        stageTerms ??
        InstallmentContractTerms.singleStage(
          totalPeriods: 2,
          firstDate: DateTime(2026, 7, 10),
          lastDate: DateTime(2026, 8, 10),
          method: InstallmentRepaymentMethod.equalPrincipal,
          accrual: InterestAccrualMethod.daily,
        ),
  );
}

Future<int> _sentinelRows(
  AppDatabase database, {
  String key = 'rollback',
}) async {
  final row = await database
      .customSelect(
        'SELECT COUNT(*) AS count FROM app_metadata WHERE key = ?',
        variables: [Variable.withString(key)],
      )
      .getSingle();
  return row.read<int>('count');
}

class _DatabaseWritingLedger implements CreditLedgerPort {
  _DatabaseWritingLedger(this.database, {this.failOnPost = false});

  final AppDatabase database;
  final bool failOnPost;

  @override
  Future<CreditLedgerPostedTransaction> postExpense(
    CreditLedgerPostExpenseCommand command,
  ) async {
    await database.customStatement(
      'INSERT INTO app_metadata (key, value, updated_at) VALUES (?, ?, ?)',
      ['rollback', 'written', DateTime(2026, 6, 1).millisecondsSinceEpoch],
    );
    if (failOnPost) {
      throw BusinessException(CreditErrorCode.contractInvalidCommand);
    }
    return const CreditLedgerPostedTransaction(
      transactionId: 'purchase-transaction',
    );
  }

  @override
  Future<CreditLedgerPostedTransaction> postRefund(
    CreditLedgerPostRefundCommand command,
  ) async {
    await database.customStatement(
      'INSERT INTO app_metadata (key, value, updated_at) VALUES (?, ?, ?)',
      ['refund', 'written', DateTime(2026, 6, 20).millisecondsSinceEpoch],
    );
    return const CreditLedgerPostedTransaction(
      transactionId: 'refund-transaction',
    );
  }

  @override
  Future<CreditLedgerAccountSnapshot?> findAccount(String accountId) async {
    return CreditLedgerAccountSnapshot(
      id: accountId,
      balance: Money.zero(),
      isArchived: false,
      kind: CreditLedgerAccountKind.liability,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FailingAutomaticPlan implements InstallmentPlanAppService {
  _FailingAutomaticPlan(this.delegate);

  final InstallmentPlanAppService delegate;

  @override
  Future<List<InstallmentPlanRow>> calculateCurrentRows(
    String contractId, {
    String? excludedRefundTransactionId,
  }) {
    return delegate.calculateCurrentRows(
      contractId,
      excludedRefundTransactionId: excludedRefundTransactionId,
    );
  }

  @override
  Future<void> applyAutomaticChange(
    String contractId,
    InstallmentPlanChangeRequest request,
  ) async {
    throw BusinessException(
      CreditErrorCode.contractPersistenceConflict,
      message: '计划保存失败',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _CreditAccounts implements CreditAccountRepository {
  @override
  Future<CreditLiabilityAccount?> findByAccountId(String accountId) async {
    return CreditLiabilityAccount(
      id: 'credit-extension',
      accountId: accountId,
      kind: CreditLiabilityAccountKind.credit,
      billingDay: 5,
      repaymentDay: 25,
      billingDayToNext: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
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
