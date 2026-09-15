import 'package:decimal/decimal.dart';

import '../../../core/time/date_label.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../view_model/installment_terms_draft.dart';
import '../../shared/presentation/reference_rate_presentation.dart';

InterestRate? installmentRateOn(
  InstallmentContractReadModel contract,
  DateTime date,
) {
  final stages = contract.stageTerms.stages
      .where((stage) => stage.terms is AmortizingStage)
      .toList();
  final currentStage =
      stages
          .where(
            (stage) => !referenceDate(
              (stage.terms as AmortizingStage).dates.getDates().last,
            ).isBefore(referenceDate(date)),
          )
          .firstOrNull ??
      stages.last;
  final stage = currentStage.terms as AmortizingStage;
  if (stage.method == InstallmentRepaymentMethod.custom ||
      stage.method == InstallmentRepaymentMethod.flatFee) {
    return null;
  }
  final changes =
      contract.repricings
          .where(
            (record) =>
                record.stageId == currentStage.id &&
                !referenceDate(
                  record.change.effectiveDate,
                ).isAfter(referenceDate(date)),
          )
          .toList()
        ..sort(
          (a, b) => a.change.effectiveDate.compareTo(b.change.effectiveDate),
        );
  return changes.isEmpty ? stage.rate : changes.last.change.rate;
}

class InstallmentStageSummaryPresentation {
  const InstallmentStageSummaryPresentation({
    required this.lines,
    required this.endDate,
  });

  final List<String> lines;
  final DateTime? endDate;
}

InstallmentStageSummaryPresentation presentInstallmentStageSummary({
  required InstallmentStageDraft stage,
  required int index,
  required List<InstallmentStageDraft> stages,
  required bool productMode,
  required DateTime? borrowingDate,
}) {
  final endDate = presentInstallmentStageEndDate(stage);
  final String range;
  if (productMode) {
    range = '时间范围在本笔贷款中填写';
  } else {
    final start = index == 0
        ? borrowingDate
        : presentInstallmentStageEndDate(stages[index - 1]);
    range =
        '${start == null ? '起点待确定' : formatDateLabel(start)} → '
        '${endDate == null ? '结束日期待确定' : formatDateLabel(endDate)}';
  }

  if (stage.deferment) {
    return InstallmentStageSummaryPresentation(
      lines: ['不还款、不计息', range],
      endDate: endDate,
    );
  }

  final method = _repaymentMethodLabel(stage.method);
  final flat = stage.method == InstallmentRepaymentMethod.flatFee;
  final custom = stage.method == InstallmentRepaymentMethod.custom;
  final unit = _ratePeriodLabel(stage.ratePeriod);
  final rateText = stage.text(StageInput.rate).trim();
  final rate = rateText.isEmpty ? Decimal.zero : Decimal.tryParse(rateText);
  return InstallmentStageSummaryPresentation(
    lines: [
      [
        flat ? '$method · 单次还款' : method,
        if (!flat && !custom)
          productMode
              ? '$unit利率（本笔填写）'
              : rate == null || rate < Decimal.zero
              ? '$unit利率待完善'
              : '$unit利率 $rate%',
      ].join(' · '),
      if (productMode && stage.floating) referenceRateTypeLabel(stage.rateType),
      range,
    ],
    endDate: endDate,
  );
}

DateTime? presentInstallmentStageEndDate(InstallmentStageDraft stage) {
  return stage.endDate;
}

String _repaymentMethodLabel(InstallmentRepaymentMethod method) {
  return switch (method) {
    InstallmentRepaymentMethod.equalInstallment => '等额本息',
    InstallmentRepaymentMethod.equalPrincipal => '等额本金',
    InstallmentRepaymentMethod.interestFirst => '先息后本',
    InstallmentRepaymentMethod.flatFee => '一次性手续费',
    InstallmentRepaymentMethod.custom => '自定义',
  };
}

String _ratePeriodLabel(InterestRatePeriod period) {
  return switch (period) {
    InterestRatePeriod.annual => '年',
    InterestRatePeriod.monthly => '月',
    InterestRatePeriod.daily => '日',
  };
}
