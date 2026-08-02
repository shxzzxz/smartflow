import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/presentation/account_credit_summary_presentation.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  group('billAccountCreditSummary', () {
    test('uses warning for billed bills and danger when overdue', () {
      final billed = billAccountCreditSummary(_bill());
      final overdue = billAccountCreditSummary(_bill(overdueItemCount: 2));

      expect(billed.title, '2026年07月');
      expect(billed.status.label, '已出账');
      expect(billed.status.tone, AccountCreditSummaryTone.warning);
      expect(billed.supportingItems.map((item) => item.text), [
        '还款 07-25',
        '12 条明细',
      ]);

      expect(overdue.status.label, '已逾期');
      expect(overdue.status.tone, AccountCreditSummaryTone.danger);
      expect(overdue.supportingItems.last.text, '2 条逾期');
      expect(
        overdue.supportingItems.last.tone,
        AccountCreditSummaryTone.danger,
      );
    });

    test('uses primary for open bills and success for settled bills', () {
      expect(
        billAccountCreditSummary(_bill(status: BillStatus.open)).status.tone,
        AccountCreditSummaryTone.primary,
      );
      expect(
        billAccountCreditSummary(_bill(status: BillStatus.settled)).status.tone,
        AccountCreditSummaryTone.success,
      );
    });
  });

  group('installmentAccountCreditSummary', () {
    test('uses borrowing date as title and exposes supporting information', () {
      final presentation = installmentAccountCreditSummary(
        _contract(),
        accountKind: AccountProfileKind.credit,
      );

      expect(presentation.title, '2026年05月10日');
      expect(presentation.amount.minorUnits, 1200000);
      expect(presentation.supportingItems.map((item) => item.text), [
        '现金分期',
        '12 期',
        '等额本息',
      ]);
      expect(presentation.status.label, '进行中');
      expect(presentation.status.tone, AccountCreditSummaryTone.primary);
    });

    test('uses loan label and success for a settled loan contract', () {
      final presentation = installmentAccountCreditSummary(
        _contract(status: InstallmentContractStatus.settled),
        accountKind: AccountProfileKind.loan,
      );

      expect(presentation.supportingItems.first.text, '贷款分期');
      expect(presentation.status.label, '已结清');
      expect(presentation.status.tone, AccountCreditSummaryTone.success);
    });
  });
}

BillSummaryReadModel _bill({
  BillStatus status = BillStatus.billed,
  int overdueItemCount = 0,
}) {
  return BillSummaryReadModel(
    id: 'bill',
    accountId: 'account',
    period: BillPeriod(year: 2026, month: 7),
    status: status,
    windowRepaymentDate: DateTime(2026, 7, 25),
    expectedPrincipal: Money.zero(),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    pendingPrincipal: const Money(minorUnits: 320000),
    itemCount: 12,
    overdueItemCount: overdueItemCount,
  );
}

InstallmentContractReadModel _contract({
  InstallmentContractStatus status = InstallmentContractStatus.active,
}) {
  return InstallmentContractReadModel(
    id: 'contract',
    liabilityAccountId: 'account',
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 1200000),
    totalPeriods: 12,
    borrowingDate: DateTime(2026, 5, 10),
    firstRepaymentDate: DateTime(2026, 6, 10),
    lastRepaymentDate: DateTime(2027, 5, 10),
    repaymentMethod: InstallmentRepaymentMethod.equalInstallment,
    interestAccrualMethod: InterestAccrualMethod.monthly,
    totalFeeMinor: 0,
    status: status,
    createdAt: DateTime(2026, 5, 10),
  );
}
