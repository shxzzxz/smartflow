import 'package:drift/drift.dart';

import '../../../../domain/insurance/valobj/insurance_enums.dart';

@DataClassName('CommercialInsuranceRow')
class CommercialInsurances extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get insurerName => text().named('insurer_name')();
  TextColumn get category => textEnum<CommercialInsuranceCategory>()();
  TextColumn get productForm => text().named('product_form').nullable()();
  DateTimeColumn get coverageStartDate =>
      dateTime().named('coverage_start_date')();
  DateTimeColumn get coverageEndDate =>
      dateTime().named('coverage_end_date').nullable()();
  BoolColumn get lifetime => boolean().withDefault(const Constant(false))();
  IntColumn get coverageAmountMinor =>
      integer().named('coverage_amount_minor').nullable()();
  IntColumn get premiumAmountMinor =>
      integer().named('premium_amount_minor').nullable()();
  TextColumn get premiumFrequency =>
      textEnum<PremiumFrequency>().named('premium_frequency').nullable()();
  IntColumn get premiumTermCount =>
      integer().named('premium_term_count').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (length(trim(name)) > 0)",
    "CHECK (length(trim(insurer_name)) > 0)",
    'CHECK (coverage_end_date IS NULL OR '
        'coverage_end_date >= coverage_start_date)',
    'CHECK (lifetime = 0 OR coverage_end_date IS NULL)',
    'CHECK (coverage_amount_minor IS NULL OR coverage_amount_minor >= 0)',
    'CHECK (premium_amount_minor IS NULL OR premium_amount_minor >= 0)',
    'CHECK (premium_term_count IS NULL OR premium_term_count > 0)',
  ];
}
