import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/service/advance/advance_share_calculator.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/advance_ownership.dart';

export 'package:smartflow/domain/ledger/service/advance/advance_share_calculator.dart'
    show AdvanceShareSplit;

const _advanceSharePolicy = AdvanceShareCalculator();

/// UI 与其它 application 用例调用垫付分担规则的稳定入口。
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
