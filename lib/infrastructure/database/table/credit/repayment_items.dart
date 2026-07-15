import 'package:drift/drift.dart';

@DataClassName('RepaymentItemRow')
class RepaymentItems extends Table {
  TextColumn get id => text()();
  TextColumn get repaymentId => text().named('repayment_id')();
  TextColumn get billItemId => text().named('bill_item_id').nullable()();
  IntColumn get allocatedPrincipalMinor =>
      integer().named('allocated_principal_minor')();
  IntColumn get allocatedInterestMinor =>
      integer().named('allocated_interest_minor')();
  IntColumn get allocatedFeeMinor => integer().named('allocated_fee_minor')();
  IntColumn get allocatedDiscountMinor =>
      integer().named('allocated_discount_minor')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (allocated_principal_minor >= 0)',
    'CHECK (allocated_interest_minor >= 0)',
    'CHECK (allocated_fee_minor >= 0)',
    'CHECK (allocated_discount_minor >= 0)',
  ];
}
