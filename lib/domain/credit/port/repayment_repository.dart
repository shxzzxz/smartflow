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

  /// Lists all repayments applied to a contract, including repayments whose
  /// aggregate target is a bill but whose items allocate to this contract's
  /// bill items. Bill-target repayment items are scoped to this contract.
  Future<List<Repayment>> listByContract(String contractId);

  Future<List<RepaymentItem>> listItems(String repaymentId);

  Future<List<RepaymentItem>> listItemsByBillItem(String billItemId);

  Future<Map<String, RepaymentAmountBreakdown>> aggregateItemsByBillItemIds(
    Iterable<String> billItemIds,
  );

  Future<void> saveRepayment(Repayment repayment);

  /// 以聚合当前状态覆盖已存在的还款记录及其全部还款明细。
  Future<void> updateRepayment(Repayment repayment);

  Future<void> deleteRepayment(String repaymentId);
}
