import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/transaction/presentation/reimbursement_edit_form_presentation.dart';

void main() {
  group('reimbursementCloseGapMessage', () {
    const outstanding = Money(minorUnits: 6000);

    test('describes reimbursement gap income', () {
      expect(
        reimbursementCloseGapMessage(
          amountText: '70',
          outstandingBeforeTransaction: outstanding,
        ),
        '多收 10.00（计入报销差额收入）',
      );
    });

    test('describes reimbursement gap expense', () {
      expect(
        reimbursementCloseGapMessage(
          amountText: '50',
          outstandingBeforeTransaction: outstanding,
        ),
        '少收 10.00（计入原报销支出分类）',
      );
    });

    test('omits hint for equal or invalid amount', () {
      expect(
        reimbursementCloseGapMessage(
          amountText: '60',
          outstandingBeforeTransaction: outstanding,
        ),
        isNull,
      );
      expect(
        reimbursementCloseGapMessage(
          amountText: 'invalid',
          outstandingBeforeTransaction: outstanding,
        ),
        isNull,
      );
    });
  });

  group('validateReimbursementReceiveAccount', () {
    test('allows an empty account only for a zero amount close', () {
      expect(
        validateReimbursementReceiveAccount(
          isClose: true,
          amountText: '0',
          accountId: null,
        ),
        isNull,
      );
      expect(
        validateReimbursementReceiveAccount(
          isClose: true,
          amountText: '1',
          accountId: null,
        ),
        '请选择账户',
      );
      expect(
        validateReimbursementReceiveAccount(
          isClose: false,
          amountText: '1',
          accountId: null,
        ),
        '请选择账户',
      );
    });
  });
}
