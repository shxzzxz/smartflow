import '../../../core/money/money.dart';

class CoverageAmount {
  const CoverageAmount({this.amount});

  final Money? amount;

  bool get isEmpty => amount == null;

  void validate() {
    final amount = this.amount;
    if (amount != null && amount.minorUnits < 0) {
      throw ArgumentError('Coverage amount cannot be negative.');
    }
  }
}
