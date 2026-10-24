import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/transaction/presentation/advance_edit_form_presentation.dart';

void main() {
  group('advanceSettlementGapMessage', () {
    const outstanding = Money(minorUnits: 6000);

    test('describes advance gap income', () {
      expect(
        advanceSettlementGapMessage(
          amountText: '70',
          outstandingBeforeTransaction: outstanding,
        ),
        '多收 10.00（计入垫付补偿）',
      );
    });

    test('describes advance gap expense', () {
      expect(
        advanceSettlementGapMessage(
          amountText: '50',
          outstandingBeforeTransaction: outstanding,
        ),
        '少收 10.00（计入自承担支出分类）',
      );
    });

    test('omits hint for equal or invalid amount', () {
      expect(
        advanceSettlementGapMessage(
          amountText: '60',
          outstandingBeforeTransaction: outstanding,
        ),
        isNull,
      );
      expect(
        advanceSettlementGapMessage(
          amountText: 'invalid',
          outstandingBeforeTransaction: outstanding,
        ),
        isNull,
      );
    });
  });

  group('validateAdvanceReceiveAccount', () {
    test('allows an empty account only for a zero amount close', () {
      expect(
        validateAdvanceReceiveAccount(
          isClose: true,
          amountText: '0',
          accountId: null,
        ),
        isNull,
      );
      expect(
        validateAdvanceReceiveAccount(
          isClose: true,
          amountText: '1',
          accountId: null,
        ),
        '请选择账户',
      );
      expect(
        validateAdvanceReceiveAccount(
          isClose: false,
          amountText: '1',
          accountId: null,
        ),
        '请选择账户',
      );
    });
  });
}
