import '../../../core/money/money.dart';

class CoverageAmount {
  const CoverageAmount({this.amount, this.note});

  final Money? amount;
  final String? note;

  bool get isEmpty => amount == null && (note == null || note!.trim().isEmpty);

  void validate() {
    final amount = this.amount;
    if (amount != null && amount.minorUnits < 0) {
      throw ArgumentError('Coverage amount cannot be negative.');
    }
  }
}
