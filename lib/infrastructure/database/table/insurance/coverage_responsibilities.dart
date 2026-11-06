import 'package:drift/drift.dart';

import '../../../../domain/insurance/valobj/insurance_enums.dart';

@DataClassName('CoverageResponsibilityRow')
class CoverageResponsibilities extends Table {
  TextColumn get id => text()();
  TextColumn get commercialInsuranceId =>
      text().named('commercial_insurance_id')();
  TextColumn get kind => textEnum<ResponsibilityKind>()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().named('sort_order')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (length(trim(name)) > 0)",
    'CHECK (sort_order >= 0)',
  ];
}
