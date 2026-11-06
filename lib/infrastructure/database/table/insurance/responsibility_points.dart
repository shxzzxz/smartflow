import 'package:drift/drift.dart';

@DataClassName('ResponsibilityPointRow')
class ResponsibilityPoints extends Table {
  TextColumn get id => text()();
  TextColumn get responsibilityId => text().named('responsibility_id')();
  TextColumn get label => text()();
  TextColumn get value => text()();
  IntColumn get sortOrder => integer().named('sort_order')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (length(trim(label)) > 0)",
    "CHECK (length(trim(value)) > 0)",
    'CHECK (sort_order >= 0)',
  ];
}
