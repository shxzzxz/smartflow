import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

void main() {
  group('Repayment', () {
    test('summarizes allocated parts', () {
      final repayment = Repayment(
        id: 'repayment-1',
        repaymentType: RepaymentType.bill,
        targetType: RepaymentTargetType.bill,
        targetId: 'bill-1',
        rootTransactionId: 'tx-1',
        items: [
          _item(
            id: 'item-1',
            repaymentId: 'repayment-1',
            billItemId: 'bill-item-1',
            principal: 1000,
            interest: 100,
          ),
          _item(
            id: 'item-2',
            repaymentId: 'repayment-1',
            billItemId: 'bill-item-2',
            principal: 500,
            fee: 50,
            discount: 20,
          ),
        ],
      );

      expect(
        repayment.totalAllocated(),
        const RepaymentAmountBreakdown(
          principal: Money(minorUnits: 1500),
          interest: Money(minorUnits: 100),
          fee: Money(minorUnits: 50),
          discount: Money(minorUnits: 20),
        ),
      );
      repayment.validateAgainstLedgerTransaction(repayment.totalAllocated());
    });

    test('rejects mismatched target type', () {
      expect(
        () => Repayment(
          id: 'repayment-1',
          repaymentType: RepaymentType.bill,
          targetType: RepaymentTargetType.account,
          targetId: 'account-1',
          items: [
            _item(
              id: 'item-1',
              repaymentId: 'repayment-1',
              billItemId: 'bill-item-1',
            ),
          ],
        ),
        throwsA(_creditInvalidCommand()),
      );
    });

    test('rejects installment repayment with ledger transaction', () {
      expect(
        () => Repayment(
          id: 'repayment-1',
          repaymentType: RepaymentType.installment,
          targetType: RepaymentTargetType.bill,
          targetId: 'bill-1',
          rootTransactionId: 'tx-1',
          items: [
            _item(
              id: 'item-1',
              repaymentId: 'repayment-1',
              billItemId: 'bill-item-1',
            ),
          ],
        ),
        throwsA(_creditInvalidCommand()),
      );
    });

    test('rejects unattributed repayment without ledger transaction', () {
      expect(
        () => Repayment(
          id: 'repayment-1',
          repaymentType: RepaymentType.unattributed,
          targetType: RepaymentTargetType.account,
          targetId: 'account-1',
          items: [_item(id: 'item-1', repaymentId: 'repayment-1')],
        ),
        throwsA(_creditInvalidCommand()),
      );
    });

    test('rejects contract level repayment item pointing to bill item', () {
      expect(
        () => Repayment(
          id: 'repayment-1',
          repaymentType: RepaymentType.prepayment,
          targetType: RepaymentTargetType.contract,
          targetId: 'contract-1',
          items: [
            _item(
              id: 'item-1',
              repaymentId: 'repayment-1',
              billItemId: 'bill-item-1',
            ),
          ],
        ),
        throwsA(_creditInvalidCommand()),
      );
    });
  });
}

RepaymentItem _item({
  required String id,
  required String repaymentId,
  String? billItemId,
  int principal = 1000,
  int interest = 0,
  int fee = 0,
  int discount = 0,
}) {
  return RepaymentItem(
    id: id,
    repaymentId: repaymentId,
    billItemId: billItemId,
    allocated: RepaymentAmountBreakdown(
      principal: Money(minorUnits: principal),
      interest: Money(minorUnits: interest),
      fee: Money(minorUnits: fee),
      discount: Money(minorUnits: discount),
    ),
  );
}

Matcher _creditInvalidCommand() {
  return isA<BusinessException>().having(
    (exception) => exception.code,
    'code',
    CreditErrorCode.repaymentInvalidCommand.code,
  );
}
