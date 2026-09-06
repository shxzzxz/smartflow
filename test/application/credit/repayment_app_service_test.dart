import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart' as credit;
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart' as ledger;
import 'package:smartflow/application/ledger/ledger_query_api.dart'
    as ledger_query;
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';

import '../../helper/sequential_id_generator.dart';
import '../../helper/test_app_database.dart';

void main() {
  group('RepaymentAppService', () {
    for (final editPath in ['metadata', 'account', 'bill']) {
      for (final failRepaymentWrite in [false, true]) {
        test(
          '$editPath time edit ${failRepaymentWrite ? 'rolls back both sides on failure' : 'persists both sides'}',
          () async {
            final fixture = _Fixture();
            addTearDown(fixture.close);
            await fixture.seedBill(
              status: credit.BillStatus.billed,
              itemType: credit.BillItemType.consumption,
              expectedPrincipal: 1000,
            );
            final original = DateTime(2026, 6, 20, 10, 11, 12);
            final updated = DateTime(2026, 6, 21, 14, 15, 16);
            final result = await fixture.service.createBillRepayment(
              credit.CreateBillRepaymentCommand(
                billId: 'bill-1',
                allocations: [
                  _allocation(billItemId: 'bill-item-1', principal: 1000),
                ],
                transactionInfo: credit.RepaymentTransactionInfo(
                  paidFromAccountId: 'cash-1',
                  occurredAt: original,
                ),
              ),
            );
            expect(
              (await fixture.repayments.findRepayment(
                result.repaymentId,
              ))!.repaymentDate,
              original,
            );
            fixture.transactionQuery.details['tx-current'] = _transactionDetail(
              transactionId: 'tx-current',
              occurredAt: original,
            );
            await fixture.database.customStatement(
              '''
INSERT INTO transactions
(id, business_purpose, occurred_at, posted_at, primary_amount_minor, source_kind)
VALUES ('tx-current', 'debtRepayment', ?, ?, 1000, 'manual')
''',
              [
                original.millisecondsSinceEpoch ~/ 1000,
                original.millisecondsSinceEpoch ~/ 1000,
              ],
            );
            // The ledger port participates in the same database, including its
            // own nested transaction. A subsequent repayment failure must undo it.
            Future<void> writeLedgerTime(
              DateTime time,
            ) => fixture.database.transaction(() async {
              await fixture.database.customStatement(
                "UPDATE transactions SET occurred_at = ? WHERE id = 'tx-current'",
                [time.millisecondsSinceEpoch ~/ 1000],
              );
            });
            fixture.update.onUpdateBasicInfo = (command) =>
                writeLedgerTime(command.occurredAt!);
            fixture.edit.onEditRepayment = (command) =>
                writeLedgerTime(command.occurredAt!);
            final beforeItems = await fixture.database
                .select(fixture.database.repaymentItems)
                .get();
            if (failRepaymentWrite) {
              await fixture.database.customStatement('''
CREATE TRIGGER fail_repayment_item_write BEFORE INSERT ON repayment_items
BEGIN SELECT RAISE(ABORT, 'repayment write failed'); END
''');
            }
            Future<void> editTime() async {
              if (editPath == 'bill') {
                await fixture.service.editBillRepayment(
                  credit.EditBillRepaymentCommand(
                    repaymentId: result.repaymentId,
                    allocations: [
                      _allocation(billItemId: 'bill-item-1', principal: 800),
                    ],
                    transactionInfo: credit.RepaymentTransactionInfo(
                      paidFromAccountId: 'bank-1',
                      occurredAt: updated,
                    ),
                  ),
                );
              } else {
                await fixture.service.editRepaymentTransaction(
                  credit.EditCreditRepaymentTransactionCommand(
                    transactionId: result.transactionId,
                    occurredAt: updated,
                    paidFromAccountId: editPath == 'account' ? 'bank-1' : null,
                  ),
                );
              }
            }

            if (failRepaymentWrite) {
              await expectLater(editTime(), throwsA(isA<Exception>()));
            } else {
              await editTime();
            }
            final expected = failRepaymentWrite ? original : updated;
            final repayment = (await fixture.repayments.findRepayment(
              result.repaymentId,
            ))!;
            final transaction = await fixture.database
                .select(fixture.database.transactions)
                .getSingle();
            expect(repayment.repaymentDate, expected);
            expect(transaction.occurredAt, expected);
            expect(transaction.postedAt, original);
            expect(
              repayment.totalAllocated().principal.minorUnits,
              !failRepaymentWrite && editPath == 'bill' ? 800 : 1000,
            );
            if (failRepaymentWrite) {
              expect(
                await fixture.database
                    .select(fixture.database.repaymentItems)
                    .get(),
                beforeItems,
              );
            }
          },
        );
      }
    }

    test(
      'prepayment time edit saves time without recalculating schedules',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final contractId = await fixture.seedContractWithSchedules(
          principal: 90000,
          schedulePrincipals: [30000, 30000, 30000],
        );
        final result = await fixture.service.createContractPrepaymentRepayment(
          credit.CreateContractPrepaymentRepaymentCommand(
            contractId: contractId,
            amount: _amount(principal: 10000),
            transactionInfo: _transactionInfo(),
          ),
        );
        expect(
          (await fixture.repayments.findRepayment(
            result.repaymentId,
          ))!.repaymentDate,
          _transactionInfo().occurredAt,
        );
        final before = await fixture.database
            .select(fixture.database.installmentSchedules)
            .get();
        fixture.transactionQuery.details[result.transactionId!] =
            _transactionDetail(
              transactionId: result.transactionId!,
              occurredAt: _transactionInfo().occurredAt,
            );
        await fixture.service.editRepaymentTransaction(
          credit.EditCreditRepaymentTransactionCommand(
            repaymentId: result.repaymentId,
            occurredAt: DateTime(2026, 9, 1, 8, 30),
          ),
        );
        expect(
          (await fixture.repayments.findRepayment(
            result.repaymentId,
          ))!.repaymentDate,
          DateTime(2026, 9, 1, 8, 30),
        );
        expect(
          await fixture.database
              .select(fixture.database.installmentSchedules)
              .get(),
          before,
        );
      },
    );

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
          repaymentDate: DateTime(2026, 6, 20),
        ),
      );

      expect(result.transactionId, isNull);

      final repayment = await fixture.repayments.findRepayment(
        result.repaymentId,
      );
      expect(repayment!.repaymentType, credit.RepaymentType.bill);
      expect(repayment.targetId, 'bill-1');
      expect(repayment.repaymentDate, DateTime(2026, 6, 20));
      expect(repayment.items.single.billItemId, 'bill-item-1');

      final bill = await fixture.bills.findBill('bill-1');
      expect(bill!.items.single.status, credit.BillItemStatus.paid);
      expect(bill.status, credit.BillStatus.settled);
    });

    test(
      'rejects no-transaction bill repayment without a repayment date',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        await fixture.seedBill(
          status: credit.BillStatus.billed,
          itemType: credit.BillItemType.consumption,
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
              CreditErrorCode.repaymentInvalidCommand.code,
            ),
          ),
        );
      },
    );

    test('creates interest-only bill repayment with zero principal', () async {
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
            _allocation(billItemId: 'bill-item-1', principal: 0, interest: 100),
          ],
          repaymentDate: DateTime(2026, 6, 20),
        ),
      );

      final repayment = await fixture.repayments.findRepayment(
        result.repaymentId,
      );
      expect(repayment!.totalAllocated().principal, Money.zero());
      expect(repayment.totalAllocated().interest, const Money(minorUnits: 100));
      final bill = await fixture.bills.findBill('bill-1');
      expect(bill!.items.single.status, credit.BillItemStatus.partiallyPaid);
    });

    test('edits bill repayment allocations and reopens settled bill', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      await fixture.seedBill(
        status: credit.BillStatus.billed,
        itemType: credit.BillItemType.consumption,
        expectedPrincipal: 1000,
      );
      final created = await fixture.service.createBillRepayment(
        credit.CreateBillRepaymentCommand(
          billId: 'bill-1',
          allocations: [
            _allocation(billItemId: 'bill-item-1', principal: 1000),
          ],
          repaymentDate: DateTime(2026, 6, 20),
        ),
      );

      await fixture.service.editBillRepayment(
        credit.EditBillRepaymentCommand(
          repaymentId: created.repaymentId,
          allocations: [_allocation(billItemId: 'bill-item-1', principal: 500)],
          repaymentDate: DateTime(2026, 6, 22),
        ),
      );

      final repayment = await fixture.repayments.findRepayment(
        created.repaymentId,
      );
      expect(
        repayment!.totalAllocated().principal,
        const Money(minorUnits: 500),
      );
      expect(repayment.repaymentDate, DateTime(2026, 6, 22));
      final bill = await fixture.bills.findBill('bill-1');
      expect(bill!.items.single.status, credit.BillItemStatus.partiallyPaid);
      expect(bill.status, credit.BillStatus.billed);
    });

    test(
      'creates ledger transaction and marks partial bill item partially paid',
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
        expect(repayment!.repaymentDate, DateTime(2026, 6, 20));
        expect(repayment.transactionId, 'tx-current');

        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.partiallyPaid);
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
            repaymentDate: DateTime(2026, 6, 20),
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

    test(
      'marks installment schedule partially paid on partial principal',
      () async {
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
            repaymentDate: DateTime(2026, 6, 20),
          ),
        );

        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.partiallyPaid);
        expect(bill.status, credit.BillStatus.billed);
        final schedule = await fixture.installments.findSchedule(
          installment.scheduleId,
        );
        final contract = await fixture.installments.findContract(
          installment.contractId,
        );
        expect(
          schedule!.status,
          credit.InstallmentScheduleStatus.partiallyPaid,
        );
        expect(contract!.status, credit.InstallmentContractStatus.active);
      },
    );

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
          repaymentDate: DateTime(2026, 6, 20),
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
        // 分期还款无交易，以合同起算日作为它的还款日期。
        expect(repayment.repaymentDate, contract.borrowingDate);
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
      'creates no-transaction prepayment and recalculates pending schedules',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final contractId = await fixture.seedContractWithSchedules(
          principal: 120000,
          schedulePrincipals: [40000, 40000, 40000],
        );
        final schedules = await fixture.installments.listSchedules(contractId);
        schedules[0].markPaid();
        final contract = await fixture.installments.findContract(contractId);
        contract!.refreshStatusFromSchedules(schedules);
        await fixture.installments.saveAggregate(contract, schedules);
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

        final result = await fixture.service.createContractPrepaymentRepayment(
          credit.CreateContractPrepaymentRepaymentCommand(
            contractId: contractId,
            amount: _amount(principal: 20000),
            repaymentDate: DateTime(2026, 8, 1),
          ),
        );

        expect(result.transactionId, isNull);
        final repayment = await fixture.repayments.findRepayment(
          result.repaymentId,
        );
        expect(repayment!.repaymentType, credit.RepaymentType.prepayment);
        expect(repayment.targetId, contractId);
        expect(repayment.repaymentDate, DateTime(2026, 8, 1));
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
      'fee-only prepayment keeps manually revised schedules unchanged when created and deleted',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final contractId = await fixture.seedContractWithSchedules(
          principal: 120000,
          schedulePrincipals: [40000, 40000, 40000],
        );
        final contract = await fixture.installments.findContract(contractId);
        final schedules = await fixture.installments.listSchedules(contractId);
        schedules[0].reviseExpectation(
          expectedPrincipal: const Money(minorUnits: 50000),
          expectedInterest: const Money(minorUnits: 111),
        );
        schedules[1].reviseExpectation(
          expectedPrincipal: const Money(minorUnits: 30000),
          expectedInterest: const Money(minorUnits: 222),
        );
        schedules[2].reviseExpectation(
          expectedPrincipal: const Money(minorUnits: 40000),
          expectedInterest: const Money(minorUnits: 333),
        );
        await fixture.installments.saveAggregate(contract!, schedules);

        final result = await fixture.service.createContractPrepaymentRepayment(
          credit.CreateContractPrepaymentRepaymentCommand(
            contractId: contractId,
            amount: _amount(fee: 500),
            repaymentDate: DateTime(2026, 7, 1),
          ),
        );

        var unchanged = await fixture.installments.listSchedules(contractId);
        expect(unchanged.map((item) => item.expectedPrincipal.minorUnits), [
          50000,
          30000,
          40000,
        ]);
        expect(unchanged.map((item) => item.expectedInterest.minorUnits), [
          111,
          222,
          333,
        ]);

        await fixture.service.deleteRepayment(
          credit.DeleteCreditRepaymentCommand(repaymentId: result.repaymentId),
        );

        unchanged = await fixture.installments.listSchedules(contractId);
        expect(unchanged.map((item) => item.expectedPrincipal.minorUnits), [
          50000,
          30000,
          40000,
        ]);
        expect(unchanged.map((item) => item.expectedInterest.minorUnits), [
          111,
          222,
          333,
        ]);
      },
    );

    test(
      'prepayment dated after a pending schedule freezes it and recalculates '
      'only later schedules',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final contractId = await fixture.seedContractWithSchedules(
          principal: 120000,
          schedulePrincipals: [40000, 40000, 40000],
        );

        await fixture.service.createContractPrepaymentRepayment(
          credit.CreateContractPrepaymentRepaymentCommand(
            contractId: contractId,
            amount: _amount(principal: 30000),
            transactionInfo: credit.RepaymentTransactionInfo(
              paidFromAccountId: 'cash-1',
              occurredAt: DateTime(2026, 8, 1),
            ),
          ),
        );

        final recalculated = await fixture.installments.listSchedules(
          contractId,
        );
        expect(recalculated.map((schedule) => schedule.expectedPrincipal), [
          const Money(minorUnits: 40000),
          const Money(minorUnits: 25000),
          const Money(minorUnits: 25000),
        ]);
      },
    );

    test('prepayment dated after every schedule is rejected', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      final contractId = await fixture.seedContractWithSchedules(
        principal: 120000,
        schedulePrincipals: [40000, 40000, 40000],
      );

      await expectLater(
        () => fixture.service.createContractPrepaymentRepayment(
          credit.CreateContractPrepaymentRepaymentCommand(
            contractId: contractId,
            amount: _amount(principal: 30000),
            transactionInfo: credit.RepaymentTransactionInfo(
              paidFromAccountId: 'cash-1',
              occurredAt: DateTime(2027, 1, 1),
            ),
          ),
        ),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.contractInvalidCommand.code,
          ),
        ),
      );
      expect(
        await fixture.repayments.listByTarget(
          credit.RepaymentTargetType.contract,
          contractId,
        ),
        isEmpty,
      );
    });

    test(
      'creates no-transaction prepayment without skipping pending rows',
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

        final result = await fixture.service.createContractPrepaymentRepayment(
          credit.CreateContractPrepaymentRepaymentCommand(
            contractId: contractId,
            amount: _amount(principal: 80000, fee: 500),
            repaymentDate: DateTime(2026, 7, 1),
          ),
        );

        expect(result.transactionId, isNull);
        final repayment = await fixture.repayments.findRepayment(
          result.repaymentId,
        );
        expect(repayment!.repaymentType, credit.RepaymentType.prepayment);
        expect(
          repayment.items.single.allocated.fee,
          const Money(minorUnits: 500),
        );

        final settledSchedules = await fixture.installments.listSchedules(
          contractId,
        );
        expect(settledSchedules.map((schedule) => schedule.status).toSet(), {
          credit.InstallmentScheduleStatus.pending,
        });
        expect(settledSchedules.map((schedule) => schedule.expectedPrincipal), [
          const Money(minorUnits: 0),
          const Money(minorUnits: 0),
        ]);
        final contract = await fixture.installments.findContract(contractId);
        expect(contract!.status, credit.InstallmentContractStatus.active);
        final bill = await fixture.bills.findBill('bill-1');
        expect(bill!.items.single.status, credit.BillItemStatus.pending);
        expect(bill.status, credit.BillStatus.billed);
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
            amount: _amount(principal: 2000),
            transactionInfo: _transactionInfo(),
          ),
        );

        expect(result.transactionId, isNotNull);
        final repayment = await fixture.repayments.findRepayment(
          result.repaymentId,
        );
        expect(repayment!.repaymentType, credit.RepaymentType.unattributed);
        expect(repayment.repaymentDate, _transactionInfo().occurredAt);
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
          repaymentDate: DateTime(2026, 6, 20),
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
        await fixture.service.createContractPrepaymentRepayment(
          credit.CreateContractPrepaymentRepaymentCommand(
            contractId: result.contractId!,
            amount: _amount(principal: 1000),
            repaymentDate: DateTime(2026, 7, 1),
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
      'deletes prepayment and recalculates affected pending schedules',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.close);
        final contractId = await fixture.seedContractWithSchedules(
          principal: 120000,
          schedulePrincipals: [40000, 40000, 40000],
        );
        final schedules = await fixture.installments.listSchedules(contractId);
        schedules[0].markPaid();
        final contract = await fixture.installments.findContract(contractId);
        contract!.refreshStatusFromSchedules(schedules);
        await fixture.installments.saveAggregate(contract, schedules);
        final result = await fixture.service.createContractPrepaymentRepayment(
          credit.CreateContractPrepaymentRepaymentCommand(
            contractId: contractId,
            amount: _amount(principal: 80000),
            repaymentDate: DateTime(2026, 8, 1),
          ),
        );
        expect(
          (await fixture.installments.listSchedules(
            contractId,
          )).map((schedule) => schedule.status),
          [
            credit.InstallmentScheduleStatus.paid,
            credit.InstallmentScheduleStatus.pending,
            credit.InstallmentScheduleStatus.pending,
          ],
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

    test('deletes prepayment without changing historical bill items', () async {
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
      final result = await fixture.service.createContractPrepaymentRepayment(
        credit.CreateContractPrepaymentRepaymentCommand(
          contractId: contractId,
          amount: _amount(principal: 80000),
          repaymentDate: DateTime(2026, 7, 1),
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
    });

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
            amount: _amount(principal: 2000),
            transactionInfo: _transactionInfo(),
          ),
        );
        fixture.transactionQuery.details[result.transactionId!] =
            _transactionDetail(
              transactionId: result.transactionId!,
              occurredAt: DateTime(2026, 7, 1),
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
        fixture.transactionQuery.details['tx-current'] = _transactionDetail(
          transactionId: 'tx-current',
          occurredAt: DateTime(2026, 6, 20),
        );

        await fixture.service.editRepaymentTransaction(
          credit.EditCreditRepaymentTransactionCommand(
            repaymentId: result.repaymentId,
            occurredAt: DateTime(2026, 6, 21),
            note: const Patch<String?>.set('updated'),
          ),
        );
        expect(
          (await fixture.repayments.findRepayment(
            result.repaymentId,
          ))!.repaymentDate,
          DateTime(2026, 6, 21),
        );
        await fixture.service.editRepaymentTransaction(
          credit.EditCreditRepaymentTransactionCommand(
            repaymentId: result.repaymentId,
            paidFromAccountId: 'bank-1',
          ),
        );

        final basicInfo = fixture.update.basicInfoCommands.single;
        expect(basicInfo.transactionId, 'tx-current');
        expect(basicInfo.occurredAt, DateTime(2026, 6, 21));
        expect((basicInfo.note as PatchSet<String?>).value, 'updated');
        final edit = fixture.edit.repaymentCommands.single;
        expect(edit.transactionId, 'tx-current');
        expect(edit.liabilityAccountId, 'credit-1');
        expect(edit.paidFromAccountId, 'bank-1');
        expect(edit.principal, const Money(minorUnits: 1000));
        expect(edit.occurredAt, DateTime(2026, 6, 21));
        expect(
          (await fixture.repayments.findRepayment(
            result.repaymentId,
          ))!.repaymentDate,
          DateTime(2026, 6, 21),
        );
        expect(
          (edit.interest as PatchSet<Money?>).value,
          const Money(minorUnits: 50),
        );

        await fixture.service.deleteRepayment(
          credit.DeleteCreditRepaymentCommand(repaymentId: result.repaymentId),
        );

        expect(fixture.edit.deletedTransactionIds.single, 'tx-current');
      },
    );

    test(
      'rolls back ledger deletion when later credit validation fails',
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
              _allocation(billItemId: 'bill-item-1', principal: 1000),
            ],
            transactionInfo: credit.RepaymentTransactionInfo(
              paidFromAccountId: 'cash-1',
              occurredAt: DateTime(2026, 6, 20),
            ),
          ),
        );
        fixture.transactionQuery.details['tx-current'] = _transactionDetail(
          transactionId: 'tx-current',
          occurredAt: DateTime(2026, 6, 20),
        );
        await fixture.database.customStatement(
          "DELETE FROM bills WHERE id = 'bill-1'",
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
              CreditErrorCode.billNotFound.code,
            ),
          ),
        );

        expect(fixture.edit.deletedTransactionIds, ['tx-current']);
        expect(await fixture.deletedTransactionMarkerExists(), false);
        expect(
          await fixture.repayments.findRepayment(result.repaymentId),
          isNotNull,
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
              amount: _amount(principal: 2001),
              transactionInfo: _transactionInfo(),
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

    test('rejects unattributed repayment for open bill consumption', () async {
      final fixture = _Fixture();
      addTearDown(fixture.close);
      fixture.accountQuery.accounts['credit-1'] = ledger.Account(
        id: 'credit-1',
        name: 'Credit',
        type: ledger.AccountType.liability,
        balance: const Money(minorUnits: 5000),
      );
      await fixture.seedBill(
        status: credit.BillStatus.open,
        itemType: credit.BillItemType.consumption,
        expectedPrincipal: 5000,
      );

      await expectLater(
        () => fixture.service.createUnattributedRepayment(
          credit.CreateUnattributedRepaymentCommand(
            accountId: 'credit-1',
            amount: _amount(principal: 1),
            transactionInfo: _transactionInfo(),
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
    });
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
    allocated: credit.RepaymentAmountDto(
      principal: Money(minorUnits: principal),
      interest: Money(minorUnits: interest),
      fee: Money(minorUnits: fee),
      discount: Money(minorUnits: discount),
    ),
  );
}

credit.RepaymentAmountDto _amount({
  int principal = 0,
  int interest = 0,
  int fee = 0,
  int discount = 0,
}) {
  return credit.RepaymentAmountDto(
    principal: Money(minorUnits: principal),
    interest: Money(minorUnits: interest),
    fee: Money(minorUnits: fee),
    discount: Money(minorUnits: discount),
  );
}

credit.RepaymentTransactionInfo _transactionInfo() {
  return credit.RepaymentTransactionInfo(
    paidFromAccountId: 'cash-1',
    occurredAt: DateTime(2026, 7, 1),
  );
}

ledger_query.TransactionReadModel _transactionDetail({
  required String transactionId,
  required DateTime occurredAt,
}) {
  return ledger_query.TransactionReadModel.fromTransaction(
    transaction: ledger_query.Transaction(
      id: transactionId,
      businessPurpose: ledger_query.BusinessPurpose.debtRepayment,
      occurredAt: occurredAt,
      primaryAmount: const Money(minorUnits: 1050),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: ledger_query.SourceKind.manual,
    ),
    createdAt: occurredAt,
    lines: const [],
  );
}

class _Fixture {
  _Fixture() {
    runner = DriftTransactionRunner(database);
    edit.onDeleteTransaction = _recordDeletedTransactionInDatabase;
    service = credit.RepaymentAppServiceImpl(
      bills: bills,
      repayments: repayments,
      installments: installments,
      ledger: _FakeCreditLedgerPort(
        accountQuery: accountQuery,
        posting: posting,
        edit: edit,
        update: update,
        transactionQuery: transactionQuery,
      ),
      transactionRunner: runner,
      idGenerator: ids,
    );
  }

  final database = createTestDatabase();
  final ids = SequentialIdGenerator(prefix: 'repayment');
  final posting = _FakePostingService();
  final edit = _FakeEditService();
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
  late final credit.RepaymentAppService service;

  Future<void> _recordDeletedTransactionInDatabase(String transactionId) {
    return database.customStatement(
      "INSERT INTO app_metadata (key, value, updated_at) "
      "VALUES ('test.deleted_transaction', '$transactionId', 0)",
    );
  }

  Future<bool> deletedTransactionMarkerExists() async {
    final rows = await database
        .customSelect(
          "SELECT key FROM app_metadata "
          "WHERE key = 'test.deleted_transaction'",
        )
        .get();
    return rows.isNotEmpty;
  }

  Future<void> seedBill({
    required credit.BillStatus status,
    required credit.BillItemType itemType,
    required int expectedPrincipal,
  }) async {
    final installment = itemType == credit.BillItemType.installment
        ? await seedInstallmentContract(expectedPrincipal: expectedPrincipal)
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
    await bills.replaceBillItems('bill-1', [
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
    final contractId = ids.newId();
    await installments.saveContract(
      credit.InstallmentContract(
        id: contractId,
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
        totalFeeMinor: 0,
        status: credit.InstallmentContractStatus.active,
        createdAt: DateTime(2026, 6, 1),
      ),
    );
    await installments
        .saveAggregate((await installments.findContract(contractId))!, [
          credit.InstallmentSchedule(
            id: ids.newId(),
            contractId: contractId,
            periodNo: 1,
            expectedRepaymentDate: DateTime(2026, 6, 25),
            expectedPrincipal: Money(minorUnits: expectedPrincipal),
            expectedInterest: Money.zero(),
            expectedFee: Money.zero(),
            status: credit.InstallmentScheduleStatus.pending,
            createdAt: DateTime(2026, 6, 1),
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
    final contractId = ids.newId();
    await installments.saveContract(
      credit.InstallmentContract(
        id: contractId,
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
        totalFeeMinor: 0,
        status: credit.InstallmentContractStatus.active,
        createdAt: DateTime(2026, 6, 1),
      ),
    );
    await installments
        .saveAggregate((await installments.findContract(contractId))!, [
          for (var index = 0; index < schedulePrincipals.length; index++)
            credit.InstallmentSchedule(
              id: ids.newId(),
              contractId: contractId,
              periodNo: index + 1,
              expectedRepaymentDate: DateTime(
                firstDate.year,
                firstDate.month + index,
                firstDate.day,
              ),
              expectedPrincipal: Money(minorUnits: schedulePrincipals[index]),
              expectedInterest: Money.zero(),
              expectedFee: Money.zero(),
              status: credit.InstallmentScheduleStatus.pending,
              createdAt: DateTime(2026, 6, 1),
            ),
        ]);
    return contractId;
  }

  Future<void> close() => database.close();
}

class _FakeCreditLedgerPort implements CreditLedgerPort {
  const _FakeCreditLedgerPort({
    required _FakeAccountQueryService accountQuery,
    required _FakePostingService posting,
    required _FakeEditService edit,
    required _FakeUpdateService update,
    required _FakeTransactionQueryService transactionQuery,
  }) : _accountQuery = accountQuery,
       _posting = posting,
       _edit = edit,
       _update = update,
       _transactionQuery = transactionQuery;

  final _FakeAccountQueryService _accountQuery;
  final _FakePostingService _posting;
  final _FakeEditService _edit;
  final _FakeUpdateService _update;
  final _FakeTransactionQueryService _transactionQuery;

  @override
  Future<CreditLedgerAccountSnapshot?> findAccount(String accountId) async {
    final account = await _accountQuery.findAccountById(accountId);
    if (account == null) return null;
    return CreditLedgerAccountSnapshot(
      id: account.id,
      balance: account.balance,
      isArchived: account.isArchived,
    );
  }

  @override
  Future<CreditLedgerPostedTransaction> postRepayment(
    CreditLedgerPostRepaymentCommand command,
  ) async {
    final result = await _posting.createRepayment(
      ledger.CreateRepaymentCommand(
        principal: command.amount.principal,
        interest: _positiveOrNull(command.amount.interest),
        fee: _positiveOrNull(command.amount.fee),
        discount: _positiveOrNull(command.amount.discount),
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: command.ownership == null
            ? null
            : ledger.TransactionOwnership(
                ownerType: command.ownership!.ownerType,
                ownerId: command.ownership!.ownerId,
                ownerRole: command.ownership!.ownerRole,
              ),
      ),
    );
    return CreditLedgerPostedTransaction(transactionId: result.transactionId);
  }

  @override
  Future<CreditLedgerPostedTransaction> editRepayment(
    CreditLedgerEditRepaymentCommand command,
  ) async {
    final amount = command.amount;
    final result = await _edit.editRepayment(
      ledger.EditRepaymentCommand(
        transactionId: command.transactionId,
        principal: amount?.principal,
        interest: amount == null
            ? null
            : Patch<Money?>.set(_positiveOrNull(amount.interest)),
        fee: amount == null
            ? null
            : Patch<Money?>.set(_positiveOrNull(amount.fee)),
        discount: amount == null
            ? null
            : Patch<Money?>.set(_positiveOrNull(amount.discount)),
        liabilityAccountId: command.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        occurredAt: command.occurredAt,
        note: command.note,
      ),
    );
    return CreditLedgerPostedTransaction(transactionId: result.transactionId);
  }

  @override
  Future<void> updateBasicInfo(CreditLedgerUpdateBasicInfoCommand command) {
    return _update.updateBasicInfo(
      ledger.UpdateTransactionBasicInfoCommand(
        transactionId: command.transactionId,
        occurredAt: command.occurredAt,
        note: command.note,
      ),
    );
  }

  @override
  Future<void> deleteTransaction(String transactionId) {
    return _edit.deleteTransaction(
      ledger.DeleteTransactionCommand(transactionId: transactionId),
    );
  }

  @override
  Future<CreditLedgerTransactionSnapshot?> findParentTransaction(
    String transactionId,
  ) async {
    final detail = await _transactionQuery.findParentTransactionDetail(
      transactionId,
    );
    if (detail == null) return null;
    return CreditLedgerTransactionSnapshot(
      transactionId: detail.id,
      occurredAt: detail.occurredAt,
    );
  }

  @override
  Future<CreditLedgerRepaymentSnapshot?> findRepaymentTransaction(
    String transactionId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> editBorrowing(CreditLedgerEditBorrowingCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<CreditLedgerPostedTransaction> postBorrowing(
    CreditLedgerPostBorrowingCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateOwnership({
    required String transactionId,
    required CreditLedgerOwnership ownership,
  }) {
    throw UnimplementedError();
  }

  Money? _positiveOrNull(Money value) {
    return value.minorUnits > 0 ? value : null;
  }
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

class _FakeEditService implements ledger.TransactionEditAppService {
  final deletedTransactionIds = <String>[];
  final repaymentCommands = <ledger.EditRepaymentCommand>[];
  Future<void> Function(String transactionId)? onDeleteTransaction;
  Future<void> Function(ledger.EditRepaymentCommand command)? onEditRepayment;

  @override
  Future<void> deleteTransaction(
    ledger.DeleteTransactionCommand command,
  ) async {
    deletedTransactionIds.add(command.transactionId);
    await onDeleteTransaction?.call(command.transactionId);
  }

  @override
  Future<ledger.PostedTransactionResult> editRepayment(
    ledger.EditRepaymentCommand command,
  ) async {
    repaymentCommands.add(command);
    await onEditRepayment?.call(command);
    return const ledger.PostedTransactionResult(transactionId: 'tx-current');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUpdateService implements ledger.TransactionUpdateAppService {
  final basicInfoCommands = <ledger.UpdateTransactionBasicInfoCommand>[];
  Future<void> Function(ledger.UpdateTransactionBasicInfoCommand command)?
  onUpdateBasicInfo;

  @override
  Future<ledger.PostedTransactionResult> updateBasicInfo(
    ledger.UpdateTransactionBasicInfoCommand command,
  ) async {
    basicInfoCommands.add(command);
    await onUpdateBasicInfo?.call(command);
    return const ledger.PostedTransactionResult(transactionId: 'tx-current');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTransactionQueryService
    implements ledger_query.TransactionQueryService {
  final details = <String, ledger_query.TransactionReadModel>{};

  @override
  Future<ledger_query.TransactionReadModel?> findTransactionDetail(
    String transactionId,
  ) async {
    return details[transactionId];
  }

  @override
  Future<ledger_query.TransactionReadModel?> findParentTransactionDetail(
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
    return const ledger.PostedTransactionResult(transactionId: 'tx-current');
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
