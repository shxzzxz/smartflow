import 'package:drift/drift.dart';

import '../../../../domain/credit/valobj/bill_enums.dart';

@DataClassName('BillItemRow')
class BillItems extends Table {
  TextColumn get id => text()();
  TextColumn get billId => text().named('bill_id')();
  TextColumn get itemType => textEnum<BillItemType>().named('item_type')();
  TextColumn get contractId => text().named('contract_id').nullable()();
  TextColumn get scheduleId => text().named('schedule_id').nullable()();
  DateTimeColumn get repaymentDate => dateTime().named('repayment_date')();
  IntColumn get expectedPrincipalMinor =>
      integer().named('expected_principal_minor')();
  IntColumn get expectedInterestMinor =>
      integer().named('expected_interest_minor')();
  IntColumn get expectedFeeMinor => integer().named('expected_fee_minor')();
  TextColumn get status => textEnum<BillItemStatus>().named('status')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (expected_principal_minor >= 0)',
    'CHECK (expected_interest_minor >= 0)',
    'CHECK (expected_fee_minor >= 0)',
    'CHECK ('
        '(item_type = \'consumption\' '
        'AND contract_id IS NULL '
        'AND schedule_id IS NULL) '
        'OR (item_type = \'installment\' '
        'AND contract_id IS NOT NULL '
        'AND schedule_id IS NOT NULL)'
        ')',
  ];
}
