import '../../../core/error/app_error_code.dart';

enum InterestRateType {
  fixed,
  lprOneYear,
  lprFiveYearPlus,
  loanBenchmarkShortTerm,
  loanBenchmarkLongTerm;

  static const referenceTypes = [
    lprOneYear,
    lprFiveYearPlus,
    loanBenchmarkShortTerm,
    loanBenchmarkLongTerm,
  ];

  bool get isFloating => this != fixed;

  bool get isLpr => this == lprOneYear || this == lprFiveYearPlus;

  DateTime get historyStart => switch (this) {
    fixed => throw StateError('固定利率没有公共参考利率历史'),
    lprOneYear || lprFiveYearPlus => DateTime.utc(2019, 8, 20),
    loanBenchmarkShortTerm ||
    loanBenchmarkLongTerm => DateTime.utc(1991, 4, 21),
  };
}

class ReferenceRate {
  const ReferenceRate({
    required this.type,
    required this.date,
    required this.ratePpm,
    required this.source,
  });

  final InterestRateType type;
  final DateTime date;
  final int ratePpm;
  final String source;
}

enum ReferenceRateErrorCode implements AppErrorCode {
  unavailable('credit.reference_rate.unavailable', '参考利率获取失败，请稍后重试'),
  conflict('credit.reference_rate.conflict', '参考利率与本地记录不一致，暂未更新');

  const ReferenceRateErrorCode(this.code, this.defaultMessage);
  @override
  final String code;
  @override
  final String defaultMessage;
}

enum ReferenceRateMissingReason {
  sourceUnavailable,
  noHistory,
  futureDate,
  dataConflict,
}

class ReferenceRateResolution {
  const ReferenceRateResolution({required this.date, this.rate, this.reason});
  final DateTime date;
  final ReferenceRate? rate;
  final ReferenceRateMissingReason? reason;
}

DateTime referenceDate(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
