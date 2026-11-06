import '../../../core/money/money.dart';
import '../../../core/time/month_key.dart';

class SocialContributionRecord {
  const SocialContributionRecord({
    required this.month,
    required this.contributionBase,
  });

  final MonthKey month;
  final Money contributionBase;

  void validate() {
    if (month.year < 1900 || month.year > 2100) {
      throw ArgumentError('Contribution month is out of range.');
    }
    if (contributionBase.minorUnits < 0) {
      throw ArgumentError('Contribution base cannot be negative.');
    }
  }
}
