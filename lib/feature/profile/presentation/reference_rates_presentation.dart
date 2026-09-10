import '../../../application/credit/credit_command_api.dart';
import '../../shared/presentation/reference_rate_presentation.dart';

enum ReferenceRateGroup {
  lpr,
  loanBenchmark;

  String get label => switch (this) {
    lpr => 'LPR',
    loanBenchmark => '贷款基准利率',
  };

  String get dateLabel => this == lpr ? '公布日期' : '数据日期';

  List<ReferenceRateType> get types => switch (this) {
    lpr => const [
      ReferenceRateType.lprOneYear,
      ReferenceRateType.lprFiveYearPlus,
    ],
    loanBenchmark => const [
      ReferenceRateType.loanBenchmarkShortTerm,
      ReferenceRateType.loanBenchmarkLongTerm,
    ],
  };
}

class ReferenceRateTableRow {
  ReferenceRateTableRow(this.date, Map<ReferenceRateType, ReferenceRate> rates)
    : rates = Map.unmodifiable(rates);
  final DateTime date;
  final Map<ReferenceRateType, ReferenceRate> rates;
}

List<ReferenceRateTableRow> referenceRateTableRows(
  ReferenceRateGroup group,
  ReferenceRateHistory? history, {
  int? year,
}) {
  final grouped = <DateTime, Map<ReferenceRateType, ReferenceRate>>{};
  for (final rate in history?.rates ?? const <ReferenceRate>[]) {
    if (!group.types.contains(rate.type) ||
        rate.date.isAfter(history!.asOf) ||
        (year != null && rate.date.year != year)) {
      continue;
    }
    (grouped[rate.date] ??= {})[rate.type] = rate;
  }
  final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final date in dates) ReferenceRateTableRow(date, grouped[date]!),
  ];
}

ReferenceRate? currentReferenceRate(
  ReferenceRateType type,
  ReferenceRateHistory? history,
) {
  ReferenceRate? current;
  for (final rate in history?.rates ?? const <ReferenceRate>[]) {
    if (rate.type == type &&
        !rate.date.isAfter(history!.asOf) &&
        (current == null || rate.date.isAfter(current.date))) {
      current = rate;
    }
  }
  return current;
}

String referenceRateFailureLabel(ReferenceRateMissingReason reason) =>
    switch (reason) {
      ReferenceRateMissingReason.sourceUnavailable => '暂未更新',
      ReferenceRateMissingReason.dataConflict => '数据待核对',
      ReferenceRateMissingReason.noHistory => '暂无记录',
      ReferenceRateMissingReason.futureDate => '尚未公布',
    };

String? referenceRateHistoryWarning(
  ReferenceRateGroup group,
  ReferenceRateHistory? history,
) {
  if (history == null || history.updating) return null;
  final failures = history.failures.entries
      .where(
        (entry) =>
            group.types.contains(entry.key) &&
            entry.value != ReferenceRateMissingReason.noHistory,
      )
      .toList();
  if (failures.isEmpty) return null;
  final hasSaved = referenceRateTableRows(group, history).isNotEmpty;
  if (failures.length == group.types.length) {
    return hasSaved ? '更新未完成，当前显示已保存数据' : '暂时无法获取参考利率，请重试';
  }
  return failures
      .map(
        (entry) =>
            '${referenceRateTermLabel(entry.key)}${referenceRateFailureLabel(entry.value)}',
      )
      .join('；');
}
