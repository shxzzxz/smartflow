import 'package:drift/drift.dart';

import '../../../../domain/orchestration/valobj/advance_enums.dart';

@DataClassName('AdvanceCaseRow')
class AdvanceCases extends Table {
  TextColumn get id => text()();
  TextColumn get scenario => textEnum<AdvanceScenario>()();
  TextColumn get trackingMode =>
      textEnum<AdvanceTrackingMode>().named('tracking_mode')();
  TextColumn get receivableAccountId =>
      text().named('receivable_account_id').nullable()();
  IntColumn get aaPeopleCount =>
      integer().named('aa_people_count').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (tracking_mode = 'itemized' OR receivable_account_id IS NOT NULL)",
    "CHECK (scenario = 'aa' OR aa_people_count IS NULL)",
    'CHECK (aa_people_count IS NULL OR '
        '(aa_people_count >= 2 AND aa_people_count <= 99))',
  ];
}
