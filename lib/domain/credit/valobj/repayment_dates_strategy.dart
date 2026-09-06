/// 一个还款阶段内各期还款日的生成方式。
///
/// [intervalMonths] 是阶段的还款节奏（月数），按月 / 按年计息时决定每期计几个基础单位。
sealed class RepaymentDatesStrategy {
  const RepaymentDatesStrategy();

  int get intervalMonths;

  List<DateTime> getDates();
}

class IntervalRepaymentDates extends RepaymentDatesStrategy {
  const IntervalRepaymentDates({
    required this.firstDate,
    required this.count,
    this.intervalMonths = 1,
    this.lastDate,
  });

  final DateTime firstDate;
  final int count;
  @override
  final int intervalMonths;
  final DateTime? lastDate;

  @override
  List<DateTime> getDates() {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'Must be > 0');
    }
    if (intervalMonths <= 0) {
      throw ArgumentError.value(
        intervalMonths,
        'intervalMonths',
        'Must be > 0',
      );
    }
    if (count == 1) {
      return [lastDate ?? firstDate];
    }
    return [
      for (var i = 0; i < count; i++)
        if (i == count - 1 && lastDate != null)
          lastDate!
        else
          addMonthsClamped(firstDate, i * intervalMonths),
    ];
  }

  /// 加 [months] 个月，日超出目标月天数时取该月最后一天。
  static DateTime addMonthsClamped(DateTime date, int months) {
    final targetYear = date.year + (date.month + months - 1) ~/ 12;
    final targetMonth = (date.month + months - 1) % 12 + 1;
    final daysInTargetMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final day = date.day > daysInTargetMonth ? daysInTargetMonth : date.day;
    return DateTime(
      targetYear,
      targetMonth,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
}

class ExplicitRepaymentDates extends RepaymentDatesStrategy {
  const ExplicitRepaymentDates(this.dates, {this.intervalMonths = 1});

  final List<DateTime> dates;
  @override
  final int intervalMonths;

  @override
  List<DateTime> getDates() {
    if (intervalMonths <= 0) {
      throw ArgumentError.value(
        intervalMonths,
        'intervalMonths',
        'Must be > 0',
      );
    }
    return List.unmodifiable(dates);
  }
}
