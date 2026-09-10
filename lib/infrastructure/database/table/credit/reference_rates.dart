import 'package:drift/drift.dart';

@DataClassName('ReferenceRateRow')
class ReferenceRates extends Table {
  TextColumn get type => text()();
  DateTimeColumn get rateDate => dateTime()();
  IntColumn get ratePpm => integer()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {type, rateDate};
  @override
  List<String> get customConstraints => [
    "CHECK (type IN ('lprOneYear', 'lprFiveYearPlus', 'loanBenchmarkShortTerm', 'loanBenchmarkLongTerm'))",
    'CHECK (rate_ppm >= 0)',
  ];
}
