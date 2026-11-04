import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/orchestration/service/advance_transaction_fact_policy.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

void main() {
  test('resolves advance-owned transaction facts', () {
    expect(
      resolveAdvanceTransactionFactKind(BusinessPurpose.advance),
      AdvanceTransactionFactKind.advance,
    );
    expect(
      resolveAdvanceTransactionFactKind(BusinessPurpose.advanceCollection),
      AdvanceTransactionFactKind.collection,
    );
    expect(
      resolveAdvanceTransactionFactKind(BusinessPurpose.refund),
      AdvanceTransactionFactKind.refund,
    );
    expect(
      resolveAdvanceTransactionFactKind(BusinessPurpose.advanceSettlement),
      AdvanceTransactionFactKind.settlement,
    );
    expect(resolveAdvanceTransactionFactKind(BusinessPurpose.transfer), isNull);
  });
}
