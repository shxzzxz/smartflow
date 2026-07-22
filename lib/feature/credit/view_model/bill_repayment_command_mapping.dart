import '../../../application/credit/credit_command_api.dart' as credit;
import '../presentation/bill_repayment_allocation.dart';

List<credit.BillRepaymentAllocation> billRepaymentCommandAllocations(
  Iterable<BillRepaymentAllocationDraft> allocations,
) {
  return [
    for (final allocation in allocations)
      credit.BillRepaymentAllocation(
        billItemId: allocation.billItemId,
        allocated: credit.RepaymentAmountDto(
          principal: allocation.allocated.principal,
          interest: allocation.allocated.interest,
          fee: allocation.allocated.fee,
          discount: allocation.allocated.discount,
        ),
      ),
  ];
}
