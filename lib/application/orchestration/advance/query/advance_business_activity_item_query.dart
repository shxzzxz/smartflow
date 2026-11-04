import '../../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../../shared/business_activity/business_activity_item_role.dart';

class AdvanceBusinessActivityItemRequest {
  const AdvanceBusinessActivityItemRequest({
    required this.advanceCaseId,
    required this.businessPurpose,
  });

  final String advanceCaseId;
  final BusinessPurpose businessPurpose;
}

class AdvanceBusinessActivityItemProjection {
  const AdvanceBusinessActivityItemProjection({
    required this.transactionId,
    required this.advanceCaseId,
    required this.factKind,
    required this.role,
    required this.scenario,
    required this.trackingMode,
  });

  final String transactionId;
  final String advanceCaseId;
  final AdvanceTransactionFactKind factKind;
  final BusinessActivityItemRole role;
  final AdvanceScenario scenario;
  final AdvanceTrackingMode trackingMode;
}
