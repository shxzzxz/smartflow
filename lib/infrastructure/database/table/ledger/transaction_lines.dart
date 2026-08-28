import 'package:drift/drift.dart';

import '../../../../domain/ledger/valobj/ledger_enum.dart';

@DataClassName('TransactionLineRow')
class TransactionLines extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().named('transaction_id')();
  IntColumn get lineNo => integer().named('line_no')();
  TextColumn get role => textEnum<TransactionRole>()();

  /// 用户账户角色必填,规则账户角色恒空——空只表示账户由过账规则按
  /// `system_key` 解析。
  TextColumn get accountId => text().named('account_id').nullable()();
  IntColumn get amountMinor => integer().named('amount_minor')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (transaction_id, line_no)'];
}
