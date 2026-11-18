import 'dart:convert';

import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../../../domain/insurance/valobj/coverage_term.dart';
import '../../../domain/insurance/valobj/insurance_enums.dart';
import '../../../domain/insurance/valobj/premium_plan.dart';
import '../../../domain/insurance/valobj/social_contribution_record.dart';

String insuranceMoneyLabel(Money? money) {
  if (money == null) return '未记录';
  final value = money.format();
  return value.endsWith('.00') ? value.substring(0, value.length - 3) : value;
}

String insuranceMoneyInputText(Money? money) {
  if (money == null) return '';
  return insuranceMoneyLabel(money);
}

String insuranceDisplayMoneyLabel(Money? money, {String empty = '未记录'}) {
  if (money == null) return empty;
  return _groupedMoneyLabel(money);
}

String insuranceCoverageAmountDisplayLabel(
  Money? money, {
  String empty = '未记录',
}) {
  if (money == null) return empty;
  return formatMoney(money, style: MoneyFormatStyle.tenThousand);
}

String _groupedMoneyLabel(Money money) {
  final exact = money.format();
  final negative = exact.startsWith('-');
  final unsigned = negative ? exact.substring(1) : exact;
  final parts = unsigned.split('.');
  final integer = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < integer.length; index++) {
    if (index > 0 && (integer.length - index) % 3 == 0) grouped.write(',');
    grouped.write(integer[index]);
  }
  final fraction = parts.length > 1 ? parts[1] : '';
  final decimal = fraction == '00'
      ? ''
      : '.${fraction.replaceFirst(RegExp(r'0$'), '')}';
  return '${negative ? '-' : ''}$grouped$decimal';
}

String insuranceDateLabel(DateTime date) {
  return '${date.year}年${date.month.toString().padLeft(2, '0')}月'
      '${date.day.toString().padLeft(2, '0')}日';
}

String insuranceCalendarDateLabel(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String insuranceCoverageTermLabel(CoverageTerm term) {
  final start = insuranceDateLabel(term.startDate);
  if (term.lifetime) return '$start 起终身';
  final end = term.endDate;
  return end == null ? '$start 起' : '$start 至 ${insuranceDateLabel(end)}';
}

String insurancePremiumPlanLabel(PremiumPlan? plan) {
  if (plan == null) return PremiumFrequency.other.label;
  final parts = <String>[plan.frequency.label];
  if (plan.termCount case final count?) {
    parts.add('$count 期');
  }
  if (plan.amount case final money?) {
    parts.add(insuranceMoneyLabel(money));
  }
  return parts.join(' · ');
}

String insuranceContributionPeriodLabel(SocialContributionRecord record) {
  final month = record.month;
  return month == null
      ? '${record.year}年'
      : '${record.year}年${month.toString().padLeft(2, '0')}月';
}

String insuranceCoverageDateRangeLabel(CoverageTerm term) {
  final start = insuranceCalendarDateLabel(term.startDate).replaceAll('-', '/');
  if (term.lifetime) return '$start-终身';
  final end = term.endDate;
  final endLabel = end == null
      ? '未设置'
      : insuranceCalendarDateLabel(end).replaceAll('-', '/');
  return '$start-$endLabel';
}

String insuranceCoverageEndDateLabel(CoverageTerm term) {
  if (term.lifetime) return '终身';
  final end = term.endDate;
  return end == null
      ? '未设置'
      : insuranceCalendarDateLabel(end).replaceAll('-', '/');
}

List<SocialContributionRecord> insuranceContributionsNewestFirst(
  List<SocialContributionRecord> records,
) => [...records]..sort((left, right) => right.period.compareTo(left.period));

List<String> insuranceTextLines(String? value) => const LineSplitter()
    .convert(value ?? '')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList();

String insuranceResponsibilityKindLabel(ResponsibilityKind kind) {
  return kind.label;
}

String insuranceCategoryDisplayLabel(CommercialInsuranceCategory category) {
  return switch (category) {
    CommercialInsuranceCategory.medical => '医疗险',
    CommercialInsuranceCategory.criticalIllness => '重疾险',
    CommercialInsuranceCategory.accident => '意外险',
    CommercialInsuranceCategory.life => '寿险',
    CommercialInsuranceCategory.other => '其他',
  };
}

AppStatusBadgePresentation insuranceStatusBadgePresentation(
  InsuranceCoverageStatus status,
) {
  return switch (status) {
    InsuranceCoverageStatus.notStarted => AppStatusBadgePresentation(
      label: status.label,
      tone: AppStatusTone.neutral,
    ),
    InsuranceCoverageStatus.active => AppStatusBadgePresentation(
      label: status.label,
      tone: AppStatusTone.success,
    ),
    InsuranceCoverageStatus.ended => AppStatusBadgePresentation(
      label: status.label,
      tone: AppStatusTone.neutral,
    ),
    InsuranceCoverageStatus.lifetime => AppStatusBadgePresentation(
      label: status.label,
      tone: AppStatusTone.info,
    ),
  };
}
