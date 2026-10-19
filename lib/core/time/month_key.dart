class MonthKey implements Comparable<MonthKey> {
  MonthKey({required this.year, required this.month}) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(
        month,
        'month',
        'Month must be between 1 and 12.',
      );
    }
  }

  factory MonthKey.fromDate(DateTime date) {
    return MonthKey(year: date.year, month: date.month);
  }

  factory MonthKey.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 2) {
      throw FormatException('Invalid month key: $value');
    }

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    if (month < 1 || month > 12) {
      throw FormatException('Invalid month in month key: $value');
    }

    return MonthKey(year: year, month: month);
  }

  final int year;
  final int month;

  DateTime get start => DateTime(year, month);

  DateTime get nextMonthStart {
    return month == 12 ? DateTime(year + 1) : DateTime(year, month + 1);
  }

  DateTime get endInclusive {
    return nextMonthStart.subtract(const Duration(milliseconds: 1));
  }

  MonthKey get next {
    return MonthKey.fromDate(nextMonthStart);
  }

  MonthKey get previous {
    return month == 1
        ? MonthKey(year: year - 1, month: 12)
        : MonthKey(year: year, month: month - 1);
  }

  MonthKey get previousYear {
    return MonthKey(year: year - 1, month: month);
  }

  @override
  int compareTo(MonthKey other) {
    final yearCompare = year.compareTo(other.year);
    if (yearCompare != 0) {
      return yearCompare;
    }
    return month.compareTo(other.month);
  }

  @override
  String toString() {
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) {
    return other is MonthKey && other.year == year && other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);
}
