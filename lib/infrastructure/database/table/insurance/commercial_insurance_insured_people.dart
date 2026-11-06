import 'package:drift/drift.dart';

@DataClassName('CommercialInsuranceInsuredPersonRow')
class CommercialInsuranceInsuredPeople extends Table {
  TextColumn get commercialInsuranceId =>
      text().named('commercial_insurance_id')();
  TextColumn get insuredPersonId => text().named('insured_person_id')();

  @override
  Set<Column> get primaryKey => {commercialInsuranceId, insuredPersonId};
}
