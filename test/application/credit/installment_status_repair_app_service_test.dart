import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import '../../helper/test_app_database.dart';

void main() {
  group('InstallmentStatusRepairAppService', () {
    for (final failAfterSave in [false, true]) {
      test(
        failAfterSave
            ? 'failure after saving rolls back schedule and contract repairs'
            : 'standalone repair commits schedule and contract statuses together',
        () async {
          final db = createTestDatabase();
          addTearDown(db.close);
          final installments = DriftInstallmentRepository(db);
          final contract = _contract(
            id: 'repair-transaction',
            status: InstallmentContractStatus.settled,
          );
          final schedules = [
            for (var period = 1; period <= 2; period++)
              _schedule(
                id: 'repair-schedule-$period',
                contractId: contract.id,
                periodNo: period,
                status: InstallmentScheduleStatus.paid,
              ),
          ];
          await installments.insertAggregate(contract, schedules);
          final service = InstallmentStatusRepairAppService(
            installments: failAfterSave
                ? _FailAfterSavingInstallments(db)
                : installments,
            bills: DriftBillRepository(db),
            repayments: DriftRepaymentRepository(db),
            transactionRunner: DriftTransactionRunner(db),
          );

          if (failAfterSave) {
            await expectLater(
              service.validateAndRepair(contract.id),
              throwsStateError,
            );
          } else {
            final result = await service.validateAndRepair(contract.id);
            expect(result.repairedScheduleCount, 2);
            expect(result.contractStatusChanged, isTrue);
          }

          expect(
            (await installments.findContract(contract.id))!.status,
            failAfterSave
                ? InstallmentContractStatus.settled
                : InstallmentContractStatus.active,
          );
          final saved = await installments.listSchedules(contract.id);
          expect(
            saved.map((row) => row.status),
            everyElement(
              failAfterSave
                  ? InstallmentScheduleStatus.paid
                  : InstallmentScheduleStatus.pending,
            ),
          );
          expect(
            saved.map((row) => row.expectedPrincipal),
            schedules.map((row) => row.expectedPrincipal),
          );
          expect(
            saved.map((row) => row.expectedRepaymentDate),
            schedules.map((row) => row.expectedRepaymentDate),
          );
        },
      );
    }

    test(
      'status repair reopens a paid schedule without repayment facts',
      () async {
        final fixture = _Fixture();
        final contract = _contract(
          id: 'contract-validation',
          status: InstallmentContractStatus.settled,
        );
        fixture.installments.putContract(contract);
        fixture.installments.putSchedules(contract.id, [
          _schedule(
            id: 'schedule-interest-only',
            contractId: contract.id,
            periodNo: 1,
            status: InstallmentScheduleStatus.paid,
            principal: Money.zero(),
            interest: const Money(minorUnits: 500),
          ),
        ]);

        final result = await fixture.service.validateAndRepair(contract.id);

        expect(result.repairedScheduleCount, 1);
        expect(result.contractStatusChanged, isTrue);
        expect(result.issues, isEmpty);
        expect(
          fixture.installments.schedulesFor(contract.id).single.status,
          InstallmentScheduleStatus.pending,
        );
        expect(
          fixture.installments.contracts[contract.id]!.status,
          InstallmentContractStatus.active,
        );
      },
    );

    test(
      'status repair preserves skipped schedules and reports allocations',
      () async {
        final fixture = _Fixture();
        final contract = _contract(id: 'contract-skipped');
        final schedule = _schedule(
          id: 'schedule-skipped',
          contractId: contract.id,
          periodNo: 1,
          status: InstallmentScheduleStatus.skipped,
        );
        fixture.installments
          ..putContract(contract)
          ..putSchedules(contract.id, [schedule]);
        fixture.bills.bills['bill-skipped'] = Bill(
          id: 'bill-skipped',
          accountId: contract.liabilityAccountId,
          period: BillPeriod.fromInt(202607),
          status: BillStatus.billed,
          items: [
            BillItem(
              id: 'bill-item-skipped',
              billId: 'bill-skipped',
              itemType: BillItemType.installment,
              contractId: contract.id,
              scheduleId: schedule.id,
              repaymentDate: schedule.expectedRepaymentDate,
              expectedPrincipal: schedule.expectedPrincipal,
              expectedInterest: schedule.expectedInterest,
              expectedFee: schedule.expectedFee,
              status: BillItemStatus.paid,
            ),
          ],
        );
        fixture.repayments.putRepayment(
          Repayment(
            id: 'repayment-skipped',
            repaymentType: RepaymentType.bill,
            targetType: RepaymentTargetType.bill,
            targetId: 'bill-skipped',
            repaymentDate: DateTime(2026, 7, 10),
            items: [
              RepaymentItem(
                id: 'repayment-item-skipped',
                repaymentId: 'repayment-skipped',
                billItemId: 'bill-item-skipped',
                allocated: const RepaymentAmountBreakdown(
                  principal: Money(minorUnits: 5000),
                  interest: Money(minorUnits: 50),
                  fee: Money(minorUnits: 0),
                  discount: Money(minorUnits: 0),
                ),
              ),
            ],
          ),
        );

        final result = await fixture.service.validateAndRepair(contract.id);

        expect(
          fixture.installments.schedulesFor(contract.id).single.status,
          InstallmentScheduleStatus.skipped,
        );
        expect(result.repairedScheduleCount, 0);
        expect(result.contractStatusChanged, isFalse);
        expect(
          result.issues.single.type,
          ContractStatusValidationIssueType.skippedScheduleHasAllocation,
        );
        expect(
          fixture.installments.contracts[contract.id]!.status,
          InstallmentContractStatus.active,
        );
      },
    );

    test(
      'status repair leaves schedules unchanged for orphan allocations',
      () async {
        final fixture = _Fixture();
        final contract = _contract(
          id: 'contract-orphan',
          status: InstallmentContractStatus.settled,
        );
        final schedule = _schedule(
          id: 'schedule-orphan',
          contractId: contract.id,
          periodNo: 1,
          status: InstallmentScheduleStatus.paid,
        );
        fixture.installments
          ..putContract(contract)
          ..putSchedules(contract.id, [schedule]);
        fixture.bills.bills['bill-orphan'] = Bill(
          id: 'bill-orphan',
          accountId: contract.liabilityAccountId,
          period: BillPeriod.fromInt(202607),
          status: BillStatus.billed,
          items: [
            BillItem(
              id: 'bill-item-orphan',
              billId: 'bill-orphan',
              itemType: BillItemType.installment,
              contractId: contract.id,
              scheduleId: schedule.id,
              repaymentDate: schedule.expectedRepaymentDate,
              expectedPrincipal: schedule.expectedPrincipal,
              expectedInterest: schedule.expectedInterest,
              expectedFee: schedule.expectedFee,
              status: BillItemStatus.paid,
            ),
          ],
        );
        fixture.repayments.items['missing-repayment'] = [
          RepaymentItem(
            id: 'orphan-item',
            repaymentId: 'missing-repayment',
            billItemId: 'bill-item-orphan',
            allocated: const RepaymentAmountBreakdown(
              principal: Money(minorUnits: 5000),
              interest: Money(minorUnits: 50),
              fee: Money(minorUnits: 0),
              discount: Money(minorUnits: 0),
            ),
          ),
        ];

        final result = await fixture.service.validateAndRepair(contract.id);

        expect(result.repairedScheduleCount, 0);
        expect(result.contractStatusChanged, isFalse);
        expect(
          result.issues.single.type,
          ContractStatusValidationIssueType.repaymentMissing,
        );
        expect(
          fixture.installments.schedulesFor(contract.id).single.status,
          InstallmentScheduleStatus.paid,
        );
        expect(
          fixture.installments.contracts[contract.id]!.status,
          InstallmentContractStatus.settled,
        );
      },
    );

    test(
      'status repair reports zero allocations without changing status',
      () async {
        final fixture = _Fixture();
        final contract = _contract(id: 'contract-zero-allocation');
        final schedule = _schedule(
          id: 'schedule-zero-allocation',
          contractId: contract.id,
          periodNo: 1,
        );
        fixture.installments
          ..putContract(contract)
          ..putSchedules(contract.id, [schedule]);
        fixture.bills.bills['bill-zero-allocation'] = Bill(
          id: 'bill-zero-allocation',
          accountId: contract.liabilityAccountId,
          period: BillPeriod.fromInt(202607),
          status: BillStatus.billed,
          items: [
            BillItem(
              id: 'bill-item-zero-allocation',
              billId: 'bill-zero-allocation',
              itemType: BillItemType.installment,
              contractId: contract.id,
              scheduleId: schedule.id,
              repaymentDate: schedule.expectedRepaymentDate,
              expectedPrincipal: schedule.expectedPrincipal,
              expectedInterest: schedule.expectedInterest,
              expectedFee: schedule.expectedFee,
              status: BillItemStatus.pending,
            ),
          ],
        );
        fixture.repayments.putRepayment(
          Repayment(
            id: 'repayment-zero-allocation',
            repaymentType: RepaymentType.bill,
            targetType: RepaymentTargetType.bill,
            targetId: 'bill-zero-allocation',
            repaymentDate: DateTime(2026, 7, 10),
            items: const [
              RepaymentItem(
                id: 'repayment-item-zero-allocation',
                repaymentId: 'repayment-zero-allocation',
                billItemId: 'bill-item-zero-allocation',
                allocated: RepaymentAmountBreakdown.zero,
              ),
            ],
          ),
        );

        final result = await fixture.service.validateAndRepair(contract.id);

        expect(result.repairedScheduleCount, 0);
        expect(result.contractStatusChanged, isFalse);
        expect(
          result.issues.single.type,
          ContractStatusValidationIssueType.zeroAllocation,
        );
        expect(
          fixture.installments.schedulesFor(contract.id).single.status,
          InstallmentScheduleStatus.pending,
        );
      },
    );

    test('status repair reports contracts without schedules', () async {
      final fixture = _Fixture();
      final contract = _contract(id: 'contract-without-schedules');
      fixture.installments
        ..putContract(contract)
        ..putSchedules(contract.id, const []);

      final result = await fixture.service.validateAndRepair(contract.id);

      expect(result.repairedScheduleCount, 0);
      expect(result.contractStatusChanged, isFalse);
      expect(
        result.issues.single.type,
        ContractStatusValidationIssueType.noSchedules,
      );
    });

    test('status repair reports bill items with missing schedules', () async {
      final fixture = _Fixture();
      final contract = _contract(id: 'contract-missing-schedule');
      fixture.installments
        ..putContract(contract)
        ..putSchedules(contract.id, [
          _schedule(
            id: 'schedule-existing',
            contractId: contract.id,
            periodNo: 1,
          ),
        ]);
      fixture.bills.bills['bill-missing-schedule'] = Bill(
        id: 'bill-missing-schedule',
        accountId: contract.liabilityAccountId,
        period: BillPeriod.fromInt(202607),
        status: BillStatus.billed,
        items: [
          BillItem(
            id: 'bill-item-missing-schedule',
            billId: 'bill-missing-schedule',
            itemType: BillItemType.installment,
            contractId: contract.id,
            scheduleId: 'schedule-missing',
            repaymentDate: DateTime(2026, 7, 10),
            expectedPrincipal: const Money(minorUnits: 5000),
            expectedInterest: const Money(minorUnits: 50),
            expectedFee: Money.zero(),
            status: BillItemStatus.pending,
          ),
        ],
      );

      final result = await fixture.service.validateAndRepair(contract.id);

      expect(
        result.issues.single.type,
        ContractStatusValidationIssueType.scheduleMissing,
      );
      expect(result.contractStatusChanged, isFalse);
    });

    test(
      'status repair reports missing bill items without blocking known facts',
      () async {
        final fixture = _Fixture();
        final contract = _contract(
          id: 'contract-missing-bill-item',
          status: InstallmentContractStatus.settled,
        );
        fixture.installments
          ..putContract(contract)
          ..putSchedules(contract.id, [
            _schedule(
              id: 'schedule-missing-bill-item',
              contractId: contract.id,
              periodNo: 1,
              status: InstallmentScheduleStatus.paid,
            ),
          ]);
        fixture.bills.bills['bill-with-orphan-item'] = Bill(
          id: 'bill-with-orphan-item',
          accountId: contract.liabilityAccountId,
          period: BillPeriod.fromInt(202607),
          status: BillStatus.billed,
          items: const [],
        );
        fixture.repayments.putRepayment(
          Repayment(
            id: 'repayment-missing-bill-item',
            repaymentType: RepaymentType.bill,
            targetType: RepaymentTargetType.bill,
            targetId: 'bill-with-orphan-item',
            repaymentDate: DateTime(2026, 7, 10),
            items: [
              RepaymentItem(
                id: 'repayment-item-missing-bill-item',
                repaymentId: 'repayment-missing-bill-item',
                billItemId: 'deleted-bill-item',
                allocated: const RepaymentAmountBreakdown(
                  principal: Money(minorUnits: 5000),
                  interest: Money(minorUnits: 50),
                  fee: Money(minorUnits: 0),
                  discount: Money(minorUnits: 0),
                ),
              ),
            ],
          ),
        );

        final result = await fixture.service.validateAndRepair(contract.id);

        expect(
          result.issues.single.type,
          ContractStatusValidationIssueType.billItemMissing,
        );
        expect(result.repairedScheduleCount, 1);
        expect(result.contractStatusChanged, isTrue);
        expect(
          fixture.installments.schedulesFor(contract.id).single.status,
          InstallmentScheduleStatus.pending,
        );
        expect(
          fixture.installments.contracts[contract.id]!.status,
          InstallmentContractStatus.active,
        );
      },
    );

    test('status repair reports bill items with mismatched contract', () async {
      final fixture = _Fixture();
      final contract = _contract(
        id: 'contract-reference-mismatch',
        status: InstallmentContractStatus.settled,
      );
      final schedule = _schedule(
        id: 'schedule-reference-mismatch',
        contractId: contract.id,
        periodNo: 1,
        status: InstallmentScheduleStatus.paid,
      );
      fixture.installments
        ..putContract(contract)
        ..putSchedules(contract.id, [schedule]);
      fixture.bills.bills['bill-reference-mismatch'] = Bill(
        id: 'bill-reference-mismatch',
        accountId: contract.liabilityAccountId,
        period: BillPeriod.fromInt(202607),
        status: BillStatus.billed,
        items: [
          BillItem(
            id: 'bill-item-reference-mismatch',
            billId: 'bill-reference-mismatch',
            itemType: BillItemType.installment,
            contractId: 'another-contract',
            scheduleId: schedule.id,
            repaymentDate: schedule.expectedRepaymentDate,
            expectedPrincipal: schedule.expectedPrincipal,
            expectedInterest: schedule.expectedInterest,
            expectedFee: schedule.expectedFee,
            status: BillItemStatus.paid,
          ),
        ],
      );

      final result = await fixture.service.validateAndRepair(contract.id);

      expect(
        result.issues.single.type,
        ContractStatusValidationIssueType.billItemReferenceMismatch,
      );
      expect(result.repairedScheduleCount, 0);
      expect(result.contractStatusChanged, isFalse);
      expect(
        fixture.installments.schedulesFor(contract.id).single.status,
        InstallmentScheduleStatus.paid,
      );
    });

    test('status repair rejects allocations from another bill', () async {
      final fixture = _Fixture();
      final contract = _contract(id: 'contract-wrong-bill');
      final schedule = _schedule(
        id: 'schedule-wrong-bill',
        contractId: contract.id,
        periodNo: 1,
      );
      fixture.installments
        ..putContract(contract)
        ..putSchedules(contract.id, [schedule]);
      fixture.bills.bills['bill-correct'] = Bill(
        id: 'bill-correct',
        accountId: contract.liabilityAccountId,
        period: BillPeriod.fromInt(202607),
        status: BillStatus.billed,
        items: [
          BillItem(
            id: 'bill-item-wrong-target',
            billId: 'bill-correct',
            itemType: BillItemType.installment,
            contractId: contract.id,
            scheduleId: schedule.id,
            repaymentDate: schedule.expectedRepaymentDate,
            expectedPrincipal: schedule.expectedPrincipal,
            expectedInterest: schedule.expectedInterest,
            expectedFee: schedule.expectedFee,
            status: BillItemStatus.pending,
          ),
        ],
      );
      fixture.repayments.putRepayment(
        Repayment(
          id: 'repayment-wrong-target',
          repaymentType: RepaymentType.bill,
          targetType: RepaymentTargetType.bill,
          targetId: 'bill-other',
          repaymentDate: DateTime(2026, 7, 10),
          items: [
            RepaymentItem(
              id: 'repayment-item-wrong-target',
              repaymentId: 'repayment-wrong-target',
              billItemId: 'bill-item-wrong-target',
              allocated: const RepaymentAmountBreakdown(
                principal: Money(minorUnits: 5000),
                interest: Money(minorUnits: 50),
                fee: Money(minorUnits: 0),
                discount: Money(minorUnits: 0),
              ),
            ),
          ],
        ),
      );

      final result = await fixture.service.validateAndRepair(contract.id);

      expect(
        result.issues.single.type,
        ContractStatusValidationIssueType.repaymentTargetMismatch,
      );
      expect(result.repairedScheduleCount, 0);
      expect(
        fixture.installments.schedulesFor(contract.id).single.status,
        InstallmentScheduleStatus.pending,
      );
    });

    test(
      'status repair aggregates allocations across historical bill items',
      () async {
        final fixture = _Fixture();
        final contract = _contract(id: 'contract-aggregate');
        final schedule = _schedule(
          id: 'schedule-aggregate',
          contractId: contract.id,
          periodNo: 1,
          status: InstallmentScheduleStatus.pending,
          principal: const Money(minorUnits: 5000),
        );
        fixture.installments
          ..putContract(contract)
          ..putSchedules(contract.id, [schedule]);
        for (final entry in [
          (billId: 'bill-july', itemId: 'bill-item-july', period: 202607),
          (billId: 'bill-august', itemId: 'bill-item-august', period: 202608),
        ]) {
          fixture.bills.bills[entry.billId] = Bill(
            id: entry.billId,
            accountId: contract.liabilityAccountId,
            period: BillPeriod.fromInt(entry.period),
            status: BillStatus.billed,
            items: [
              BillItem(
                id: entry.itemId,
                billId: entry.billId,
                itemType: BillItemType.installment,
                contractId: contract.id,
                scheduleId: schedule.id,
                repaymentDate: schedule.expectedRepaymentDate,
                expectedPrincipal: schedule.expectedPrincipal,
                expectedInterest: schedule.expectedInterest,
                expectedFee: schedule.expectedFee,
                status: BillItemStatus.partiallyPaid,
              ),
            ],
          );
        }
        for (final entry in [
          (
            repaymentId: 'repayment-july',
            billId: 'bill-july',
            itemId: 'bill-item-july',
            principal: 2000,
          ),
          (
            repaymentId: 'repayment-august',
            billId: 'bill-august',
            itemId: 'bill-item-august',
            principal: 3000,
          ),
        ]) {
          fixture.repayments.putRepayment(
            Repayment(
              id: entry.repaymentId,
              repaymentType: RepaymentType.bill,
              targetType: RepaymentTargetType.bill,
              targetId: entry.billId,
              repaymentDate: DateTime(2026, 7, 10),
              items: [
                RepaymentItem(
                  id: '${entry.repaymentId}-item',
                  repaymentId: entry.repaymentId,
                  billItemId: entry.itemId,
                  allocated: RepaymentAmountBreakdown(
                    principal: Money(minorUnits: entry.principal),
                    interest: Money.zero(),
                    fee: Money.zero(),
                    discount: Money.zero(),
                  ),
                ),
              ],
            ),
          );
        }

        final result = await fixture.service.validateAndRepair(contract.id);

        expect(result.repairedScheduleCount, 1);
        expect(result.contractStatusChanged, isTrue);
        expect(result.issues, isEmpty);
        expect(
          fixture.installments.schedulesFor(contract.id).single.status,
          InstallmentScheduleStatus.paid,
        );
        expect(
          fixture.installments.contracts[contract.id]!.status,
          InstallmentContractStatus.settled,
        );
      },
    );

    test('status repair marks underpaid schedules partially paid', () async {
      final fixture = _Fixture();
      final contract = _contract(id: 'contract-partial');
      final schedule = _schedule(
        id: 'schedule-partial',
        contractId: contract.id,
        periodNo: 1,
        principal: const Money(minorUnits: 5000),
      );
      fixture.installments
        ..putContract(contract)
        ..putSchedules(contract.id, [schedule]);
      fixture.bills.bills['bill-partial'] = Bill(
        id: 'bill-partial',
        accountId: contract.liabilityAccountId,
        period: BillPeriod.fromInt(202607),
        status: BillStatus.billed,
        items: [
          BillItem(
            id: 'bill-item-partial',
            billId: 'bill-partial',
            itemType: BillItemType.installment,
            contractId: contract.id,
            scheduleId: schedule.id,
            repaymentDate: schedule.expectedRepaymentDate,
            expectedPrincipal: schedule.expectedPrincipal,
            expectedInterest: schedule.expectedInterest,
            expectedFee: schedule.expectedFee,
            status: BillItemStatus.partiallyPaid,
          ),
        ],
      );
      fixture.repayments.putRepayment(
        Repayment(
          id: 'repayment-partial',
          repaymentType: RepaymentType.bill,
          targetType: RepaymentTargetType.bill,
          targetId: 'bill-partial',
          repaymentDate: DateTime(2026, 7, 10),
          items: [
            RepaymentItem(
              id: 'repayment-item-partial',
              repaymentId: 'repayment-partial',
              billItemId: 'bill-item-partial',
              allocated: const RepaymentAmountBreakdown(
                principal: Money(minorUnits: 2000),
                interest: Money(minorUnits: 50),
                fee: Money(minorUnits: 0),
                discount: Money(minorUnits: 0),
              ),
            ),
          ],
        ),
      );

      await fixture.service.validateAndRepair(contract.id);

      expect(
        fixture.installments.schedulesFor(contract.id).single.status,
        InstallmentScheduleStatus.partiallyPaid,
      );
      expect(
        fixture.installments.contracts[contract.id]!.status,
        InstallmentContractStatus.active,
      );
    });
  });
}

InstallmentContract _contract({
  required String id,
  InstallmentContractStatus status = InstallmentContractStatus.active,
}) {
  return InstallmentContract(
    id: id,
    liabilityAccountId: 'loan-liability',
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 120000),
    borrowingDate: DateTime(2026, 6, 1),
    status: status,
    createdAt: DateTime(2026, 6, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: '$id:stage:1',
      totalPeriods: 2,
      firstDate: DateTime(2026, 7, 10),
      lastDate: DateTime(2026, 9, 10),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.daily,
      feeMinor: 0,
    ),
  );
}

InstallmentSchedule _schedule({
  required String id,
  required String contractId,
  required int periodNo,
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
  Money principal = const Money(minorUnits: 5000),
  Money interest = const Money(minorUnits: 50),
}) {
  return InstallmentSchedule(
    id: id,
    contractId: contractId,
    periodNo: periodNo,
    expectedRepaymentDate: DateTime(2026, 6 + periodNo, 10),
    expectedPrincipal: principal,
    expectedInterest: interest,
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 6, 1),
  );
}

class _FailAfterSavingInstallments extends DriftInstallmentRepository {
  _FailAfterSavingInstallments(super.database);

  @override
  Future<void> saveAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) async {
    await super.saveAggregate(contract, schedules);
    expect(
      (await findContract(contract.id))!.status,
      InstallmentContractStatus.active,
    );
    expect(
      (await listSchedules(contract.id)).map((row) => row.status),
      everyElement(InstallmentScheduleStatus.pending),
    );
    throw StateError('failure after saving repaired statuses');
  }
}

class _Fixture {
  final installments = _FakeInstallmentRepository();
  final bills = _FakeBillRepository();
  final repayments = _FakeRepaymentRepository();
  late final service = InstallmentStatusRepairAppService(
    installments: installments,
    bills: bills,
    repayments: repayments,
    transactionRunner: const _ImmediateRunner(),
  );
}

class _ImmediateRunner implements TransactionRunner {
  const _ImmediateRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _FakeInstallmentRepository implements InstallmentRepository {
  final contracts = <String, InstallmentContract>{};
  final _schedules = <String, List<InstallmentSchedule>>{};

  void putContract(InstallmentContract contract) =>
      contracts[contract.id] = contract;

  void putSchedules(String contractId, List<InstallmentSchedule> schedules) {
    _schedules[contractId] = [...schedules];
  }

  List<InstallmentSchedule> schedulesFor(String contractId) => [
    ...?_schedules[contractId],
  ];

  @override
  Future<InstallmentContract?> findContract(String id) async => contracts[id];

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) async =>
      schedulesFor(contractId);

  @override
  Future<void> saveAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) async {
    putContract(contract);
    putSchedules(contract.id, schedules);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBillRepository implements BillRepository {
  final bills = <String, Bill>{};

  @override
  Future<List<Bill>> listBillsByAccount(String accountId) async =>
      bills.values.where((bill) => bill.accountId == accountId).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepaymentRepository implements RepaymentRepository {
  final repayments = <String, Repayment>{};
  final items = <String, List<RepaymentItem>>{};

  void putRepayment(Repayment repayment) {
    repayments[repayment.id] = repayment;
    items[repayment.id] = [...repayment.items];
  }

  @override
  Future<Repayment?> findRepayment(String repaymentId) async =>
      repayments[repaymentId];

  @override
  Future<List<Repayment>> listByTarget(
    RepaymentTargetType targetType,
    String targetId,
  ) async => repayments.values
      .where((r) => r.targetType == targetType && r.targetId == targetId)
      .toList();

  @override
  Future<List<RepaymentItem>> listItemsByBillItem(String billItemId) async => [
    for (final repaymentItems in items.values)
      for (final item in repaymentItems)
        if (item.billItemId == billItemId) item,
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
