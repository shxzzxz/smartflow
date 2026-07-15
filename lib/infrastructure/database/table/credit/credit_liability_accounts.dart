import 'package:drift/drift.dart';

import '../../../../domain/credit/valobj/credit_account_enums.dart';

@DataClassName('CreditLiabilityAccountRow')
class CreditLiabilityAccounts extends Table {
  TextColumn get id => text().named('id')();
  TextColumn get accountId => text().named('account_id')();
  TextColumn get kind => textEnum<CreditLiabilityAccountKind>().named('kind')();
  IntColumn get creditLimitMinor =>
      integer().named('credit_limit_minor').nullable()();
  IntColumn get billingDay => integer().named('billing_day').nullable()();
  IntColumn get repaymentDay => integer().named('repayment_day').nullable()();
  BoolColumn get billingDayToNext =>
      boolean()
          .named('billing_day_to_next')
          .withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE (account_id)',
    'CHECK (credit_limit_minor IS NULL OR credit_limit_minor >= 0)',
    'CHECK (billing_day IS NULL OR billing_day BETWEEN 1 AND 28)',
    'CHECK (repayment_day IS NULL OR repayment_day BETWEEN 1 AND 28)',
    'CHECK ('
        '(kind = \'credit\' '
        'AND billing_day IS NOT NULL '
        'AND repayment_day IS NOT NULL) '
        'OR (kind = \'loan\' '
        'AND billing_day IS NULL '
        'AND repayment_day IS NULL)'
        ')',
  ];
}
