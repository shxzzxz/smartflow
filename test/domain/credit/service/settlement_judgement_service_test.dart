import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/service/settlement/settlement_judgement_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

void main() {
  const service = SettlementJudgementService();

  group('SettlementJudgementService', () {
    test(
      'keeps an interest-only item pending without repayment allocation',
      () {
        final status = service.judgeBillItem(
          expectedPrincipalMinor: 0,
          allocatedPrincipalMinor: 0,
          hasAllocation: false,
          hasExpectedRepayment: true,
        );

        expect(status, BillItemStatus.pending);
      },
    );

    test('settles an entirely empty item without repayment allocation', () {
      final status = service.judgeBillItem(
        expectedPrincipalMinor: 0,
        allocatedPrincipalMinor: 0,
        hasAllocation: false,
        hasExpectedRepayment: false,
      );

      expect(status, BillItemStatus.paid);
    });

    test('settles a zero-principal item after repayment allocation exists', () {
      final status = service.judgeBillItem(
        expectedPrincipalMinor: 0,
        allocatedPrincipalMinor: 0,
        hasAllocation: true,
        hasExpectedRepayment: true,
      );

      expect(status, BillItemStatus.paid);
    });

    test('keeps a schedule with remaining principal pending', () {
      final status = service.judgeScheduleFromRepayment(
        expectedPrincipalMinor: 2000,
        allocatedPrincipalMinor: 0,
        hasAllocation: false,
        hasExpectedRepayment: true,
      );

      expect(status, InstallmentScheduleStatus.pending);
    });

    test('settles an entirely empty schedule without allocation', () {
      final status = service.judgeScheduleFromRepayment(
        expectedPrincipalMinor: 0,
        allocatedPrincipalMinor: 0,
        hasAllocation: false,
        hasExpectedRepayment: false,
      );

      expect(status, InstallmentScheduleStatus.paid);
    });
  });
}
