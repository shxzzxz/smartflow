import '../../../domain/credit/valobj/reference_rate.dart';

String referenceRateTypeLabel(ReferenceRateType type) => switch (type) {
  ReferenceRateType.lprOneYear => 'LPR 一年期',
  ReferenceRateType.lprFiveYearPlus => 'LPR 五年期以上',
  ReferenceRateType.loanBenchmarkShortTerm => '短期贷款基准利率',
  ReferenceRateType.loanBenchmarkLongTerm => '中长期贷款基准利率',
};

String referenceRateTermLabel(ReferenceRateType type) => switch (type) {
  ReferenceRateType.lprOneYear => '一年期',
  ReferenceRateType.lprFiveYearPlus => '五年期以上',
  ReferenceRateType.loanBenchmarkShortTerm => '六个月至一年（含）',
  ReferenceRateType.loanBenchmarkLongTerm => '五年以上',
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
