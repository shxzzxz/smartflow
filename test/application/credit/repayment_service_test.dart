import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart' as credit;
import 'package:smartflow/application/ledger/ledger_command_api.dart' as ledger;
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
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

class _Fixture {
  _Fixture() {
    runner = DriftTransactionRunner(database);
    service = credit.RepaymentServiceImpl(
      bills: bills,
      repayments: repayments,
      installments: installments,
      postingService: posting,
      transactionRunner: runner,
      idGenerator: ids,
    );
  }

  final database = createTestDatabase();
  final ids = SequentialIdGenerator(prefix: 'repayment');
  final posting = _FakePostingService();
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

  Future<void> close() => database.close();
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
