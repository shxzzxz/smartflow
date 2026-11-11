import '../../../core/money/money.dart';
import 'insurance_enums.dart';

class PremiumPlan {
  const PremiumPlan({required this.frequency, this.amount, this.termCount});

  final Money? amount;
  final PremiumFrequency frequency;
  final int? termCount;

  void validate() {
    final amount = this.amount;
    if (amount != null && amount.minorUnits < 0) {
      throw ArgumentError('Premium amount cannot be negative.');
    }
    final termCount = this.termCount;
    if (termCount != null && termCount <= 0) {
      throw ArgumentError('Premium term count must be positive.');
    }
  }
}
