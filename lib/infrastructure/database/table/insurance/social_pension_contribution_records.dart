import 'package:drift/drift.dart';

@DataClassName('SocialPensionContributionRecordRow')
class SocialPensionContributionRecords extends Table {
  TextColumn get socialPensionInsuranceId =>
      text().named('social_pension_insurance_id')();
  TextColumn get yearMonth => text().named('year_month')();
  IntColumn get contributionBaseMinor =>
      integer().named('contribution_base_minor')();

  @override
  Set<Column> get primaryKey => {socialPensionInsuranceId, yearMonth};

  @override
  List<String> get customConstraints => [
    'CHECK (contribution_base_minor >= 0)',
  ];
}
