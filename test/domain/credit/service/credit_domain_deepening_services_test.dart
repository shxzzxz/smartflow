import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/debt/credit_debt_bucket_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

void main() {
  group('RepaymentPolicyService', () {
    const policy = RepaymentPolicyService();

    test('open bill repayment only accepts consumption item allocations', () {
      final bill = _bill(
        status: BillStatus.open,
        items: [
          _billItem(id: 'consumption', type: BillItemType.consumption),
          _billItem(
            id: 'installment',
            type: BillItemType.installment,
            scheduleId: 'schedule',
          ),
        ],
      );

      expect(
        () => policy.validateBillRepayment(
          bill: bill,
          allocations: [
            BillRepaymentAllocationDraft(
              billItemId: 'installment',
              allocated: _breakdown(principal: 100),
            ),
          ],
        ),
        throwsA(isA<BusinessException>()),
      );

      policy.validateBillRepayment(
        bill: bill,
        allocations: [
          BillRepaymentAllocationDraft(
            billItemId: 'consumption',
            allocated: _breakdown(principal: 100),
          ),
        ],
      );
    });

    test(
      'bill conversion installment only accepts pending consumption principal',
      () {
        final bill = _bill(
          status: BillStatus.billed,
          items: [_billItem(id: 'consumption', type: BillItemType.consumption)],
        );

        expect(
          () => policy.validateBillConversionInstallment(
            bill: bill,
            allocations: [
              BillRepaymentAllocationDraft(
                billItemId: 'consumption',
                allocated: _breakdown(principal: 100, interest: 1),
              ),
            ],
            totalPeriods: 1,
            firstRepaymentDate: null,
            lastRepaymentDate: null,
            interestRatePeriod: null,
            interestRatePpm: null,
            totalFeeMinor: 0,
            equalInstallmentOverrideMinor: null,
          ),
          throwsA(isA<BusinessException>()),
        );

        policy.validateBillConversionInstallment(
          bill: bill,
          allocations: [
            BillRepaymentAllocationDraft(
              billItemId: 'consumption',
              allocated: _breakdown(principal: 100),
            ),
          ],
          totalPeriods: 1,
          firstRepaymentDate: null,
          lastRepaymentDate: null,
          interestRatePeriod: null,
          interestRatePpm: null,
          totalFeeMinor: 0,
          equalInstallmentOverrideMinor: null,
        );
      },
    );
  });

  group('CreditDebtBucketService', () {
    test(
      'computes bill, future contract and unattributed debt buckets',
      () async {
        const service = CreditDebtBucketService();
        final bills = _FakeBillRepository([
          _bill(
            status: BillStatus.billed,
            items: [
              _billItem(id: 'consumption', type: BillItemType.consumption),
            ],
          ),
        ]);
        final installments = _FakeInstallmentRepository([
          _schedule(id: 'future-schedule', principal: 4000),
        ]);
        final repayments = _FakeRepaymentRepository([
          Repayment(
            id: 'repayment',
            repaymentType: RepaymentType.bill,
            targetType: RepaymentTargetType.bill,
            targetId: 'bill',
            items: [
              RepaymentItem(
                id: 'item',
                repaymentId: 'repayment',
                billItemId: 'consumption',
                allocated: _breakdown(principal: 2000),
              ),
            ],
          ),
        ]);

        final buckets = await service.bucketsForAccount(
          accountId: 'account',
          liabilityBalance: const Money(minorUnits: 10000),
          bills: bills,
          installments: installments,
          repayments: repayments,
        );

        expect(buckets.billDebt, const Money(minorUnits: 3000));
        expect(buckets.futureContractDebt, const Money(minorUnits: 4000));
        expect(buckets.unattributedDebt, const Money(minorUnits: 3000));
      },
    );

    test('counts open bill consumption outside unattributed debt', () async {
      const service = CreditDebtBucketService();
      final bills = _FakeBillRepository([
        _bill(
          status: BillStatus.open,
          items: [
            _billItem(id: 'open-consumption', type: BillItemType.consumption),
          ],
        ),
      ]);
      const installments = _FakeInstallmentRepository([]);
      const repayments = _FakeRepaymentRepository([]);

      final buckets = await service.bucketsForAccount(
        accountId: 'account',
        liabilityBalance: const Money(minorUnits: 8000),
        bills: bills,
        installments: installments,
        repayments: repayments,
      );

      expect(buckets.billDebt, const Money(minorUnits: 5000));
      expect(buckets.unattributedDebt, const Money(minorUnits: 3000));
    });
  });

  group('InstallmentLifecycleService', () {
    const service = InstallmentLifecycleService();

    test(
      'aligns credit-account disbursement schedules to bill repayment dates',
      () {
        final account = CreditLiabilityAccount(
          id: 'extension',
          accountId: 'account',
          kind: CreditLiabilityAccountKind.credit,
          billingDay: 5,
          repaymentDay: 25,
          billingDayToNext: true,
        );

        final bounds = service.cycleScheduleBoundsForDisbursement(
          account,
          borrowingDate: DateTime(2026, 6, 1),
          totalPeriods: 3,
        );

        expect(bounds!.first, DateTime(2026, 7, 25));
        expect(bounds.last, DateTime(2026, 9, 25));
      },
    );

    test(
      'allows source cleanup but rejects prepayments and paid schedules',
      () {
        service.validateDelete(
          repayments: const [],
          schedules: [_schedule(id: 'pending', principal: 100)],
        );

        final migrationContract = _contract(disbursementTransactionId: null);
        final repayment = Repayment(
          id: 'repayment',
          repaymentType: RepaymentType.prepayment,
          targetType: RepaymentTargetType.contract,
          targetId: migrationContract.id,
          items: [
            RepaymentItem(
              id: 'item',
              repaymentId: 'repayment',
              allocated: _breakdown(principal: 100),
            ),
          ],
        );

        expect(
          () => service.validateDelete(
            repayments: [repayment],
            schedules: const [],
          ),
          throwsA(isA<BusinessException>()),
        );

        final paid = _schedule(id: 'paid', principal: 100)..markPaid();
        expect(
          () => service.validateDelete(repayments: const [], schedules: [paid]),
          throwsA(isA<BusinessException>()),
        );
      },
    );
  });
}

RepaymentAmountBreakdown _breakdown({
  required int principal,
  int interest = 0,
  int fee = 0,
  int discount = 0,
}) {
  return RepaymentAmountBreakdown(
    principal: Money(minorUnits: principal),
    interest: Money(minorUnits: interest),
    fee: Money(minorUnits: fee),
    discount: Money(minorUnits: discount),
  );
}

Bill _bill({required BillStatus status, required List<BillItem> items}) {
  return Bill(
    id: 'bill',
    accountId: 'account',
    period: BillPeriod.fromInt(202607),
    status: status,
    items: items,
  );
}

BillItem _billItem({
  required String id,
  required BillItemType type,
  String? scheduleId,
}) {
  return BillItem(
    id: id,
    billId: 'bill',
    itemType: type,
    contractId: scheduleId == null ? null : 'contract',
    scheduleId: scheduleId,
    repaymentDate: DateTime(2026, 7, 25),
    expectedPrincipal: const Money(minorUnits: 5000),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: BillItemStatus.pending,
  );
}

InstallmentContract _contract({String? disbursementTransactionId}) {
  return InstallmentContract(
    id: 'contract',
    liabilityAccountId: 'account',
    sourceType: InstallmentSourceType.disbursement,
    disbursementAccountId: disbursementTransactionId == null ? null : 'asset',
    disbursementTransactionId: disbursementTransactionId,
    principal: const Money(minorUnits: 5000),
    totalPeriods: 1,
    borrowingDate: DateTime(2026, 6, 1),
    firstRepaymentDate: DateTime(2026, 7, 25),
    lastRepaymentDate: DateTime(2026, 7, 25),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: InterestAccrualMethod.daily,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 6, 1),
  );
}

InstallmentSchedule _schedule({required String id, required int principal}) {
  return InstallmentSchedule(
    id: id,
    contractId: 'contract',
    periodNo: 1,
    expectedRepaymentDate: DateTime(2026, 8, 25),
    expectedPrincipal: Money(minorUnits: principal),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: InstallmentScheduleStatus.pending,
    createdAt: DateTime(2026, 6, 1),
  );
}

class _FakeBillRepository implements BillRepository {
  const _FakeBillRepository(this.bills);

  final List<Bill> bills;

  @override
  Future<Bill?> findBill(String billId) async => null;

  @override
  Future<Bill?> findByAccountAndPeriod(
    String accountId,
    BillPeriod period,
  ) async {
    return null;
  }

  @override
  Future<bool> hasUnsettledItems(String accountId) async => false;

  @override
  Future<List<Bill>> listBillsByAccount(String accountId) async => bills;

  @override
  Future<void> replaceBillItems(String billId, List<BillItem> items) async {}

  @override
  Future<Bill> saveBill(Bill bill) async => bill;

  @override
  Future<void> updateBill(Bill bill) async {}

  @override
  Future<void> deleteBill(String billId) async {}
}

class _FakeInstallmentRepository implements InstallmentRepository {
  const _FakeInstallmentRepository(this.schedules);

  final List<InstallmentSchedule> schedules;

  @override
  Future<void> deleteContract(String contractId) async {}

  @override
  Future<InstallmentContract?> findContract(String id) async => null;

  @override
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    String transactionId,
  ) async {
    return null;
  }

  @override
  Future<InstallmentSchedule?> findSchedule(String scheduleId) async => null;

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    return const [];
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) async {
    return schedules;
  }

  @override
  Future<List<InstallmentSchedule>> listSchedulesByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    return schedules;
  }

  @override
  Future<void> saveContract(InstallmentContract contract) async {}

  @override
  Future<void> insertAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) async {}

  @override
  Future<void> saveAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) async {}
}

class _FakeRepaymentRepository implements RepaymentRepository {
  const _FakeRepaymentRepository(this.repayments);

  final List<Repayment> repayments;

  @override
  Future<void> deleteRepayment(String repaymentId) async {}

  @override
  Future<Repayment?> findByTransaction(String transactionId) async {
    return null;
  }

  @override
  Future<Repayment?> findRepayment(String repaymentId) async => null;

  @override
  Future<List<Repayment>> listByTarget(
    RepaymentTargetType targetType,
    String targetId,
  ) async {
    return repayments;
  }

  @override
  Future<List<RepaymentItem>> listItems(String repaymentId) async {
    return const [];
  }

  @override
  Future<List<RepaymentItem>> listItemsByBillItem(String billItemId) async {
    return [
      for (final repayment in repayments)
        for (final item in repayment.items)
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
  Future<void> replaceRepaymentItems(
    String repaymentId,
    List<RepaymentItem> items,
  ) async {}

  @override
  Future<void> saveRepayment(Repayment repayment) async {}
}
