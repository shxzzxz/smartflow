import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/service/installment/installment_origination_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

void main() {
  test(
    'disbursement and bill conversion share contract schedule origination',
    () {
      const service = InstallmentOriginationService();
      var scheduleId = 0;
      String nextScheduleId() => 'schedule-${++scheduleId}';
      final terms = InstallmentOriginationTerms(
        principal: const Money(minorUnits: 10000),
        totalPeriods: 2,
        borrowingDate: _borrowingDate,
        firstRepaymentDate: _firstDate,
        lastRepaymentDate: _lastDate,
        repaymentMethod: InstallmentRepaymentMethod.flatFee,
        interestAccrualMethod: InterestAccrualMethod.monthly,
        totalFeeMinor: 200,
      );

      final disbursement = service.originateDisbursement(
        contractId: 'disbursement',
        liabilityAccountId: 'loan',
        disbursementAccountId: 'cash',
        disbursementTransactionId: 'borrowing',
        terms: terms,
        createdAt: _createdAt,
        newScheduleId: nextScheduleId,
      );
      final conversion = service.originateBillConversion(
        contractId: 'conversion',
        bill: _bill(),
        sourceRepaymentId: 'repayment',
        principal: const Money(minorUnits: 10000),
        totalPeriods: 2,
        borrowingDate: _borrowingDate,
        firstRepaymentDate: _firstDate,
        lastRepaymentDate: _lastDate,
        repaymentMethod: InstallmentRepaymentMethod.flatFee,
        interestAccrualMethod: InterestAccrualMethod.monthly,
        totalFeeMinor: 200,
        createdAt: _createdAt,
        newScheduleId: nextScheduleId,
      );

      for (final result in [disbursement, conversion]) {
        expect(result.schedules, hasLength(2));
        expect(
          result.schedules.fold<int>(
            0,
            (sum, schedule) => sum + schedule.expectedPrincipal.minorUnits,
          ),
          10000,
        );
        expect(
          result.schedules.fold<int>(
            0,
            (sum, schedule) => sum + schedule.expectedFee.minorUnits,
          ),
          200,
        );
      }
      expect(
        disbursement.contract.sourceType,
        InstallmentSourceType.disbursement,
      );
      expect(
        conversion.contract.sourceType,
        InstallmentSourceType.billConversion,
      );
      expect(conversion.contract.sourceRepaymentId, 'repayment');
    },
  );
}

final _borrowingDate = DateTime(2026, 1, 1);
final _firstDate = DateTime(2026, 2, 1);
final _lastDate = DateTime(2026, 3, 1);
final _createdAt = DateTime(2026, 1, 1);

Bill _bill() {
  return Bill(
    id: 'bill',
    accountId: 'credit',
    period: BillPeriod(year: 2026, month: 1),
    status: BillStatus.billed,
    items: const [],
  );
}
