import 'package:drift/drift.dart';

@DataClassName('RepaymentRow')
class Repayments extends Table {
  TextColumn get id => text()();
  TextColumn get repaymentType => text().named('repayment_type')();
  TextColumn get targetType => text().named('target_type')();
  TextColumn get targetId => text().named('target_id')();
  TextColumn get transactionId => text().named('transaction_id').nullable()();

  /// 每笔还款自持的业务时间；关联交易的交易时间由信贷用例同步维护。
  DateTimeColumn get repaymentDate => dateTime().named('repayment_date')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (repayment_type IN ('
        '\'BILL\', '
        '\'INSTALLMENT\', '
        '\'PREPAYMENT\', '
        '\'UNATTRIBUTED\'))',
    'CHECK (target_type IN (\'BILL\', \'CONTRACT\', \'ACCOUNT\'))',
    'CHECK ('
        '(repayment_type IN (\'BILL\', \'INSTALLMENT\') '
        'AND target_type = \'BILL\') '
        'OR (repayment_type = \'PREPAYMENT\' '
        'AND target_type = \'CONTRACT\') '
        'OR (repayment_type = \'UNATTRIBUTED\' '
        'AND target_type = \'ACCOUNT\')'
        ')',
    'CHECK (repayment_type <> \'INSTALLMENT\' OR transaction_id IS NULL)',
  ];
}
