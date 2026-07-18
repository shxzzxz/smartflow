import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/presentation/bill_repayment_presentation.dart';

void main() {
  test('formats bill repayment date and amount breakdown', () {
    final repayment = BillRepaymentReadModel(
      id: 'repayment',
      repaymentType: RepaymentType.bill,
      allocated: const RepaymentAmountDto(
        principal: Money(minorUnits: 200),
        interest: Money(minorUnits: 200),
        fee: Money(minorUnits: 200),
        discount: Money(minorUnits: 0),
      ),
      displayTime: DateTime(2026, 7, 17),
      timeSource: BillRepaymentTimeSource.transaction,
    );

    expect(billRepaymentDateText(repayment), '还款日 2026-07-17');
    expect(billRepaymentBreakdownText(repayment), '本 2.00 息 2.00 费 2.00');
  });
}
