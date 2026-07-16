import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/service/settlement/settlement_judgement_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';

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
  });
}
