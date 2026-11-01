import 'package:drift/drift.dart';

import '../../../../domain/orchestration/valobj/amortization_enums.dart';

@DataClassName('AmortizationAllocationRow')
class AmortizationAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get subjectType =>
      textEnum<AmortizationSubjectType>().named('subject_type')();
  TextColumn get subjectId => text().named('subject_id')();
  TextColumn get dimension =>
      textEnum<AmortizationAllocationDimension>().named('dimension')();
  IntColumn get lineNo => integer().named('line_no')();
  TextColumn get accountId => text().named('account_id')();
  IntColumn get amountMinor => integer().named('amount_minor')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (subject_type, subject_id, dimension, line_no)',
    'UNIQUE (subject_type, subject_id, dimension, account_id)',
    'CHECK (line_no > 0)',
    'CHECK (amount_minor > 0)',
  ];
}
