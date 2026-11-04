import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/credit/service/installment/installment_transaction_fact_policy.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

void main() {
  test('resolves installment-owned transaction facts', () {
    expect(
      resolveInstallmentTransactionFactKind(
        installmentType: InstallmentType.purchase,
        businessPurpose: BusinessPurpose.dailyExpense,
      ),
      InstallmentTransactionFactKind.purchase,
    );
    expect(
      resolveInstallmentTransactionFactKind(
        installmentType: InstallmentType.disbursement,
        businessPurpose: BusinessPurpose.borrowing,
      ),
      InstallmentTransactionFactKind.disbursement,
    );
    expect(
      resolveInstallmentTransactionFactKind(
        installmentType: InstallmentType.purchase,
        businessPurpose: BusinessPurpose.refund,
      ),
      InstallmentTransactionFactKind.refund,
    );
  });

  test('rejects transaction purposes outside the installment activity', () {
    expect(
      resolveInstallmentTransactionFactKind(
        installmentType: InstallmentType.purchase,
        businessPurpose: BusinessPurpose.transfer,
      ),
      isNull,
    );
  });
}
