import 'package:drift/drift.dart';

import '../../../domain/credit/enums/installment_enums.dart';

@DataClassName('InstallmentScheduleRow')
class InstallmentSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contractId => integer().named('contract_id')();
  IntColumn get periodNo => integer().named('period_no')();
  DateTimeColumn get expectedRepaymentDate =>
      dateTime().named('expected_repayment_date')();
  IntColumn get expectedPrincipalMinor =>
      integer()
          .named('expected_principal_minor')
          .withDefault(const Constant(0))();
  IntColumn get expectedInterestMinor =>
      integer()
          .named('expected_interest_minor')
          .withDefault(const Constant(0))();
  IntColumn get expectedFeeMinor =>
      integer().named('expected_fee_minor').withDefault(const Constant(0))();
  TextColumn get status =>
      textEnum<InstallmentScheduleStatus>().named('status')();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'UNIQUE (contract_id, period_no)',
    'CHECK (period_no > 0)',
    'CHECK (expected_principal_minor >= 0)',
    'CHECK (expected_interest_minor >= 0)',
    'CHECK (expected_fee_minor >= 0)',
  ];
}
