import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

void main() {
  group('Bill aggregate behavior', () {
    test('applyAllocations settles items and projects bill status', () {
      final bill = Bill(
        id: 'bill',
        accountId: 'credit',
        period: BillPeriod(year: 2026, month: 7),
        status: BillStatus.billed,
        items: [
          _billItem(id: 'item-1', principalMinor: 1000),
          _billItem(id: 'item-2', principalMinor: 500, scheduleId: 'schedule'),
        ],
      );

      final result = bill.applyAllocations({
        'item-1': (principalMinor: 1000, hasAllocation: true),
        'item-2': (principalMinor: 499, hasAllocation: true),
      });

      expect(bill.items[0].status, BillItemStatus.paid);
      expect(bill.items[1].status, BillItemStatus.partiallyPaid);
      expect(bill.status, BillStatus.billed);
      expect(result.scheduleItemStatuses, {
        'schedule': BillItemStatus.partiallyPaid,
      });

      bill.applyAllocations({
        'item-2': (principalMinor: 500, hasAllocation: true),
      });

      expect(bill.items[1].status, BillItemStatus.paid);
      expect(bill.status, BillStatus.settled);
    });
  });

  group('CreditLiabilityAccount cycle behavior', () {
    test('derives current period and bill window from account parameters', () {
      final account = CreditLiabilityAccount(
        id: 'extension',
        accountId: 'credit',
        kind: CreditLiabilityAccountKind.credit,
        billingDay: 5,
        repaymentDay: 20,
        billingDayToNext: true,
      );

      expect(
        account.creditPeriodForDate(DateTime(2026, 7, 4)),
        BillPeriod(year: 2026, month: 7),
      );
      expect(
        account.creditPeriodForDate(DateTime(2026, 7, 5)),
        BillPeriod(year: 2026, month: 8),
      );

      final window = account.nextCreditBillWindow(
        BillPeriod(year: 2026, month: 7),
      );

      expect(window.startDate, DateTime(2026, 6, 5));
      expect(window.billingDate, DateTime(2026, 7, 5));
      expect(window.repaymentDate, DateTime(2026, 7, 20));
      expect(account.effectiveCreditWindowStart(window), window.startDate);
      expect(account.effectiveCreditWindowEnd(window), window.billingDate);
    });
  });

  group('Installment aggregate behavior', () {
    test('settled contract allows term revision independently of status', () {
      final contract = _contract(status: InstallmentContractStatus.settled);

      contract.reviseStageTerms(_terms(totalPeriods: 3));
      expect(contract.stageTerms.totalPeriods, 3);
      expect(contract.status, InstallmentContractStatus.settled);
    });

    test('bill conversion contract retains its source reference', () {
      final contract = _contract(
        installmentType: InstallmentType.billConversion,
        sourceRefId: 'repayment',
      );

      expect(contract.sourceRefId, 'repayment');
    });

    test('non-disbursement installment requires a source reference', () {
      expect(
        () => _contract(installmentType: InstallmentType.purchase),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.contractInvalidCommand.code,
          ),
        ),
      );
    });

    test('contract rejects schedules owned by another contract', () {
      final foreign = _schedule(
        id: 'foreign',
        contractId: 'another-contract',
        status: InstallmentScheduleStatus.pending,
      );

      expect(
        () => _contract(schedules: [foreign]),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.scheduleNotFound.code,
          ),
        ),
      );
    });

    test('invalid term revision is rejected without partial mutation', () {
      final contract = _contract();

      expect(
        () => contract.reviseStageTerms(
          _terms(
            totalPeriods: 3,
            firstDate: DateTime(2026, 4, 1),
            lastDate: DateTime(2026, 3, 1),
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
      expect(contract.stageTerms.totalPeriods, 2);
      expect(contract.stageTerms.firstDate, DateTime(2026, 2, 1));
    });

    test('negative fee revision is rejected without mutation', () {
      final contract = _contract();

      expect(
        () => contract.reviseStageTerms(_terms(feeMinor: -1)),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.contractInvalidCommand.code,
          ),
        ),
      );
      expect(contract.stageTerms.totalFeeMinor, 0);
    });

    test('negative rate revision is rejected without partial mutation', () {
      final contract = _contract(
        interestRatePeriod: InterestRatePeriod.monthly,
        interestRatePpm: 120000,
      );

      expect(
        () => contract.reviseStageTerms(
          _terms(
            totalPeriods: 3,
            ratePeriod: InterestRatePeriod.monthly,
            ratePpm: -1,
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(contract.stageTerms.totalPeriods, 2);
      expect(contract.stageTerms.repayments.first.rate?.ppm, 120000);
    });

    test('rate period and value must be revised as an atomic pair', () {
      final contract = _contract(
        interestRatePeriod: InterestRatePeriod.monthly,
        interestRatePpm: 120000,
      );

      expect(
        () => contract.reviseStageTerms(_terms(feeMinor: 100, ratePpm: 120000)),
        throwsA(isA<BusinessException>()),
      );
      expect(contract.stageTerms.totalFeeMinor, 0);
      expect(
        contract.stageTerms.repayments.first.rate?.period,
        InterestRatePeriod.monthly,
      );
      expect(contract.stageTerms.repayments.first.rate?.ppm, 120000);
    });

    test('term revision can explicitly clear nullable values', () {
      final contract = _contract(
        interestRatePeriod: InterestRatePeriod.monthly,
        interestRatePpm: 120000,
        note: 'legacy',
      );

      contract.reviseStageTerms(_terms());
      contract.reviseDetails(note: const Patch<String>.clear());

      expect(contract.stageTerms.repayments.first.rate?.period, isNull);
      expect(contract.stageTerms.repayments.first.rate?.ppm, isNull);
      expect(contract.note, isNull);
    });

    test(
      'schedule revisions reject the whole batch when a period is missing',
      () {
        final schedules = [
          _schedule(id: 's1', status: InstallmentScheduleStatus.pending),
          _schedule(id: 's2', status: InstallmentScheduleStatus.skipped),
        ];
        final contract = _contract(schedules: schedules);

        expect(
          () => contract.reviseSchedules(
            revisions: const [
              InstallmentScheduleRevision(
                periodNo: 1,
                expectedPrincipal: Money(minorUnits: 600),
              ),
              InstallmentScheduleRevision(
                periodNo: 99,
                expectedPrincipal: Money(minorUnits: 400),
              ),
            ],
          ),
          throwsA(
            isA<BusinessException>().having(
              (exception) => exception.code,
              'code',
              CreditErrorCode.scheduleNotFound.code,
            ),
          ),
        );
        expect(schedules.first.expectedPrincipal, const Money(minorUnits: 500));
      },
    );

    test('schedule status changes project contract status', () {
      final schedules = [
        _schedule(id: 's1', status: InstallmentScheduleStatus.pending),
        _schedule(id: 's2', status: InstallmentScheduleStatus.skipped),
      ];
      final contract = _contract(schedules: schedules);

      contract.markSchedulePaid(schedules.first.id);

      expect(schedules.first.status, InstallmentScheduleStatus.paid);
      expect(contract.status, InstallmentContractStatus.settled);

      contract.restoreSchedule(schedules.last.id);

      expect(schedules.last.status, InstallmentScheduleStatus.pending);
      expect(contract.status, InstallmentContractStatus.active);
    });

    test(
      'bill item statuses project through the owned schedule collection',
      () {
        final schedules = [
          _schedule(id: 's1', status: InstallmentScheduleStatus.pending),
          _schedule(id: 's2', status: InstallmentScheduleStatus.skipped),
        ];
        final contract = _contract(schedules: schedules);

        contract.applyBillItemStatuses({'s1': BillItemStatus.paid});

        expect(contract.status, InstallmentContractStatus.settled);
        expect(contract.schedules.first.status, InstallmentScheduleStatus.paid);
      },
    );
  });
}

BillItem _billItem({
  required String id,
  required int principalMinor,
  String? scheduleId,
}) {
  return BillItem(
    id: id,
    billId: 'bill',
    itemType: scheduleId == null
        ? BillItemType.consumption
        : BillItemType.installment,
    contractId: scheduleId == null ? null : 'contract',
    scheduleId: scheduleId,
    repaymentDate: DateTime(2026, 7, 20),
    expectedPrincipal: Money(minorUnits: principalMinor),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: BillItemStatus.pending,
  );
}

InstallmentContract _contract({
  InstallmentContractStatus status = InstallmentContractStatus.active,
  InstallmentType installmentType = InstallmentType.disbursement,
  String? sourceRefId,
  InterestRatePeriod? interestRatePeriod,
  int? interestRatePpm,
  String? note,
  List<InstallmentSchedule> schedules = const [],
}) {
  return InstallmentContract(
    id: 'contract',
    liabilityAccountId: 'credit',
    installmentType: installmentType,
    sourceRefId: sourceRefId,
    principal: const Money(minorUnits: 1000),
    borrowingDate: DateTime(2026, 1, 1),
    status: status,
    note: note,
    createdAt: DateTime(2026, 1, 1),
    schedules: schedules,
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'contract:stage:1',
      totalPeriods: 2,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, 3, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      ratePeriod: interestRatePeriod,
      ratePpm: interestRatePpm,
      accrual: InterestAccrualMethod.monthly,
      feeMinor: 0,
    ),
  );
}

InstallmentSchedule _schedule({
  required String id,
  required InstallmentScheduleStatus status,
  String contractId = 'contract',
  int? periodNo,
}) {
  return InstallmentSchedule(
    id: id,
    contractId: contractId,
    periodNo: periodNo ?? (id == 's1' ? 1 : 2),
    expectedRepaymentDate: DateTime(2026, id == 's1' ? 2 : 3, 1),
    expectedPrincipal: const Money(minorUnits: 500),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentContractTerms _terms({
  int totalPeriods = 2,
  DateTime? firstDate,
  DateTime? lastDate,
  int feeMinor = 0,
  InterestRatePeriod? ratePeriod,
  int? ratePpm,
}) => InstallmentContractTerms.singleStage(
  id: 'contract:stage:1',
  totalPeriods: totalPeriods,
  firstDate: firstDate ?? DateTime(2026, 2, 1),
  lastDate: lastDate,
  method: InstallmentRepaymentMethod.equalPrincipal,
  accrual: InterestAccrualMethod.monthly,
  ratePeriod: ratePeriod,
  ratePpm: ratePpm,
  feeMinor: feeMinor,
);
