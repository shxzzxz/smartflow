import '../../ledger/valobj/ledger_enum.dart';
import '../valobj/advance_enums.dart';

/// Resolves the orchestration-owned transaction fact for an advance activity.
AdvanceTransactionFactKind? resolveAdvanceTransactionFactKind(
  BusinessPurpose businessPurpose,
) {
  return switch (businessPurpose) {
    BusinessPurpose.advance => AdvanceTransactionFactKind.advance,
    BusinessPurpose.advanceCollection => AdvanceTransactionFactKind.collection,
    BusinessPurpose.refund => AdvanceTransactionFactKind.refund,
    BusinessPurpose.advanceSettlement => AdvanceTransactionFactKind.settlement,
    _ => null,
  };
}
