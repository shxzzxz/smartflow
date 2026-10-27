import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/orchestration/service/advance_share_calculator.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

export 'package:smartflow/domain/orchestration/service/advance_share_calculator.dart'
    show AdvanceShareSplit;

const _advanceSharePolicy = AdvanceShareCalculator();

AdvanceShareSplit calculateAdvanceEntrySplit({
  required AdvanceScenario scenario,
  required Money total,
  required int aaPeopleCount,
  required List<AccountAmountAllocation> categoryAllocations,
}) {
  return _advanceSharePolicy.splitForEntry(
    scenario: scenario,
    total: total,
    aaPeopleCount: aaPeopleCount,
    categoryAllocations: categoryAllocations,
  );
}

int inferAaPeopleCount({required Money total, required Money advanceAmount}) {
  return _advanceSharePolicy.inferAaPeopleCount(
    total: total,
    advanceAmount: advanceAmount,
  );
}
