import 'package:drift/drift.dart';

@DataClassName('SocialContributionRecordRow')
class SocialContributionRecords extends Table {
  TextColumn get socialInsuranceId => text().named('social_insurance_id')();
  TextColumn get yearMonth => text().named('year_month')();
  IntColumn get contributionBaseMinor =>
      integer().named('contribution_base_minor')();

  @override
  Set<Column> get primaryKey => {socialInsuranceId, yearMonth};

  @override
  List<String> get customConstraints => [
    'CHECK (contribution_base_minor >= 0)',
  ];
}
