import '../../../core/money/money.dart';

class SocialContributionRecord {
  const SocialContributionRecord({
    required this.year,
    this.month,
    this.contributionBase,
    this.contributionAmount,
    this.note,
  });

  factory SocialContributionRecord.fromPeriod({
    required String period,
    Money? contributionBase,
    Money? contributionAmount,
    String? note,
  }) {
    final match = RegExp(r'^(\d{4})(?:-(0[1-9]|1[0-2]))?$').firstMatch(period);
    if (match == null) throw FormatException('Invalid contribution period.');
    final record = SocialContributionRecord(
      year: int.parse(match.group(1)!),
      month: match.group(2) == null ? null : int.parse(match.group(2)!),
      contributionBase: contributionBase,
      contributionAmount: contributionAmount,
      note: note,
    );
    record.validate();
    return record;
  }

  final int year;
  final int? month;
  final Money? contributionBase;

  /// Older records only contained a contribution base, so their amount is null.
  final Money? contributionAmount;
  final String? note;

  String get period =>
      month == null ? '$year' : '$year-${month.toString().padLeft(2, '0')}';

  void validate() {
    if (year < 1900 ||
        year > 2100 ||
        (month != null && (month! < 1 || month! > 12))) {
      throw ArgumentError('Contribution period is out of range.');
    }
    if ((contributionBase?.minorUnits ?? 0) < 0) {
      throw ArgumentError('Contribution base cannot be negative.');
    }
    if ((contributionAmount?.minorUnits ?? 0) < 0) {
      throw ArgumentError('Contribution amount cannot be negative.');
    }
  }
}
