sealed class RepaymentDatesStrategy {
  const RepaymentDatesStrategy();

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
          _addMonthsClamped(firstDate, i * intervalMonths),
    ];
  }

  static DateTime _addMonthsClamped(DateTime date, int months) {
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
  const ExplicitRepaymentDates(this.dates);

  final List<DateTime> dates;

  @override
  List<DateTime> getDates() => List.unmodifiable(dates);
}
