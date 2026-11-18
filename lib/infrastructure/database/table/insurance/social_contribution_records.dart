import 'package:drift/drift.dart';

@DataClassName('SocialContributionRecordRow')
class SocialContributionRecords extends Table {
  TextColumn get socialInsuranceId => text().named('social_insurance_id')();
  TextColumn get period => text()();
  IntColumn get contributionBaseMinor =>
      integer().named('contribution_base_minor').nullable()();
  IntColumn get contributionAmountMinor =>
      integer().named('contribution_amount_minor').nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {socialInsuranceId, period};

  @override
  List<String> get customConstraints => [
    'CHECK (contribution_base_minor IS NULL OR contribution_base_minor >= 0)',
    'CHECK (contribution_amount_minor IS NULL OR contribution_amount_minor >= 0)',
  ];
}
