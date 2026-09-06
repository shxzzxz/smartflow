/// 利率单位之间换算所用的标准天数：月按 [daysPerMonth] 天，年按 [daysPerYear] 天。
class DayCountConvention {
  const DayCountConvention({
    required this.daysPerMonth,
    required this.daysPerYear,
  });

  static const thirty360 = DayCountConvention(
    daysPerMonth: 30,
    daysPerYear: 360,
  );
  static const thirty365 = DayCountConvention(
    daysPerMonth: 30,
    daysPerYear: 365,
  );

  static const values = [thirty360, thirty365];

  final int daysPerMonth;
  final int daysPerYear;

  @override
  bool operator ==(Object other) {
    return other is DayCountConvention &&
        other.daysPerMonth == daysPerMonth &&
        other.daysPerYear == daysPerYear;
  }

  @override
  int get hashCode => Object.hash(daysPerMonth, daysPerYear);

  @override
  String toString() => 'DayCountConvention($daysPerMonth/$daysPerYear)';
}
