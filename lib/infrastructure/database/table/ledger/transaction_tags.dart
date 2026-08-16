import 'package:drift/drift.dart';

/// 交易与标签的关联。标签只挂在顶层交易上；引用一致性由写入路径校验，
/// 不使用数据库外键。
@DataClassName('TransactionTagRow')
class TransactionTags extends Table {
  TextColumn get transactionId => text().named('transaction_id')();
  TextColumn get tagId => text().named('tag_id')();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}
