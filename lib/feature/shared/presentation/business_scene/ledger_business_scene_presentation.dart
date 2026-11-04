import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';

import 'business_scene_presentation.dart';
import 'transaction_adjustment_presentation.dart';

BusinessActivityRowContent presentLedgerBusinessActivityRow(
  BusinessActivityReadModel item,
) {
  final transaction = item.displayTransaction;
  final parts = transaction == null
      ? const <String>[]
      : adjustmentSupportingParts(transaction);
  return BusinessActivityRowContent(
    standardSummary: parts.isEmpty ? null : parts.join(' · '),
  );
}
