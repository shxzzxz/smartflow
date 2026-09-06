import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import '../../helper/sequential_id_generator.dart';

void main() {
  group('InstallmentAppServiceImpl', () {
    test(
      'creates disbursement contract without borrowing transaction',
      () async {
        final fixture = _Fixture();

        final result = await fixture.service.createDisbursementContract(
          _createDisbursementCommand(disbursementAccountId: null),
        );

        expect(result.disbursementTransactionId, isNull);
        expect(fixture.posting.borrowingCommands, isEmpty);
        final contract = fixture.installments.contracts[result.contractId]!;
        expect(contract.disbursementAccountId, isNull);
        expect(contract.disbursementTransactionId, isNull);
        expect(
          fixture.installments.schedulesFor(result.contractId),
          hasLength(2),
        );
      },
    );

    test(
      'marks borrowing owner when disbursement transaction is created',
      () async {
        final fixture = _Fixture();

        final result = await fixture.service.createDisbursementContract(
          _createDisbursementCommand(disbursementAccountId: 'asset-cash'),
        );

        expect(result.disbursementTransactionId, 'tx-borrowing-1');
        expect(
          fixture.posting.borrowingCommands.single.receiveAccountId,
          'asset-cash',
        );
        final ownership = fixture.update.ownershipCommands.single.ownership;
        expect(ownership.ownerType, installmentOwnerType);
        expect(ownership.ownerId, result.contractId);
        expect(
          ownership.ownerRole,
          InstallmentOwnerRole.disbursement.wireValue,
        );
      },
    );

    test(
      'uses next credit billing cycle for cash installment schedules',
      () async {
        final fixture = _Fixture();
        fixture.creditAccounts.accounts['credit-liability'] =
            CreditLiabilityAccount(
              id: 'credit-ext',
              accountId: 'credit-liability',
              kind: CreditLiabilityAccountKind.credit,
              billingDay: 5,
              repaymentDay: 25,
              billingDayToNext: true,
            );

        final result = await fixture.service.createDisbursementContract(
          _createDisbursementCommand(
            liabilityAccountId: 'credit-liability',
            disbursementAccountId: null,
            borrowingDate: DateTime(2026, 6, 4),
            firstRepaymentDate: DateTime(2026, 6, 10),
            lastRepaymentDate: DateTime(2026, 6, 10),
          ),
        );

        final contract = fixture.installments.contracts[result.contractId]!;
        expect(contract.stageTerms.firstDate, DateTime(2026, 7, 25));
        expect(contract.stageTerms.lastDate, DateTime(2026, 8, 25));
        expect(
          fixture.installments
              .schedulesFor(result.contractId)
              .map((s) => s.expectedRepaymentDate),
          [DateTime(2026, 7, 25), DateTime(2026, 8, 25)],
        );
      },
    );

    test(
      'updates parameter snapshot without recalculating schedules',
      () async {
        final fixture = _Fixture();
        fixture.installments.putContract(_contract(id: 'contract-1'));
        fixture.installments.putSchedules('contract-1', [
          _schedule(
            id: 'schedule-1',
            contractId: 'contract-1',
            periodNo: 1,
            principal: const Money(minorUnits: 5000),
            date: DateTime(2026, 7, 10),
          ),
        ]);

        await fixture.service.updateContract(
          UpdateContractCommand(
            contractId: 'contract-1',
            stageTerms: InstallmentContractTerms.singleStage(
              id: 'contract-1:stage:1',
              totalPeriods: 2,
              firstDate: DateTime(2026, 8, 10),
              lastDate: DateTime(2026, 9, 10),
              method: InstallmentRepaymentMethod.equalPrincipal,
              accrual: InterestAccrualMethod.monthly,
              feeMinor: 900,
            ),
          ),
        );

        final contract = fixture.installments.contracts['contract-1']!;
        expect(contract.stageTerms.totalPeriods, 2);
        expect(contract.stageTerms.firstDate, DateTime(2026, 8, 10));
        final schedule = fixture.installments.schedulesFor('contract-1').single;
        expect(schedule.expectedRepaymentDate, DateTime(2026, 7, 10));
        expect(schedule.expectedPrincipal, const Money(minorUnits: 5000));
      },
    );

    test(
      'explicit recalculation changes pending amounts and regenerates pending dates',
      () async {
        final fixture = _Fixture();
        fixture.installments.putContract(
          _contract(
            id: 'contract-1',
            principal: const Money(minorUnits: 10000),
            totalFeeMinor: 300,
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        fixture.installments.putSchedules('contract-1', [
          _schedule(
            id: 'schedule-1',
            contractId: 'contract-1',
            periodNo: 1,
            status: InstallmentScheduleStatus.skipped,
            principal: const Money(minorUnits: 99),
            date: DateTime(2026, 7, 10),
          ),
          _schedule(
            id: 'schedule-2',
            contractId: 'contract-1',
            periodNo: 2,
            principal: const Money(minorUnits: 1),
            fee: Money.zero(),
            date: DateTime(2026, 9, 10),
          ),
          _schedule(
            id: 'schedule-3',
            contractId: 'contract-1',
            periodNo: 3,
            principal: const Money(minorUnits: 1),
            fee: Money.zero(),
            date: DateTime(2026, 11, 10),
          ),
        ]);

        final command = RecalculateContractSchedulesCommand(
          contractId: 'contract-1',
          stageTerms: InstallmentContractTerms.singleStage(
            id: 'contract-1:stage:1',
            totalPeriods: 3,
            firstDate: DateTime(2026, 7, 10),
            lastDate: DateTime(2026, 10, 10),
            method: InstallmentRepaymentMethod.equalPrincipal,
            ratePeriod: null,
            ratePpm: null,
            accrual: InterestAccrualMethod.monthly,
            feeMinor: 500,
          ),
        );
        final preview = await fixture.service.previewContractRecalculation(
          command,
        );
        await fixture.service.recalculateContractSchedules(command);

        // 锚点是被跳过的第 1 期；其后的待还尾部按合同条款重生日期并重新分配。
        expect(preview.skip(1).map((row) => row.expectedRepaymentDate), [
          DateTime(2026, 8, 10),
          DateTime(2026, 10, 10),
        ]);
        final schedules = fixture.installments.schedulesFor('contract-1');
        expect(preview.skip(1).map((row) => row.expectedPrincipal.minorUnits), [
          4951,
          4950,
        ]);
        expect(preview.skip(1).map((row) => row.expectedFee.minorUnits), [
          250,
          250,
        ]);
        expect(schedules[0].expectedPrincipal, const Money(minorUnits: 99));
        expect(schedules[0].status, InstallmentScheduleStatus.skipped);
        expect(schedules[1].expectedPrincipal, preview[1].expectedPrincipal);
        expect(schedules[1].expectedFee, preview[1].expectedFee);
        expect(schedules[1].expectedRepaymentDate, DateTime(2026, 8, 10));
        expect(schedules[2].expectedRepaymentDate, DateTime(2026, 10, 10));
      },
    );

    test(
      'explicit recalculation fails when only skipped rows remain with principal',
      () async {
        final fixture = _Fixture();
        fixture.installments.putContract(
          _contract(
            id: 'contract-1',
            principal: const Money(minorUnits: 10000),
            repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
          ),
        );
        fixture.installments.putSchedules('contract-1', [
          _schedule(
            id: 'schedule-1',
            contractId: 'contract-1',
            periodNo: 1,
            principal: const Money(minorUnits: 5000),
            date: DateTime(2026, 7, 10),
          ),
          _schedule(
            id: 'schedule-2',
            contractId: 'contract-1',
            periodNo: 2,
            status: InstallmentScheduleStatus.skipped,
            principal: const Money(minorUnits: 1000),
            date: DateTime(2026, 8, 10),
          ),
        ]);

        await expectLater(
          fixture.service.previewContractRecalculation(
            RecalculateContractSchedulesCommand(contractId: 'contract-1'),
          ),
          throwsA(
            isA<BusinessException>().having(
              (e) => e.code,
              'code',
              CreditErrorCode.contractInvalidCommand.code,
            ),
          ),
        );
      },
    );

    test(
      'explicit recalculation regenerates pending dates from edited terms',
      () async {
        final fixture = _Fixture();
        final result = await fixture.service.createDisbursementContract(
          CreateDisbursementContractCommand(
            liabilityAccountId: 'loan-liability',
            principal: const Money(minorUnits: 120000),
            borrowingDate: DateTime(2026, 6, 14),
            stageTerms: InstallmentContractTerms.singleStage(
              id: 'stage-1',
              totalPeriods: 12,
              firstDate: DateTime(2026, 7, 12),
              method: InstallmentRepaymentMethod.interestFirst,
              accrual: InterestAccrualMethod.daily,
            ),
          ),
        );

        final preview = await fixture.service.previewContractRecalculation(
          RecalculateContractSchedulesCommand(
            contractId: result.contractId,
            stageTerms: InstallmentContractTerms.singleStage(
              id: fixture
                  .installments
                  .contracts[result.contractId]!
                  .stageTerms
                  .stages
                  .single
                  .id,
              totalPeriods: 12,
              firstDate: DateTime(2026, 8, 12),
              lastDate: DateTime(2027, 7, 12),
              method: InstallmentRepaymentMethod.interestFirst,
              ratePeriod: null,
              ratePpm: null,
              accrual: InterestAccrualMethod.daily,
              feeMinor: 0,
            ),
          ),
        );

        expect(preview, hasLength(12));
        expect(preview.first.expectedRepaymentDate, DateTime(2026, 8, 12));
        expect(preview.last.expectedRepaymentDate, DateTime(2027, 7, 12));
      },
    );

    test('manual schedule patches reject non-pending rows', () async {
      final fixture = _Fixture();
      fixture.installments.putContract(_contract(id: 'contract-1'));
      fixture.installments.putSchedules('contract-1', [
        _schedule(
          id: 'schedule-1',
          contractId: 'contract-1',
          periodNo: 1,
          status: InstallmentScheduleStatus.skipped,
        ),
      ]);

      await expectLater(
        fixture.service.updateContract(
          UpdateContractCommand(
            contractId: 'contract-1',
            schedulePatches: [
              SchedulePendingPatch(
                periodNo: 1,
                expectedPrincipal: const Money(minorUnits: 200),
              ),
            ],
          ),
        ),
        throwsA(
          isA<BusinessException>().having(
            (e) => e.code,
            'code',
            CreditErrorCode.scheduleNotPending.code,
          ),
        ),
      );
    });

    test(
      'schedule patch batch is rejected without partial persistence',
      () async {
        final fixture = _Fixture();
        fixture.installments.putContract(_contract(id: 'contract-1'));
        fixture.installments.putSchedules('contract-1', [
          _schedule(
            id: 'schedule-1',
            contractId: 'contract-1',
            periodNo: 1,
            principal: const Money(minorUnits: 5000),
          ),
          _schedule(
            id: 'schedule-2',
            contractId: 'contract-1',
            periodNo: 2,
            principal: const Money(minorUnits: 5000),
            status: InstallmentScheduleStatus.skipped,
          ),
        ]);

        await expectLater(
          fixture.service.updateContract(
            const UpdateContractCommand(
              contractId: 'contract-1',
              schedulePatches: [
                SchedulePendingPatch(
                  periodNo: 1,
                  expectedPrincipal: Money(minorUnits: 6000),
                ),
                SchedulePendingPatch(
                  periodNo: 2,
                  expectedPrincipal: Money(minorUnits: 4000),
                ),
              ],
            ),
          ),
          throwsA(
            isA<BusinessException>().having(
              (exception) => exception.code,
              'code',
              CreditErrorCode.scheduleNotPending.code,
            ),
          ),
        );
        expect(
          fixture.installments
              .schedulesFor('contract-1')
              .first
              .expectedPrincipal,
          const Money(minorUnits: 5000),
        );
      },
    );

    test('skips and restores pending schedules', () async {
      final fixture = _Fixture();
      fixture.installments.putContract(_contract(id: 'contract-1'));
      fixture.installments.putSchedules('contract-1', [
        _schedule(id: 'schedule-1', contractId: 'contract-1', periodNo: 1),
      ]);

      await fixture.service.skipSchedule(
        const SkipInstallmentScheduleCommand(
          contractId: 'contract-1',
          scheduleId: 'schedule-1',
        ),
      );
      expect(
        fixture.installments.schedulesFor('contract-1').single.status,
        InstallmentScheduleStatus.skipped,
      );

      await fixture.service.restoreSchedule(
        const RestoreInstallmentScheduleCommand(
          contractId: 'contract-1',
          scheduleId: 'schedule-1',
        ),
      );
      expect(
        fixture.installments.schedulesFor('contract-1').single.status,
        InstallmentScheduleStatus.pending,
      );
    });

    test(
      'status validation reopens a paid schedule without repayment facts',
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

        final result = await fixture.service.validateContractStatuses(
          ValidateContractStatusesCommand(contractId: contract.id),
        );

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
      'status validation preserves skipped schedules and reports allocations',
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

        final result = await fixture.service.validateContractStatuses(
          ValidateContractStatusesCommand(contractId: contract.id),
        );

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
      'status validation leaves schedules unchanged for orphan allocations',
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

        final result = await fixture.service.validateContractStatuses(
          ValidateContractStatusesCommand(contractId: contract.id),
        );

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
      'status validation reports zero allocations without changing status',
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

        final result = await fixture.service.validateContractStatuses(
          ValidateContractStatusesCommand(contractId: contract.id),
        );

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

    test('status validation reports contracts without schedules', () async {
      final fixture = _Fixture();
      final contract = _contract(id: 'contract-without-schedules');
      fixture.installments
        ..putContract(contract)
        ..putSchedules(contract.id, const []);

      final result = await fixture.service.validateContractStatuses(
        ValidateContractStatusesCommand(contractId: contract.id),
      );

      expect(result.repairedScheduleCount, 0);
      expect(result.contractStatusChanged, isFalse);
      expect(
        result.issues.single.type,
        ContractStatusValidationIssueType.noSchedules,
      );
    });

    test(
      'status validation reports bill items with missing schedules',
      () async {
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

        final result = await fixture.service.validateContractStatuses(
          ValidateContractStatusesCommand(contractId: contract.id),
        );

        expect(
          result.issues.single.type,
          ContractStatusValidationIssueType.scheduleMissing,
        );
        expect(result.contractStatusChanged, isFalse);
      },
    );

    test(
      'status validation reports missing bill items without blocking known facts',
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

        final result = await fixture.service.validateContractStatuses(
          ValidateContractStatusesCommand(contractId: contract.id),
        );

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

    test(
      'status validation reports bill items with mismatched contract',
      () async {
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

        final result = await fixture.service.validateContractStatuses(
          ValidateContractStatusesCommand(contractId: contract.id),
        );

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
      },
    );

    test('status validation rejects allocations from another bill', () async {
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

      final result = await fixture.service.validateContractStatuses(
        ValidateContractStatusesCommand(contractId: contract.id),
      );

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
      'status validation aggregates allocations across historical bill items',
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

        final result = await fixture.service.validateContractStatuses(
          ValidateContractStatusesCommand(contractId: contract.id),
        );

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

    test(
      'status validation marks underpaid schedules partially paid',
      () async {
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

        await fixture.service.validateContractStatuses(
          ValidateContractStatusesCommand(contractId: contract.id),
        );

        expect(
          fixture.installments.schedulesFor(contract.id).single.status,
          InstallmentScheduleStatus.partiallyPaid,
        );
        expect(
          fixture.installments.contracts[contract.id]!.status,
          InstallmentContractStatus.active,
        );
      },
    );

    test(
      'deletes source transaction but rejects contracts with prepayments',
      () async {
        final fixture = _Fixture();
        fixture.installments
          ..putContract(
            _contract(id: 'with-tx', disbursementTransactionId: 'tx-borrowing'),
          )
          ..putContract(_contract(id: 'with-repayment'))
          ..putContract(_contract(id: 'deletable'));
        fixture.repayments.putRepayment(
          Repayment(
            id: 'repayment-1',
            repaymentType: RepaymentType.prepayment,
            targetType: RepaymentTargetType.contract,
            targetId: 'with-repayment',
            transactionId: 'tx-repay',
            repaymentDate: DateTime(2026, 1, 1),
            items: [
              RepaymentItem(
                id: 'repayment-item-1',
                repaymentId: 'repayment-1',
                allocated: const RepaymentAmountBreakdown(
                  principal: Money(minorUnits: 1000),
                  interest: Money(minorUnits: 0),
                  fee: Money(minorUnits: 0),
                  discount: Money(minorUnits: 0),
                ),
                createdAt: DateTime(2026, 6, 1),
              ),
            ],
            createdAt: DateTime(2026, 6, 1),
          ),
        );

        await fixture.service.deleteContract(
          const DeleteContractCommand(contractId: 'with-tx'),
        );
        await expectLater(
          fixture.service.deleteContract(
            const DeleteContractCommand(contractId: 'with-repayment'),
          ),
          throwsA(isA<BusinessException>()),
        );
        await fixture.service.deleteContract(
          const DeleteContractCommand(contractId: 'deletable'),
        );

        expect(fixture.installments.contracts.containsKey('with-tx'), false);
        expect(fixture.ledger.deletedTransactionIds, ['tx-borrowing']);
        expect(
          fixture.installments.contracts.containsKey('with-repayment'),
          true,
        );
        expect(fixture.installments.contracts.containsKey('deletable'), false);
      },
    );
  });
}

CreateDisbursementContractCommand _createDisbursementCommand({
  String liabilityAccountId = 'loan-liability',
  String? disbursementAccountId,
  DateTime? borrowingDate,
  DateTime? firstRepaymentDate,
  DateTime? lastRepaymentDate,
}) {
  return CreateDisbursementContractCommand(
    liabilityAccountId: liabilityAccountId,
    disbursementAccountId: disbursementAccountId,
    principal: const Money(minorUnits: 120000),
    borrowingDate: borrowingDate ?? DateTime(2026, 6, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'stage-1',
      totalPeriods: 2,
      firstDate: firstRepaymentDate ?? DateTime(2026, 7, 10),
      lastDate: lastRepaymentDate ?? DateTime(2026, 9, 10),
      method: InstallmentRepaymentMethod.equalPrincipal,
      feeMinor: 1200,
      accrual: InterestAccrualMethod.daily,
    ),
  );
}

InstallmentContract _contract({
  required String id,
  Money principal = const Money(minorUnits: 120000),
  int totalPeriods = 2,
  int totalFeeMinor = 0,
  InstallmentRepaymentMethod repaymentMethod =
      InstallmentRepaymentMethod.equalPrincipal,
  InstallmentContractStatus status = InstallmentContractStatus.active,
  String? disbursementTransactionId,
}) {
  return InstallmentContract(
    id: id,
    liabilityAccountId: 'loan-liability',
    sourceType: InstallmentSourceType.disbursement,
    disbursementAccountId: disbursementTransactionId == null
        ? null
        : 'asset-cash',
    disbursementTransactionId: disbursementTransactionId,
    principal: principal,
    borrowingDate: DateTime(2026, 6, 1),
    status: status,
    createdAt: DateTime(2026, 6, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: '$id:stage:1',
      totalPeriods: totalPeriods,
      firstDate: DateTime(2026, 7, 10),
      lastDate: DateTime(2026, 9, 10),
      method: repaymentMethod,
      accrual: InterestAccrualMethod.daily,
      feeMinor: totalFeeMinor,
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
  Money? fee,
  DateTime? date,
}) {
  return InstallmentSchedule(
    id: id,
    contractId: contractId,
    periodNo: periodNo,
    expectedRepaymentDate: date ?? DateTime(2026, 6 + periodNo, 10),
    expectedPrincipal: principal,
    expectedInterest: interest,
    expectedFee: fee ?? Money.zero(),
    status: status,
    createdAt: DateTime(2026, 6, 1),
  );
}

class _Fixture {
  final installments = _FakeInstallmentRepository();
  final repayments = _FakeRepaymentRepository();
  final bills = _FakeBillRepository();
  final creditAccounts = _FakeCreditAccountRepository();
  final posting = _FakePostingService();
  final edit = _FakeEditService();
  final update = _FakeUpdateService();
  final query = _FakeTransactionQueryService();
  late final ledger = _FakeCreditLedgerPort(
    posting: posting,
    edit: edit,
    update: update,
  );

  late final InstallmentAppService service = InstallmentAppServiceImpl(
    repository: installments,
    bills: bills,
    creditAccounts: creditAccounts,
    ledger: ledger,
    repayments: repayments,
    transactionRunner: const _ImmediateRunner(),
    idGenerator: SequentialIdGenerator(prefix: 'contract-test'),
  );
}

class _FakeBillRepository implements BillRepository {
  final bills = <String, Bill>{};

  @override
  Future<Bill?> findBill(String billId) async => bills[billId];

  @override
  Future<Bill?> findByAccountAndPeriod(
    String accountId,
    BillPeriod period,
  ) async {
    return bills.values
        .where((bill) => bill.accountId == accountId && bill.period == period)
        .firstOrNull;
  }

  @override
  Future<bool> hasUnsettledItems(String accountId) async => false;

  @override
  Future<List<Bill>> listBillsByAccount(String accountId) async {
    return bills.values.where((bill) => bill.accountId == accountId).toList();
  }

  @override
  Future<void> replaceBillItems(String billId, List<BillItem> items) async {
    final bill = bills[billId];
    if (bill == null) return;
    if (bill.status == BillStatus.open) {
      bill.refreshOpenProjection(window: bill.window!, sourceItems: items);
    } else {
      bill.synchronizeBilledItems(items);
    }
  }

  @override
  Future<Bill> saveBill(Bill bill) async {
    bills[bill.id] = bill;
    return bill;
  }

  @override
  Future<void> updateBill(Bill bill) async {
    bills[bill.id] = bill;
  }

  @override
  Future<void> deleteBill(String billId) async {
    bills.remove(billId);
  }
}

class _ImmediateRunner implements TransactionRunner {
  const _ImmediateRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _FakeCreditAccountRepository implements CreditAccountRepository {
  final accounts = <String, CreditLiabilityAccount>{};

  @override
  Future<CreditLiabilityAccount?> findByAccountId(String accountId) async {
    return accounts[accountId];
  }

  @override
  Future<List<CreditLiabilityAccount>> listAll() async =>
      accounts.values.toList();

  @override
  Stream<Map<String, CreditLiabilityAccount>> watchByAccountId() {
    return Stream.value(accounts);
  }

  @override
  Future<void> insert(CreditLiabilityAccountDraft draft) async {
    accounts[draft.accountId] = CreditLiabilityAccount(
      id: draft.id,
      accountId: draft.accountId,
      kind: draft.kind,
      creditLimit: draft.creditLimit,
      billingDay: draft.billingDay,
      repaymentDay: draft.repaymentDay,
      billingDayToNext: draft.billingDayToNext,
    );
  }

  @override
  Future<void> delete(String accountId) async {
    accounts.remove(accountId);
  }

  @override
  Future<void> update(
    String accountId,
    CreditLiabilityAccountPersistencePatch patch,
  ) async {}
}

class _FakeInstallmentRepository implements InstallmentRepository {
  final contracts = <String, InstallmentContract>{};
  final _schedules = <String, List<InstallmentSchedule>>{};

  void putContract(InstallmentContract contract) {
    contracts[contract.id] = contract;
  }

  void putSchedules(String contractId, List<InstallmentSchedule> schedules) {
    _schedules[contractId] = [...schedules];
  }

  List<InstallmentSchedule> schedulesFor(String contractId) {
    return [...?_schedules[contractId]]
      ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
  }

  @override
  Future<InstallmentContract?> findContract(String id) async => contracts[id];

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    return contracts.values
        .where((contract) => contract.liabilityAccountId == liabilityAccountId)
        .toList();
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) async {
    return schedulesFor(contractId);
  }

  @override
  Future<List<InstallmentSchedule>> listSchedulesByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    final result = <InstallmentSchedule>[];
    for (final contract in contracts.values) {
      if (contract.liabilityAccountId == liabilityAccountId) {
        result.addAll(schedulesFor(contract.id));
      }
    }
    return result;
  }

  @override
  Future<InstallmentSchedule?> findSchedule(String scheduleId) async {
    for (final schedules in _schedules.values) {
      for (final schedule in schedules) {
        if (schedule.id == scheduleId) return schedule;
      }
    }
    return null;
  }

  @override
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    String transactionId,
  ) async {
    for (final contract in contracts.values) {
      if (contract.disbursementTransactionId == transactionId) return contract;
    }
    return null;
  }

  @override
  Future<void> saveContract(InstallmentContract contract) async {
    contracts[contract.id] = contract;
  }

  @override
  Future<void> insertAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) async {
    contracts[contract.id] = contract;
    _schedules[contract.id] = [...schedules];
  }

  @override
  Future<void> saveAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) async {
    contracts[contract.id] = contract;
    _schedules[contract.id] = [...schedules];
  }

  @override
  Future<void> deleteContract(String contractId) async {
    contracts.remove(contractId);
    _schedules.remove(contractId);
  }
}

class _FakeRepaymentRepository implements RepaymentRepository {
  final repayments = <String, Repayment>{};
  final items = <String, List<RepaymentItem>>{};

  void putRepayment(Repayment repayment) {
    repayments[repayment.id] = repayment;
    items[repayment.id] = [...repayment.items];
  }

  @override
  Future<Repayment?> findRepayment(String repaymentId) async {
    return repayments[repaymentId];
  }

  @override
  Future<Repayment?> findByTransaction(String transactionId) async {
    for (final repayment in repayments.values) {
      if (repayment.transactionId == transactionId) {
        return repayment;
      }
    }
    return null;
  }

  @override
  Future<List<Repayment>> listByTarget(
    RepaymentTargetType targetType,
    String targetId,
  ) async {
    return repayments.values
        .where((r) => r.targetType == targetType && r.targetId == targetId)
        .toList();
  }

  @override
  Future<List<Repayment>> listByContract(String contractId) async {
    return repayments.values
        .where(
          (repayment) =>
              repayment.targetType == RepaymentTargetType.contract &&
              repayment.targetId == contractId,
        )
        .toList();
  }

  @override
  Future<List<RepaymentItem>> listItems(String repaymentId) async {
    return [...?items[repaymentId]];
  }

  @override
  Future<List<RepaymentItem>> listItemsByBillItem(String billItemId) async {
    return [
      for (final repaymentItems in items.values)
        for (final item in repaymentItems)
          if (item.billItemId == billItemId) item,
    ];
  }

  @override
  Future<Map<String, RepaymentAmountBreakdown>> aggregateItemsByBillItemIds(
    Iterable<String> billItemIds,
  ) async {
    final result = <String, RepaymentAmountBreakdown>{};
    for (final billItemId in billItemIds.toSet()) {
      final allocations = await listItemsByBillItem(billItemId);
      if (allocations.isEmpty) continue;
      result[billItemId] = allocations.fold(
        RepaymentAmountBreakdown.zero,
        (sum, item) => sum + item.allocated,
      );
    }
    return result;
  }

  @override
  Future<void> saveRepayment(Repayment repayment) async {
    putRepayment(repayment);
  }

  @override
  Future<void> updateRepayment(Repayment repayment) async {
    putRepayment(repayment);
  }

  @override
  Future<void> deleteRepayment(String repaymentId) async {
    repayments.remove(repaymentId);
    items.remove(repaymentId);
  }
}

class _FakePostingService implements TransactionPostingAppService {
  final borrowingCommands = <CreateBorrowingCommand>[];

  @override
  Future<PostedTransactionResult> createBorrowing(
    CreateBorrowingCommand command,
  ) async {
    borrowingCommands.add(command);
    final id = 'tx-borrowing-${borrowingCommands.length}';
    return PostedTransactionResult(transactionId: id);
  }

  @override
  Future<PostedTransactionResult> createRepayment(
    CreateRepaymentCommand command,
  ) async {
    return const PostedTransactionResult(transactionId: 'tx-repay');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCreditLedgerPort implements CreditLedgerPort {
  _FakeCreditLedgerPort({
    required _FakePostingService posting,
    required _FakeEditService edit,
    required _FakeUpdateService update,
  }) : _posting = posting,
       _edit = edit,
       _update = update;

  final _FakePostingService _posting;
  final _FakeEditService _edit;
  final _FakeUpdateService _update;
  final deletedTransactionIds = <String>[];

  @override
  Future<CreditLedgerPostedTransaction> postBorrowing(
    CreditLedgerPostBorrowingCommand command,
  ) async {
    final result = await _posting.createBorrowing(
      CreateBorrowingCommand(
        amount: command.amount,
        liabilityAccountId: command.liabilityAccountId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
      ),
    );
    return CreditLedgerPostedTransaction(transactionId: result.transactionId);
  }

  @override
  Future<void> updateOwnership({
    required String transactionId,
    required CreditLedgerOwnership ownership,
  }) {
    return _update.updateOwnership(
      UpdateTransactionOwnershipCommand(
        transactionId: transactionId,
        ownership: TransactionOwnership(
          ownerType: ownership.ownerType,
          ownerId: ownership.ownerId,
          ownerRole: ownership.ownerRole,
        ),
      ),
    );
  }

  @override
  Future<void> editBorrowing(CreditLedgerEditBorrowingCommand command) {
    return _edit.editBorrowing(
      EditBorrowingCommand(
        transactionId: command.transactionId,
        receiveAccountId: command.receiveAccountId,
        occurredAt: command.occurredAt,
      ),
    );
  }

  @override
  Future<CreditLedgerPostedTransaction> editRepayment(
    CreditLedgerEditRepaymentCommand command,
  ) async {
    final result = await _edit.editRepayment(
      EditRepaymentCommand(
        transactionId: command.transactionId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
      ),
    );
    return CreditLedgerPostedTransaction(transactionId: result.transactionId);
  }

  @override
  Future<void> updateBasicInfo(CreditLedgerUpdateBasicInfoCommand command) {
    return _update.updateBasicInfo(
      UpdateTransactionBasicInfoCommand(
        transactionId: command.transactionId,
        occurredAt: command.occurredAt,
        note: command.note,
      ),
    );
  }

  @override
  Future<CreditLedgerAccountSnapshot?> findAccount(String accountId) {
    throw UnimplementedError();
  }

  @override
  Future<CreditLedgerTransactionSnapshot?> findParentTransaction(
    String transactionId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CreditLedgerRepaymentSnapshot?> findRepaymentTransaction(
    String transactionId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    deletedTransactionIds.add(transactionId);
  }

  @override
  Future<CreditLedgerPostedTransaction> postRepayment(
    CreditLedgerPostRepaymentCommand command,
  ) {
    throw UnimplementedError();
  }
}

class _FakeEditService implements TransactionEditAppService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUpdateService implements TransactionUpdateAppService {
  final ownershipCommands = <UpdateTransactionOwnershipCommand>[];

  @override
  Future<PostedTransactionResult> updateOwnership(
    UpdateTransactionOwnershipCommand command,
  ) async {
    ownershipCommands.add(command);
    return PostedTransactionResult(transactionId: command.transactionId);
  }

  @override
  Future<PostedTransactionResult> updateBasicInfo(
    UpdateTransactionBasicInfoCommand command,
  ) async {
    return PostedTransactionResult(transactionId: command.transactionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionQueryService implements TransactionQueryService {
  @override
  Future<int> getLineAmountSum({
    required Iterable<String> transactionIds,
    required TransactionRole role,
  }) async {
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
