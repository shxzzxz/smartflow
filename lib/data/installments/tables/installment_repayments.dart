import 'package:drift/drift.dart';

import '../../../domain/installments/enums/installment_enums.dart';

@DataClassName('InstallmentRepaymentRow')
class InstallmentRepayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contractId => integer().named('contract_id')();
  TextColumn get repaymentType =>
      textEnum<InstallmentRepaymentType>().named('repayment_type')();
  IntColumn get scheduleId => integer().named('schedule_id').nullable()();
  IntColumn get transactionId => integer().named('transaction_id')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK ('
        '(repayment_type = \'scheduled\' AND schedule_id IS NOT NULL) '
        'OR (repayment_type IN (\'extraPrincipal\', \'earlySettlement\') '
        'AND schedule_id IS NULL)'
        ')',
  ];
}
