import 'package:decimal/decimal.dart';

import '../../../core/time/date_label.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/rate_change.dart';
import '../../shared/presentation/reference_rate_presentation.dart';

String repricingRatePeriodLabel(InterestRatePeriod period) => switch (period) {
  InterestRatePeriod.annual => '年',
  InterestRatePeriod.monthly => '月',
  InterestRatePeriod.daily => '日',
};

String repricingRateLabel(RateChange change) =>
    '${repricingRatePeriodLabel(change.rate.period)}利率 '
    '${_percent(change.rate.ppm)}%';

String repricingBasisLabel(RateChange change) => switch (change) {
  DirectRateChange() => '直接指定',
  ReferenceRateChange() =>
    '重定价日 ${formatDateLabel(change.resetDate)}\n'
        '${referenceRateTypeLabel(change.referenceRate.type)} '
        '${_percent(change.referenceRate.ratePpm)}% · ${change.spreadBp} BP',
};

String _percent(int ppm) =>
    (Decimal.fromInt(ppm) * Decimal.parse('0.0001')).toString();
