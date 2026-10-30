import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_bill_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/credit/installment_statistics_change_source.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../helper/test_app_database.dart';

void main() {
  test(
    'reports only the unpaid part of a partially paid installment schedule',
    () async {
      final fixture = await _StatisticsFixture.create();
      addTearDown(fixture.close);

      final report = await fixture.nextReport();

      final contract = report.contracts.single;
      expect(contract.remainingPrincipal, const Money(minorUnits: 160000));
      expect(contract.remainingInterest, const Money(minorUnits: 2600));
      expect(contract.remainingTotal, const Money(minorUnits: 162750));
      expect(report.remainingPrincipal, const Money(minorUnits: 160000));
      expect(report.remainingInterest, const Money(minorUnits: 2600));
      expect(report.remainingTotal, const Money(minorUnits: 162750));
      expect(report.overdueTotal, const Money(minorUnits: 60550));

      expect(report.monthlyCashflow.map((month) => month.month), [
        DateTime(2026, 10),
        DateTime(2026, 11),
      ]);
      expect(
        report.monthlyCashflow.first.principal,
        const Money(minorUnits: 0),
      );
      expect(
        report.monthlyCashflow.last.principal,
        const Money(minorUnits: 100000),
      );
      expect(
        report.monthlyCashflow.last.interestAndFee,
        const Money(minorUnits: 2200),
      );
    },
  );

  test('emits a fresh report when a repayment allocation changes', () async {
    final fixture = await _StatisticsFixture.create();
    addTearDown(fixture.close);

    final initial = await fixture.nextReport();
    expect(initial.remainingTotal, const Money(minorUnits: 162750));

    await fixture.repayments.saveRepayment(
      _repayment(
        id: 'later-payment',
        billItemId: 'october-item',
        principalMinor: 10000,
        interestMinor: 100,
      ),
    );

    final refreshed = await fixture.nextReport();
    expect(refreshed.remainingPrincipal, const Money(minorUnits: 150000));
    expect(refreshed.remainingInterest, const Money(minorUnits: 2500));
    expect(refreshed.remainingTotal, const Money(minorUnits: 152650));
    expect(refreshed.overdueTotal, const Money(minorUnits: 50450));
  });
}

class _StatisticsFixture {
  _StatisticsFixture._(this.database)
    : installments = DriftInstallmentRepository(database),
      bills = DriftBillRepository(database),
      repayments = DriftRepaymentRepository(database);

  final AppDatabase database;
  final DriftInstallmentRepository installments;
  final DriftBillRepository bills;
  final DriftRepaymentRepository repayments;
  late final _reports =
      InstallmentStatisticsQueryImpl(
        installments: installments,
        bills: bills,
        repayments: repayments,
        changes: DriftInstallmentStatisticsChangeSource(database),
      ).watchStatistics(
        asOf: DateTime(2026, 10, 18),
        liabilityAccountIds: const {'loan-account'},
      );
  late final StreamIterator<InstallmentStatisticsReadModel> _iterator =
      StreamIterator(_reports);

  static Future<_StatisticsFixture> create() async {
    final database = createTestDatabase();
    final fixture = _StatisticsFixture._(database);
    await fixture._seed();
    return fixture;
  }

  Future<InstallmentStatisticsReadModel> nextReport() async {
    final hasNext = await _iterator.moveNext().timeout(
      const Duration(seconds: 5),
    );
    expect(hasNext, isTrue);
    return _iterator.current;
  }

  Future<void> close() async {
    await _iterator.cancel();
    await database.close();
  }

  Future<void> _seed() async {
    await installments.insertAggregate(
      InstallmentContract(
        id: 'contract',
        name: '消费贷',
        liabilityAccountId: 'loan-account',
        installmentType: InstallmentType.disbursement,
        principal: const Money(minorUnits: 220000),
        borrowingDate: DateTime(2026, 1, 1),
        status: InstallmentContractStatus.active,
        createdAt: DateTime(2026, 1, 1),
        stageTerms: InstallmentContractTerms(
          stages: [
            InstallmentContractStage(
              id: 'stage',
              terms: AmortizingStage(
                dates: IntervalRepaymentDates(
                  firstDate: DateTime(2026, 10, 10),
                  count: 2,
                ),
                method: InstallmentRepaymentMethod.interestFirst,
              ),
            ),
          ],
        ),
      ),
      [
        InstallmentSchedule(
          id: 'september',
          contractId: 'contract',
          periodNo: 1,
          expectedRepaymentDate: DateTime(2026, 9, 10),
          expectedPrincipal: const Money(minorUnits: 20000),
          expectedInterest: const Money(minorUnits: 200),
          expectedFee: const Money(minorUnits: 0),
          status: InstallmentScheduleStatus.paid,
          createdAt: DateTime(2026, 1, 1),
        ),
        InstallmentSchedule(
          id: 'october',
          contractId: 'contract',
          periodNo: 2,
          expectedRepaymentDate: DateTime(2026, 10, 10),
          expectedPrincipal: const Money(minorUnits: 100000),
          expectedInterest: const Money(minorUnits: 1000),
          expectedFee: const Money(minorUnits: 100),
          status: InstallmentScheduleStatus.partiallyPaid,
          createdAt: DateTime(2026, 1, 1),
        ),
        InstallmentSchedule(
          id: 'november',
          contractId: 'contract',
          periodNo: 3,
          expectedRepaymentDate: DateTime(2026, 11, 10),
          expectedPrincipal: const Money(minorUnits: 100000),
          expectedInterest: const Money(minorUnits: 2000),
          expectedFee: const Money(minorUnits: 200),
          status: InstallmentScheduleStatus.pending,
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    final bill = Bill(
      id: 'october-bill',
      accountId: 'loan-account',
      period: BillPeriod.fromDate(DateTime(2026, 10, 10)),
      status: BillStatus.billed,
      items: const [],
      createdAt: DateTime(2026, 9, 1),
    );
    await bills.saveBill(bill);
    await bills.replaceBillItems('october-bill', [
      BillItem(
        id: 'october-item',
        billId: 'october-bill',
        itemType: BillItemType.installment,
        repaymentDate: DateTime(2026, 10, 10),
        expectedPrincipal: const Money(minorUnits: 100000),
        expectedInterest: const Money(minorUnits: 1000),
        expectedFee: const Money(minorUnits: 100),
        status: BillItemStatus.partiallyPaid,
        contractId: 'contract',
        scheduleId: 'october',
      ),
    ]);
    await repayments.saveRepayment(
      _repayment(
        id: 'partial-payment',
        billItemId: 'october-item',
        principalMinor: 40000,
        interestMinor: 400,
        feeMinor: 100,
        discountMinor: 50,
      ),
    );
  }
}

Repayment _repayment({
  required String id,
  required String billItemId,
  required int principalMinor,
  required int interestMinor,
  int feeMinor = 0,
  int discountMinor = 0,
}) {
  return Repayment(
    id: id,
    repaymentType: RepaymentType.bill,
    targetType: RepaymentTargetType.bill,
    targetId: 'october-bill',
    repaymentDate: DateTime(2026, 10, 12),
    items: [
      RepaymentItem(
        id: '$id-item',
        repaymentId: id,
        billItemId: billItemId,
        allocated: RepaymentAmountBreakdown(
          principal: Money(minorUnits: principalMinor),
          interest: Money(minorUnits: interestMinor),
          fee: Money(minorUnits: feeMinor),
          discount: Money(minorUnits: discountMinor),
        ),
      ),
    ],
  );
}
