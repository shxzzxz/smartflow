import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

export 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

TransactionOwnership advanceOwnership({
  required AdvanceTrackingMode management,
  required String ownerId,
  required AdvanceScenario scenario,
}) {
  return TransactionOwnership(
    ownerType: orchestrationAdvanceOwnerType,
    ownerId: ownerId,
  );
}
