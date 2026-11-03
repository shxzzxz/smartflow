import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/money_formatter.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

import '../transaction_badge_presentation.dart';
import 'business_scene_presentation.dart';
import 'transaction_adjustment_presentation.dart';

BusinessActivityRowContent presentAdvanceBusinessActivityRow(
  BusinessActivityReadModel item,
) {
  final summary = item.summary as AdvanceBusinessActivitySummary;
  return BusinessActivityRowContent(
    preferCategoryArtwork: item.anchorTransaction.categoryLines.isNotEmpty,
    standardSummary: _standardSummary(item, summary),
    standardBadges: _standardFallbackBadges(summary),
    compactBadges: [?_compactBadgePresentation(item, summary)],
  );
}

String? _standardSummary(
  BusinessActivityReadModel item,
  AdvanceBusinessActivitySummary summary,
) {
  if (summary.trackingMode == AdvanceTrackingMode.account) {
    return null;
  }

  final transaction = item.anchorTransaction;
  final scenarioLabel = _scenarioLabel(summary);
  final gapParts = _gapParts(transaction);
  if (summary.isClosed) {
    return [scenarioLabel, '已结清', ...gapParts].join(' · ');
  }

  final progress = _advanceProgress(transaction, summary);
  if (progress == null) {
    return [scenarioLabel, ...gapParts].join(' · ');
  }

  final progressText =
      '${formatMoney(progress.received, style: MoneyFormatStyle.compact)}/'
      '${formatMoney(progress.currentReceivable, style: MoneyFormatStyle.compact)}';
  if (summary.scenario == AdvanceScenario.aa) {
    return [scenarioLabel, '已到账 $progressText', ...gapParts].join(' · ');
  }
  return ['$scenarioLabel $progressText', ...gapParts].join(' · ');
}

String? _compactBadgeLabel(
  BusinessActivityReadModel item,
  AdvanceBusinessActivitySummary summary,
) {
  final scenarioLabel = _scenarioLabel(summary);
  if (summary.scenario == AdvanceScenario.aa ||
      summary.trackingMode == AdvanceTrackingMode.account ||
      summary.isClosed) {
    return scenarioLabel;
  }

  final progress = _advanceProgress(item.anchorTransaction, summary);
  if (progress == null) {
    return scenarioLabel;
  }
  return '$scenarioLabel '
      '${formatMoney(progress.received, style: MoneyFormatStyle.compact)}/'
      '${formatMoney(progress.currentReceivable, style: MoneyFormatStyle.compact)}';
}

({Money received, Money currentReceivable})? _advanceProgress(
  TransactionReadModel transaction,
  AdvanceBusinessActivitySummary summary,
) {
  final received = transaction.advanceSummary?.receivedAmount ?? Money.zero();
  final currentReceivable = received + summary.outstanding;
  if (currentReceivable.minorUnits <= 0) return null;
  return (received: received, currentReceivable: currentReceivable);
}

String _scenarioLabel(AdvanceBusinessActivitySummary summary) {
  return switch (summary.scenario) {
    AdvanceScenario.aa => switch (summary.aaPeopleCount) {
      final count? => 'AA $count人',
      null => 'AA',
    },
    AdvanceScenario.reimbursement => '报销',
    AdvanceScenario.onBehalf => '代付',
  };
}

List<String> _gapParts(TransactionReadModel transaction) {
  return [
    for (final adjustment in transactionAdjustments(transaction))
      if (adjustment.kind == TransactionAdjustmentKind.advanceSelfBorne ||
          adjustment.kind == TransactionAdjustmentKind.advanceBadDebt ||
          adjustment.kind ==
              TransactionAdjustmentKind.advanceCompensationIncome)
        adjustmentSupportingLabel(adjustment),
  ];
}

List<TransactionBadgePresentation> _standardFallbackBadges(
  AdvanceBusinessActivitySummary summary,
) {
  if (summary.trackingMode == AdvanceTrackingMode.account &&
      summary.scenario == AdvanceScenario.aa &&
      summary.aaPeopleCount != null) {
    return [
      TransactionBadgePresentation(
        label: 'AA ${summary.aaPeopleCount}人',
        tone: FinanceTone.neutral,
      ),
    ];
  }
  return const [];
}

TransactionBadgePresentation? _compactBadgePresentation(
  BusinessActivityReadModel item,
  AdvanceBusinessActivitySummary summary,
) {
  final label = _compactBadgeLabel(item, summary);
  return label == null
      ? null
      : TransactionBadgePresentation(label: label, tone: FinanceTone.neutral);
}
