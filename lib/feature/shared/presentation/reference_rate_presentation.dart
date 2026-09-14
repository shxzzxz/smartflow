import '../../../domain/credit/valobj/reference_rate.dart';

String referenceRateTypeLabel(InterestRateType type) => switch (type) {
  InterestRateType.fixed => '固定利率',
  InterestRateType.lprOneYear => 'LPR 一年期',
  InterestRateType.lprFiveYearPlus => 'LPR 五年期以上',
  InterestRateType.loanBenchmarkShortTerm => '短期贷款基准利率',
  InterestRateType.loanBenchmarkLongTerm => '中长期贷款基准利率',
};

String referenceRateTermLabel(InterestRateType type) => switch (type) {
  InterestRateType.fixed => '',
  InterestRateType.lprOneYear => '一年期',
  InterestRateType.lprFiveYearPlus => '五年期以上',
  InterestRateType.loanBenchmarkShortTerm => '六个月至一年（含）',
  InterestRateType.loanBenchmarkLongTerm => '五年以上',
};

String referenceRateSourceLabel(String source) => switch (source) {
  'chinamoney' => '中国货币网',
  'eastmoney' => '东方财富',
  _ => source,
};

String referenceRatePercent(int ppm) {
  final whole = ppm ~/ 10000;
  final fraction = (ppm % 10000).toString().padLeft(4, '0');
  final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '').padRight(2, '0');
  return '$whole.$trimmed%';
}
