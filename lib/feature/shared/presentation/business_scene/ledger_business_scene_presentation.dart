import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';

import 'business_scene_presentation.dart';
import 'transaction_adjustment_presentation.dart';

BusinessItemRowContent presentLedgerBusinessItemRow(
  BusinessItemReadModel item,
) {
  final parts = adjustmentSupportingParts(item.anchorTransaction);
  return BusinessItemRowContent(
    standardSummary: parts.isEmpty ? null : parts.join(' · '),
  );
}
