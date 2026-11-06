import '../../../core/money/money.dart';
import 'insurance_enums.dart';

class PremiumPlan {
  const PremiumPlan({required this.frequency, this.amount, this.note});

  final Money? amount;
  final PremiumFrequency frequency;
  final String? note;

  void validate() {
    final amount = this.amount;
    if (amount != null && amount.minorUnits < 0) {
      throw ArgumentError('Premium amount cannot be negative.');
    }
  }
}
