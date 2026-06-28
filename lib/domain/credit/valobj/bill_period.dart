import '../../../core/error/app_exception.dart';
import 'credit_error_code.dart';

class BillPeriod implements Comparable<BillPeriod> {
  BillPeriod({required this.year, required this.month}) {
    if (year < 1900 || month < 1 || month > 12) {
      throw BusinessException(
        CreditErrorCode.accountInvalidCommand,
        message: 'Bill period must be a valid YYYYMM value.',
      );
    }
  }

  factory BillPeriod.fromDate(DateTime date) {
    return BillPeriod(year: date.year, month: date.month);
  }

  factory BillPeriod.fromInt(int value) {
    final year = value ~/ 100;
    final month = value % 100;
    return BillPeriod(year: year, month: month);
  }

  final int year;
  final int month;

  int toInt() => year * 100 + month;

  @override
  int compareTo(BillPeriod other) {
    final yearCompare = year.compareTo(other.year);
    if (yearCompare != 0) return yearCompare;
    return month.compareTo(other.month);
  }

  @override
  String toString() => '$year${month.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) {
    return other is BillPeriod && other.year == year && other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);
}
