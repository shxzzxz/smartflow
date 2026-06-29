import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart' as credit;
import 'package:smartflow/application/ledger/ledger_command_api.dart' as ledger;
import 'package:smartflow/application/ledger/ledger_query_api.dart'
    as ledger_query;
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';

import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  group('RepaymentService', () {
    test('creates no-transaction bill repayment and settles bill', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      await fixture.seedBill(
        status: credit.BillStatus.billed,
        itemType: credit.BillItemType.consumption,
        expectedPrincipal: 1000,
      );

      final result = await fixture.service.createBillRepayment(
        credit.CreateBillRepaymentCommand(
          billId: 'bill-1',
          allocations: [
            _allocation(billItemId: 'bill-item-1', principal: 1000),
          ],
        ),
      );

      expect(result.transactionId, isNull);
      expect(result.rootTransactionId, isNull);

      final repayment = await fixture.repayments.findRepayment(
        result.repaymentId,
      );
      expect(repayment!.repaymentType, credit.RepaymentType.bill);
      expect(repayment.targetId, 'bill-1');
      expect(repayment.items.single.billItemId, 'bill-item-1');

      final bill = await fixture.bills.findBill('bill-1');
      expect(bill!.items.single.status, credit.BillItemStatus.paid);
      expect(bill.status, credit.BillStatus.settled);
    });

    test(
      'creates ledger transaction for bill repayment and keeps partial pending',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.seedBill(
          status: credit.BillStatus.billed,
          itemType: credit.BillItemType.consumption,
          expectedPrincipal: 1000,
        );

        final result = await fixture.service.createBillRepayment(
          credit.CreateBillRepaymentCommand(
            billId: 'bill-1',
            allocations: [
              _allocation(
                billItemId: 'bill-item-1',
                principal: 400,
                interest: 20,
              ),
            ],
            transactionInfo: credit.RepaymentTransactionInfo(
              paidFromAccountId: 'cash-1',
              occurredAt: DateTime(2026, 6, 20),
              counterpartyName: 'Bank',
              note: 'partial',
            ),
          ),
        );

        expect(result.transactionId, 'tx-current');
        expect(result.rootTransactionId, 'tx-root');
        expect(
          fixture.posting.repaymentCommand!.principal,
          const Money(minorUnits: 400),
        );
        expect(
          fixture.posting.repaymentCommand!.interest,
          const Money(minorUnits: 20),
        );
        expect(
          fixture.posting.repaymentCommand!.liabilityAccountId,
          'credit-1',
        );
        expect(fixture.posting.repaymentCommand!.paidFromAccountId, 'cash-1');
        expect(
          fixture.posting.repaymentCommand!.ownership!.ownerType,
          creditRepaymentOwnerType,
        );
        expect(
          fixture.posting.repaymentCommand!.ownership!.ownerId,
          result.repaymentId,
        );
        expect(fixture.posting.repaymentCommand!.ownership!.ownerRole, 'BILL');

        final repayment = await fixture.repayments.findRepayment(
          result.repaymentId,
        );
        expect(repayment!.rootTransactionId, 'tx-root');

        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.pending);
        expect(bill.status, credit.BillStatus.billed);
      },
    );

    test(
      'rejects installment item allocation while bill is still open',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.seedBill(
          status: credit.BillStatus.open,
          itemType: credit.BillItemType.installment,
          expectedPrincipal: 1000,
        );

        await expectLater(
          () => fixture.service.createBillRepayment(
            credit.CreateBillRepaymentCommand(
              billId: 'bill-1',
              allocations: [
                _allocation(billItemId: 'bill-item-1', principal: 1000),
              ],
            ),
          ),
          throwsA(
            isA<BusinessException>().having(
              (exception) => exception.code,
              'code',
              CreditErrorCode.billInvalidCommand.code,
            ),
          ),
        );
      },
    );

    test(
      'settles bill and installment contract after cross item allocation',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final installment = await fixture.seedInstallmentContract(
          expectedPrincipal: 700,
        );
        await fixture.seedBillItems(
          status: credit.BillStatus.billed,
          items: [
            const _BillItemSeed(
              id: 'bill-item-consumption',
              itemType: credit.BillItemType.consumption,
              expectedPrincipal: 500,
            ),
            _BillItemSeed(
              id: 'bill-item-installment',
              itemType: credit.BillItemType.installment,
              expectedPrincipal: 700,
              contractId: installment.contractId,
              scheduleId: installment.scheduleId,
            ),
          ],
        );

        await fixture.service.createBillRepayment(
          credit.CreateBillRepaymentCommand(
            billId: 'bill-1',
            allocations: [
              _allocation(billItemId: 'bill-item-consumption', principal: 500),
              _allocation(billItemId: 'bill-item-installment', principal: 700),
            ],
          ),
        );

        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.map((item) => item.status).toSet(), {
          credit.BillItemStatus.paid,
        });
        expect(bill.status, credit.BillStatus.settled);
        final schedule = await fixture.installments.findSchedule(
          installment.scheduleId,
        );
        final contract = await fixture.installments.findContract(
          installment.contractId,
        );
        expect(schedule!.status, credit.InstallmentScheduleStatus.paid);
        expect(contract!.status, credit.InstallmentContractStatus.settled);
      },
    );

    test('keeps installment schedule pending on partial principal', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final installment = await fixture.seedInstallmentContract(
        expectedPrincipal: 1000,
      );
      await fixture.seedBillItems(
        status: credit.BillStatus.billed,
        items: [
          _BillItemSeed(
            id: 'bill-item-installment',
            itemType: credit.BillItemType.installment,
            expectedPrincipal: 1000,
            contractId: installment.contractId,
            scheduleId: installment.scheduleId,
          ),
        ],
      );

      await fixture.service.createBillRepayment(
        credit.CreateBillRepaymentCommand(
          billId: 'bill-1',
          allocations: [
            _allocation(billItemId: 'bill-item-installment', principal: 400),
          ],
        ),
      );

      final bill = await fixture.bills.findBill('bill-1');
      expect(bill!.items.single.status, credit.BillItemStatus.pending);
      expect(bill.status, credit.BillStatus.billed);
      final schedule = await fixture.installments.findSchedule(
        installment.scheduleId,
      );
      final contract = await fixture.installments.findContract(
        installment.contractId,
      );
      expect(schedule!.status, credit.InstallmentScheduleStatus.pending);
      expect(contract!.status, credit.InstallmentContractStatus.active);
    });

    test('allows manual principal over-allocation and settles item', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      await fixture.seedBill(
        status: credit.BillStatus.billed,
        itemType: credit.BillItemType.consumption,
        expectedPrincipal: 1000,
      );

      await fixture.service.createBillRepayment(
        credit.CreateBillRepaymentCommand(
          billId: 'bill-1',
          allocations: [
            _allocation(billItemId: 'bill-item-1', principal: 1200),
          ],
        ),
      );

      final bill = await fixture.bills.findBill('bill-1');
      expect(bill!.items.single.status, credit.BillItemStatus.paid);
      expect(bill.status, credit.BillStatus.settled);
    });

    test(
      'creates bill conversion contract and mixes with cash allocation',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.seedBill(
          status: credit.BillStatus.billed,
          itemType: credit.BillItemType.consumption,
          expectedPrincipal: 10000,
        );

        await fixture.service.createBillRepayment(
          credit.CreateBillRepaymentCommand(
            billId: 'bill-1',
            allocations: [
              _allocation(billItemId: 'bill-item-1', principal: 4000),
            ],
            transactionInfo: credit.RepaymentTransactionInfo(
              paidFromAccountId: 'cash-1',
              occurredAt: DateTime(2026, 6, 20),
            ),
          ),
        );
        final result = await fixture.service
            .createBillConversionInstallmentRepayment(
              credit.CreateBillConversionInstallmentRepaymentCommand(
                billId: 'bill-1',
                allocations: [
                  _allocation(billItemId: 'bill-item-1', principal: 6000),
                ],
                totalPeriods: 2,
                firstRepaymentDate: DateTime(2026, 7, 25),
                repaymentMethod:
                    credit.InstallmentRepaymentMethod.equalPrincipal,
              ),
            );

        expect(result.transactionId, isNull);
        expect(result.rootTransactionId, isNull);
        expect(result.contractId, isNotNull);
        final repayment = await fixture.repayments.findRepayment(
          result.repaymentId,
        );
        expect(repayment!.repaymentType, credit.RepaymentType.installment);
        expect(repayment.targetId, 'bill-1');
        expect(repayment.items.single.billItemId, 'bill-item-1');

        final contract = await fixture.installments.findContract(
          result.contractId!,
        );
        expect(
          contract!.sourceType,
          credit.InstallmentSourceType.billConversion,
        );
        expect(contract.sourceRepaymentId, result.repaymentId);
        expect(contract.principal, const Money(minorUnits: 6000));
        final schedules = await fixture.installments.listSchedules(
          result.contractId!,
        );
        expect(schedules.map((schedule) => schedule.expectedRepaymentDate), [
          DateTime(2026, 7, 25),
          DateTime(2026, 8, 25),
        ]);
        expect(schedules.map((schedule) => schedule.expectedPrincipal), [
          const Money(minorUnits: 3000),
          const Money(minorUnits: 3000),
        ]);

        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.paid);
        expect(bill.status, credit.BillStatus.settled);
      },
    );

    test(
      'creates no-transaction extra principal repayment and recalculates pending schedules',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final contractId = await fixture.seedContractWithSchedules(
          principal: 120000,
          schedulePrincipals: [40000, 40000, 40000],
        );
        final schedules = await fixture.installments.listSchedules(contractId);
        await fixture.installments.updateSchedule(
          schedules[0].id,
          const InstallmentSchedulePatch(
            status: credit.InstallmentScheduleStatus.paid,
          ),
        );
        await fixture.seedBillItems(
          status: credit.BillStatus.billed,
          items: [
            _BillItemSeed(
              id: 'bill-item-installment',
              itemType: credit.BillItemType.installment,
              expectedPrincipal: 40000,
              contractId: contractId,
              scheduleId: schedules[1].id,
            ),
          ],
        );

        final result = await fixture.service.createExtraPrincipalRepayment(
          credit.CreateExtraPrincipalRepaymentCommand(
            contractId: contractId,
            principal: const Money(minorUnits: 20000),
          ),
        );

        expect(result.transactionId, isNull);
        final repayment = await fixture.repayments.findRepayment(
          result.repaymentId,
        );
        expect(repayment!.repaymentType, credit.RepaymentType.extraPrincipal);
        expect(repayment.targetId, contractId);
        expect(repayment.items.single.billItemId, isNull);
        expect(
          repayment.items.single.allocated.principal,
          const Money(minorUnits: 20000),
        );

        final recalculated = await fixture.installments.listSchedules(
          contractId,
        );
        expect(
          recalculated[0].expectedPrincipal,
          const Money(minorUnits: 40000),
        );
        expect(
          recalculated[1].expectedPrincipal,
          const Money(minorUnits: 30000),
        );
        expect(
          recalculated[2].expectedPrincipal,
          const Money(minorUnits: 30000),
        );
        expect(
          recalculated[1].status,
          credit.InstallmentScheduleStatus.pending,
        );

        final bill = await fixture.bills.findBill('bill-1');
        expect(
          bill!.items.single.expectedPrincipal,
          const Money(minorUnits: 40000),
        );
        expect(bill.items.single.status, credit.BillItemStatus.pending);
      },
    );

    test(
      'creates no-transaction early settlement and skips pending rows',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final contractId = await fixture.seedContractWithSchedules(
          principal: 80000,
          schedulePrincipals: [40000, 40000],
        );
        final schedules = await fixture.installments.listSchedules(contractId);
        await fixture.seedBillItems(
          status: credit.BillStatus.billed,
          items: [
            _BillItemSeed(
              id: 'bill-item-installment',
              itemType: credit.BillItemType.installment,
              expectedPrincipal: 40000,
              contractId: contractId,
              scheduleId: schedules[0].id,
            ),
          ],
        );

        final result = await fixture.service.createEarlySettlementRepayment(
          credit.CreateEarlySettlementRepaymentCommand(
            contractId: contractId,
            principal: const Money(minorUnits: 80000),
            fee: const Money(minorUnits: 500),
          ),
        );

        expect(result.transactionId, isNull);
        final repayment = await fixture.repayments.findRepayment(
          result.repaymentId,
        );
        expect(repayment!.repaymentType, credit.RepaymentType.earlySettlement);
        expect(
          repayment.items.single.allocated.fee,
          const Money(minorUnits: 500),
        );

        final settledSchedules = await fixture.installments.listSchedules(
          contractId,
        );
        expect(settledSchedules.map((schedule) => schedule.status).toSet(), {
          credit.InstallmentScheduleStatus.skipped,
        });
        final contract = await fixture.installments.findContract(contractId);
        expect(contract!.status, credit.InstallmentContractStatus.closed);
        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.skipped);
        expect(bill.status, credit.BillStatus.settled);
      },
    );

    test(
      'creates unattributed repayment within bucket without touching bills or contracts',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        fixture.accountQuery.accounts['credit-1'] = ledger.Account(
          id: 'credit-1',
          name: 'Credit',
          type: ledger.AccountType.liability,
          balance: const Money(minorUnits: 5000),
        );
        final contractId = await fixture.seedContractWithSchedules(
          principal: 2000,
          schedulePrincipals: [2000],
        );
        await fixture.seedBill(
          status: credit.BillStatus.billed,
          itemType: credit.BillItemType.consumption,
          expectedPrincipal: 1000,
        );

        final result = await fixture.service.createUnattributedRepayment(
          credit.CreateUnattributedRepaymentCommand(
            accountId: 'credit-1',
            amount: const Money(minorUnits: 2000),
          ),
        );

        expect(result.transactionId, isNull);
        final repayment = await fixture.repayments.findRepayment(
          result.repaymentId,
        );
        expect(repayment!.repaymentType, credit.RepaymentType.unattributed);
        expect(repayment.targetType, credit.RepaymentTargetType.account);
        expect(repayment.targetId, 'credit-1');
        expect(repayment.items.single.billItemId, isNull);
        expect(
          repayment.items.single.allocated.principal,
          const Money(minorUnits: 2000),
        );

        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.pending);
        final schedules = await fixture.installments.listSchedules(contractId);
        expect(
          schedules.single.status,
          credit.InstallmentScheduleStatus.pending,
        );
      },
    );

    test('deletes bill repayment and reopens the bill item', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      await fixture.seedBill(
        status: credit.BillStatus.billed,
        itemType: credit.BillItemType.consumption,
        expectedPrincipal: 1000,
      );
      final result = await fixture.service.createBillRepayment(
        credit.CreateBillRepaymentCommand(
          billId: 'bill-1',
          allocations: [
            _allocation(billItemId: 'bill-item-1', principal: 1000),
          ],
        ),
      );

      await fixture.service.deleteRepayment(
        credit.DeleteCreditRepaymentCommand(repaymentId: result.repaymentId),
      );

      expect(
        await fixture.repayments.findRepayment(result.repaymentId),
        isNull,
      );
      final bill = await fixture.bills.findBill('bill-1');
      expect(bill!.items.single.status, credit.BillItemStatus.pending);
      expect(bill.status, credit.BillStatus.billed);
    });

    test(
      'deletes bill conversion repayment and cascades the created contract',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.seedBill(
          status: credit.BillStatus.billed,
          itemType: credit.BillItemType.consumption,
          expectedPrincipal: 6000,
        );
        final result = await fixture.service
            .createBillConversionInstallmentRepayment(
              credit.CreateBillConversionInstallmentRepaymentCommand(
                billId: 'bill-1',
                allocations: [
                  _allocation(billItemId: 'bill-item-1', principal: 6000),
                ],
                totalPeriods: 2,
                firstRepaymentDate: DateTime(2026, 7, 25),
                repaymentMethod:
                    credit.InstallmentRepaymentMethod.equalPrincipal,
              ),
            );

        await fixture.service.deleteRepayment(
          credit.DeleteCreditRepaymentCommand(repaymentId: result.repaymentId),
        );

        expect(
          await fixture.repayments.findRepayment(result.repaymentId),
          isNull,
        );
        expect(
          await fixture.installments.findContract(result.contractId!),
          isNull,
        );
        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.pending);
        expect(bill.status, credit.BillStatus.billed);
      },
    );

    test(
      'blocks bill conversion deletion while created contract has repayments',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.seedBill(
          status: credit.BillStatus.billed,
          itemType: credit.BillItemType.consumption,
          expectedPrincipal: 6000,
        );
        final result = await fixture.service
            .createBillConversionInstallmentRepayment(
              credit.CreateBillConversionInstallmentRepaymentCommand(
                billId: 'bill-1',
                allocations: [
                  _allocation(billItemId: 'bill-item-1', principal: 6000),
                ],
                totalPeriods: 2,
                firstRepaymentDate: DateTime(2026, 7, 25),
                repaymentMethod:
                    credit.InstallmentRepaymentMethod.equalPrincipal,
              ),
            );
        await fixture.service.createExtraPrincipalRepayment(
          credit.CreateExtraPrincipalRepaymentCommand(
            contractId: result.contractId!,
            principal: const Money(minorUnits: 1000),
          ),
        );

        await expectLater(
          () => fixture.service.deleteRepayment(
            credit.DeleteCreditRepaymentCommand(
              repaymentId: result.repaymentId,
            ),
          ),
          throwsA(
            isA<BusinessException>().having(
              (exception) => exception.code,
              'code',
              CreditErrorCode.repaymentNotEditable.code,
            ),
          ),
        );
        expect(
          await fixture.repayments.findRepayment(result.repaymentId),
          isNotNull,
        );
        expect(
          await fixture.installments.findContract(result.contractId!),
          isNotNull,
        );
      },
    );

    test(
      'deletes extra principal repayment and restores pending schedules',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final contractId = await fixture.seedContractWithSchedules(
          principal: 120000,
          schedulePrincipals: [40000, 40000, 40000],
        );
        final schedules = await fixture.installments.listSchedules(contractId);
        await fixture.installments.updateSchedule(
          schedules[0].id,
          const InstallmentSchedulePatch(
            status: credit.InstallmentScheduleStatus.paid,
          ),
        );
        final result = await fixture.service.createExtraPrincipalRepayment(
          credit.CreateExtraPrincipalRepaymentCommand(
            contractId: contractId,
            principal: const Money(minorUnits: 80000),
          ),
        );
        expect(
          (await fixture.installments.listSchedules(contractId))
              .where(
                (schedule) =>
                    schedule.status == credit.InstallmentScheduleStatus.skipped,
              )
              .length,
          2,
        );

        await fixture.service.deleteRepayment(
          credit.DeleteCreditRepaymentCommand(repaymentId: result.repaymentId),
        );

        expect(
          await fixture.repayments.findRepayment(result.repaymentId),
          isNull,
        );
        final restored = await fixture.installments.listSchedules(contractId);
        expect(restored.map((schedule) => schedule.status), [
          credit.InstallmentScheduleStatus.paid,
          credit.InstallmentScheduleStatus.pending,
          credit.InstallmentScheduleStatus.pending,
        ]);
        expect(restored.map((schedule) => schedule.expectedPrincipal), [
          const Money(minorUnits: 40000),
          const Money(minorUnits: 40000),
          const Money(minorUnits: 40000),
        ]);
      },
    );

    test(
      'deletes early settlement and restores contract schedules and bill items',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final contractId = await fixture.seedContractWithSchedules(
          principal: 80000,
          schedulePrincipals: [40000, 40000],
        );
        final schedules = await fixture.installments.listSchedules(contractId);
        await fixture.seedBillItems(
          status: credit.BillStatus.billed,
          items: [
            _BillItemSeed(
              id: 'bill-item-installment',
              itemType: credit.BillItemType.installment,
              expectedPrincipal: 40000,
              contractId: contractId,
              scheduleId: schedules[0].id,
            ),
          ],
        );
        final result = await fixture.service.createEarlySettlementRepayment(
          credit.CreateEarlySettlementRepaymentCommand(
            contractId: contractId,
            principal: const Money(minorUnits: 80000),
          ),
        );

        await fixture.service.deleteRepayment(
          credit.DeleteCreditRepaymentCommand(repaymentId: result.repaymentId),
        );

        expect(
          await fixture.repayments.findRepayment(result.repaymentId),
          isNull,
        );
        final contract = await fixture.installments.findContract(contractId);
        expect(contract!.status, credit.InstallmentContractStatus.active);
        final restored = await fixture.installments.listSchedules(contractId);
        expect(restored.map((schedule) => schedule.status).toSet(), {
          credit.InstallmentScheduleStatus.pending,
        });
        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.pending);
        expect(bill.status, credit.BillStatus.billed);
      },
    );

    test(
      'deletes unattributed repayment without touching bill or contract',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        fixture.accountQuery.accounts['credit-1'] = ledger.Account(
          id: 'credit-1',
          name: 'Credit',
          type: ledger.AccountType.liability,
          balance: const Money(minorUnits: 5000),
        );
        final contractId = await fixture.seedContractWithSchedules(
          principal: 2000,
          schedulePrincipals: [2000],
        );
        await fixture.seedBill(
          status: credit.BillStatus.billed,
          itemType: credit.BillItemType.consumption,
          expectedPrincipal: 1000,
        );
        final result = await fixture.service.createUnattributedRepayment(
          credit.CreateUnattributedRepaymentCommand(
            accountId: 'credit-1',
            amount: const Money(minorUnits: 2000),
          ),
        );

        await fixture.service.deleteRepayment(
          credit.DeleteCreditRepaymentCommand(repaymentId: result.repaymentId),
        );

        expect(
          await fixture.repayments.findRepayment(result.repaymentId),
          isNull,
        );
        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.pending);
        final schedules = await fixture.installments.listSchedules(contractId);
        expect(
          schedules.single.status,
          credit.InstallmentScheduleStatus.pending,
        );
      },
    );

    test(
      'edits repayment transaction metadata and settlement account',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.seedBill(
          status: credit.BillStatus.billed,
          itemType: credit.BillItemType.consumption,
          expectedPrincipal: 1000,
        );
        final result = await fixture.service.createBillRepayment(
          credit.CreateBillRepaymentCommand(
            billId: 'bill-1',
            allocations: [
              _allocation(
                billItemId: 'bill-item-1',
                principal: 1000,
                interest: 50,
              ),
            ],
            transactionInfo: credit.RepaymentTransactionInfo(
              paidFromAccountId: 'cash-1',
              occurredAt: DateTime(2026, 6, 20),
            ),
          ),
        );
        fixture.transactionQuery.details['tx-root'] = _transactionDetail(
          transactionId: 'tx-root',
          occurredAt: DateTime(2026, 6, 20),
        );

        await fixture.service.editRepaymentTransaction(
          credit.EditCreditRepaymentTransactionCommand(
            repaymentId: result.repaymentId,
            occurredAt: DateTime(2026, 6, 21),
            note: const Patch<String?>.set('updated'),
          ),
        );
        await fixture.service.editRepaymentTransaction(
          credit.EditCreditRepaymentTransactionCommand(
            repaymentId: result.repaymentId,
            paidFromAccountId: 'bank-1',
          ),
        );

        final basicInfo = fixture.update.basicInfoCommands.single;
        expect(basicInfo.transactionId, 'tx-root');
        expect(basicInfo.occurredAt, DateTime(2026, 6, 21));
        expect((basicInfo.note as PatchSet<String?>).value, 'updated');
        final correction = fixture.correction.repaymentCommands.single;
        expect(correction.transactionId, 'tx-root');
        expect(correction.liabilityAccountId, 'credit-1');
        expect(correction.paidFromAccountId, 'bank-1');
        expect(correction.principal, const Money(minorUnits: 1000));
        expect(
          (correction.interest as PatchSet<Money?>).value,
          const Money(minorUnits: 50),
        );
      },
    );

    test(
      'rejects unattributed repayment above unattributed debt bucket',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        fixture.accountQuery.accounts['credit-1'] = ledger.Account(
          id: 'credit-1',
          name: 'Credit',
          type: ledger.AccountType.liability,
          balance: const Money(minorUnits: 5000),
        );
        await fixture.seedContractWithSchedules(
          principal: 2000,
          schedulePrincipals: [2000],
        );
        await fixture.seedBill(
          status: credit.BillStatus.billed,
          itemType: credit.BillItemType.consumption,
          expectedPrincipal: 1000,
        );

        await expectLater(
          () => fixture.service.createUnattributedRepayment(
            credit.CreateUnattributedRepaymentCommand(
              accountId: 'credit-1',
              amount: const Money(minorUnits: 2001),
            ),
          ),
          throwsA(
            isA<BusinessException>().having(
              (exception) => exception.code,
              'code',
              CreditErrorCode.repaymentExceedsAvailable.code,
            ),
          ),
        );
      },
    );
  });
}

credit.BillRepaymentAllocation _allocation({
  required String billItemId,
  required int principal,
  int interest = 0,
  int fee = 0,
  int discount = 0,
}) {
  return credit.BillRepaymentAllocation(
    billItemId: billItemId,
    allocated: credit.RepaymentAmountBreakdown(
      principal: Money(minorUnits: principal),
      interest: Money(minorUnits: interest),
      fee: Money(minorUnits: fee),
      discount: Money(minorUnits: discount),
    ),
  );
}

ledger_query.TransactionDetail _transactionDetail({
  required String transactionId,
  required DateTime occurredAt,
}) {
  return ledger_query.TransactionDetail(
    transaction: ledger_query.Transaction(
      id: transactionId,
      rootTransactionId: transactionId,
      businessPurpose: ledger_query.BusinessPurpose.debtRepayment,
      occurredAt: occurredAt,
      primaryAmount: const Money(minorUnits: 1050),
      mutationKind: ledger_query.MutationKind.original,
      businessState: ledger_query.BusinessState.current,
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: ledger_query.SourceKind.manual,
    ),
    createdAt: occurredAt,
    details: const [],
    entries: const [],
  );
}

class _Fixture {
  _Fixture() {
    runner = DriftTransactionRunner(database);
    service = credit.RepaymentServiceImpl(
      bills: bills,
      repayments: repayments,
      installments: installments,
      accountQueryService: accountQuery,
      postingService: posting,
      correctionService: correction,
      updateService: update,
      transactionQueryService: transactionQuery,
      transactionRunner: runner,
      idGenerator: ids,
    );
  }

  final database = createTestDatabase();
  final ids = SequentialIdGenerator(prefix: 'repayment');
  final posting = _FakePostingService();
  final correction = _FakeCorrectionService();
  final update = _FakeUpdateService();
  final transactionQuery = _FakeTransactionQueryService();
  final accountQuery = _FakeAccountQueryService();
  late final TransactionRunner runner;
  late final DriftBillRepository bills = DriftBillRepository(database);
  late final DriftInstallmentRepository installments =
      DriftInstallmentRepository(database);
  late final DriftRepaymentRepository repayments = DriftRepaymentRepository(
    database,
  );
  late final credit.RepaymentService service;

  Future<void> seedBill({
    required credit.BillStatus status,
    required credit.BillItemType itemType,
    required int expectedPrincipal,
  }) async {
    final installment =
        itemType == credit.BillItemType.installment
            ? await seedInstallmentContract(
              expectedPrincipal: expectedPrincipal,
            )
            : null;
    await seedBillItems(
      status: status,
      items: [
        _BillItemSeed(
          id: 'bill-item-1',
          itemType: itemType,
          expectedPrincipal: expectedPrincipal,
          contractId: installment?.contractId,
          scheduleId: installment?.scheduleId,
        ),
      ],
    );
  }

  Future<void> seedBillItems({
    required credit.BillStatus status,
    required List<_BillItemSeed> items,
  }) async {
    final bill = Bill(
      id: 'bill-1',
      accountId: 'credit-1',
      period: credit.BillPeriod.fromInt(202606),
      status: status,
      items: const [],
    );
    await bills.saveBill(bill);
    await bills.upsertBillItems('bill-1', [
      for (final item in items)
        BillItem(
          id: item.id,
          billId: 'bill-1',
          itemType: item.itemType,
          contractId: item.contractId,
          scheduleId: item.scheduleId,
          repaymentDate: DateTime(2026, 6, 25),
          expectedPrincipal: Money(minorUnits: item.expectedPrincipal),
          expectedInterest: Money.zero(),
          expectedFee: Money.zero(),
          status: credit.BillItemStatus.pending,
        ),
    ]);
  }

  Future<({String contractId, String scheduleId})> seedInstallmentContract({
    required int expectedPrincipal,
  }) async {
    final contractId = await installments.insertContract(
      InstallmentContractDraft(
        liabilityAccountId: 'credit-1',
        sourceType: credit.InstallmentSourceType.disbursement,
        disbursementAccountId: 'cash-1',
        disbursementTransactionId: 'borrow-tx',
        principal: Money(minorUnits: expectedPrincipal),
        totalPeriods: 1,
        borrowingDate: DateTime(2026, 6, 1),
        firstRepaymentDate: DateTime(2026, 6, 25),
        lastRepaymentDate: DateTime(2026, 6, 25),
        repaymentMethod: credit.InstallmentRepaymentMethod.equalPrincipal,
        interestAccrualMethod: credit.InterestAccrualMethod.monthly,
        status: credit.InstallmentContractStatus.active,
      ),
    );
    await installments.replaceSchedules(contractId, [
      credit.InstallmentScheduleDraft(
        periodNo: 1,
        expectedRepaymentDate: DateTime(2026, 6, 25),
        expectedPrincipal: Money(minorUnits: expectedPrincipal),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
      ),
    ]);
    final schedule = (await installments.listSchedules(contractId)).single;
    return (contractId: contractId, scheduleId: schedule.id);
  }

  Future<String> seedContractWithSchedules({
    required int principal,
    required List<int> schedulePrincipals,
  }) async {
    final firstDate = DateTime(2026, 7, 25);
    final contractId = await installments.insertContract(
      InstallmentContractDraft(
        liabilityAccountId: 'credit-1',
        sourceType: credit.InstallmentSourceType.disbursement,
        disbursementAccountId: 'cash-1',
        disbursementTransactionId: 'borrow-tx',
        principal: Money(minorUnits: principal),
        totalPeriods: schedulePrincipals.length,
        borrowingDate: DateTime(2026, 6, 25),
        firstRepaymentDate: firstDate,
        lastRepaymentDate: DateTime(
          firstDate.year,
          firstDate.month + schedulePrincipals.length - 1,
          firstDate.day,
        ),
        repaymentMethod: credit.InstallmentRepaymentMethod.equalPrincipal,
        interestAccrualMethod: credit.InterestAccrualMethod.monthly,
        status: credit.InstallmentContractStatus.active,
      ),
    );
    await installments.replaceSchedules(contractId, [
      for (var index = 0; index < schedulePrincipals.length; index++)
        credit.InstallmentScheduleDraft(
          periodNo: index + 1,
          expectedRepaymentDate: DateTime(
            firstDate.year,
            firstDate.month + index,
            firstDate.day,
          ),
          expectedPrincipal: Money(minorUnits: schedulePrincipals[index]),
          expectedInterest: Money.zero(),
          expectedFee: Money.zero(),
        ),
    ]);
    return contractId;
  }

  Future<void> close() => database.close();
}

class _FakeAccountQueryService implements ledger_query.AccountQueryService {
  final accounts = <String, ledger.Account>{};

  @override
  Future<ledger.Account?> findAccountById(String id) async => accounts[id];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BillItemSeed {
  const _BillItemSeed({
    required this.id,
    required this.itemType,
    required this.expectedPrincipal,
    this.contractId,
    this.scheduleId,
  });

  final String id;
  final credit.BillItemType itemType;
  final int expectedPrincipal;
  final String? contractId;
  final String? scheduleId;
}

class _FakeCorrectionService implements ledger.TransactionCorrectionAppService {
  final deletedTransactionIds = <String>[];
  final repaymentCommands = <ledger.CorrectRepaymentCommand>[];

  @override
  Future<void> deleteTransaction(
    ledger.DeleteTransactionCommand command,
  ) async {
    deletedTransactionIds.add(command.transactionId);
  }

  @override
  Future<ledger.PostedTransactionResult> correctRepayment(
    ledger.CorrectRepaymentCommand command,
  ) async {
    repaymentCommands.add(command);
    return const ledger.PostedTransactionResult(
      transactionId: 'tx-current',
      rootTransactionId: 'tx-root',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUpdateService implements ledger.TransactionUpdateAppService {
  final basicInfoCommands = <ledger.UpdateTransactionBasicInfoCommand>[];

  @override
  Future<ledger.PostedTransactionResult> updateBasicInfo(
    ledger.UpdateTransactionBasicInfoCommand command,
  ) async {
    basicInfoCommands.add(command);
    return const ledger.PostedTransactionResult(
      transactionId: 'tx-current',
      rootTransactionId: 'tx-root',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionQueryService
    implements ledger_query.TransactionQueryService {
  final details = <String, ledger_query.TransactionDetail>{};

  @override
  Future<ledger_query.TransactionDetail?> findTransactionDetail(
    String transactionId,
  ) async {
    return details[transactionId];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePostingService implements ledger.TransactionPostingAppService {
  ledger.CreateRepaymentCommand? repaymentCommand;

  @override
  Future<ledger.PostedTransactionResult> createRepayment(
    ledger.CreateRepaymentCommand command,
  ) async {
    repaymentCommand = command;
    return const ledger.PostedTransactionResult(
      transactionId: 'tx-current',
      rootTransactionId: 'tx-root',
    );
  }

  @override
  Future<ledger.PostedTransactionResult> adjustBalance(
    ledger.AdjustBalanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ledger.PostedTransactionResult> closeReimbursement(
    ledger.CloseReimbursementCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ledger.PostedTransactionResult> createBorrowing(
    ledger.CreateBorrowingCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ledger.PostedTransactionResult> createExpense(
    ledger.CreateExpenseCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ledger.PostedTransactionResult> createIncome(
    ledger.CreateIncomeCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ledger.PostedTransactionResult> createOpeningBalance(
    ledger.CreateOpeningBalanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ledger.PostedTransactionResult> createRefund(
    ledger.CreateRefundCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ledger.PostedTransactionResult> createReimbursementAdvance(
    ledger.CreateReimbursementAdvanceCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ledger.PostedTransactionResult> createReimbursementReceipt(
    ledger.CreateReimbursementReceiptCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ledger.PostedTransactionResult> createTransfer(
    ledger.CreateTransferCommand command,
  ) {
    throw UnimplementedError();
  }
}
