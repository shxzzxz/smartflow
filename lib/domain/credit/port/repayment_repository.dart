import '../entity/repayment.dart';
import '../valobj/repayment_amount_breakdown.dart';
import '../valobj/repayment_enums.dart';

abstract interface class RepaymentRepository {
  Future<Repayment?> findRepayment(String repaymentId);

  Future<Repayment?> findByTransaction(String transactionId);

  Future<List<Repayment>> listByTarget(
    RepaymentTargetType targetType,
    String targetId,
  );

  Future<List<RepaymentItem>> listItems(String repaymentId);

  Future<List<RepaymentItem>> listItemsByBillItem(String billItemId);

  Future<Map<String, RepaymentAmountBreakdown>> aggregateItemsByBillItemIds(
    Iterable<String> billItemIds,
  );

  Future<void> saveRepayment(Repayment repayment);

  Future<void> replaceRepaymentItems(
    String repaymentId,
    List<RepaymentItem> items,
  );

  Future<void> deleteRepayment(String repaymentId);
}
