import 'package:drift/drift.dart';

import '../../../../domain/credit/valobj/installment_enums.dart';

@DataClassName('InstallmentRepaymentRow')
class InstallmentRepayments extends Table {
  TextColumn get id => text()();
  TextColumn get contractId => text().named('contract_id')();
  TextColumn get repaymentType =>
      textEnum<InstallmentRepaymentType>().named('repayment_type')();
  TextColumn get scheduleId => text().named('schedule_id').nullable()();
  TextColumn get transactionId => text().named('transaction_id')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ('
        '(repayment_type = \'scheduled\' AND schedule_id IS NOT NULL) '
        'OR (repayment_type IN (\'extraPrincipal\', \'earlySettlement\') '
        'AND schedule_id IS NULL)'
        ')',
  ];
}
