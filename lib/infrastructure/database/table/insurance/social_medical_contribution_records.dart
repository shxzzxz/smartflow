import 'package:drift/drift.dart';

@DataClassName('SocialMedicalContributionRecordRow')
class SocialMedicalContributionRecords extends Table {
  TextColumn get socialMedicalInsuranceId =>
      text().named('social_medical_insurance_id')();
  TextColumn get yearMonth => text().named('year_month')();
  IntColumn get contributionBaseMinor =>
      integer().named('contribution_base_minor')();

  @override
  Set<Column> get primaryKey => {socialMedicalInsuranceId, yearMonth};

  @override
  List<String> get customConstraints => [
    'CHECK (contribution_base_minor >= 0)',
  ];
}
