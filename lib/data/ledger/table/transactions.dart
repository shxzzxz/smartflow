import 'package:drift/drift.dart';

import '../../../domain/ledger/valobj/ledger_enum.dart';

@DataClassName('TransactionRow')
class Transactions extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();
  TextColumn get rootTransactionId =>
      text().named('root_transaction_id').nullable()();
  TextColumn get businessPurpose =>
      textEnum<BusinessPurpose>().named('business_purpose')();
  DateTimeColumn get occurredAt => dateTime().named('occurred_at')();
  IntColumn get primaryAmountMinor => integer().named('primary_amount_minor')();
  TextColumn get counterpartyName =>
      text().named('counterparty_name').nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get parentTransactionId =>
      text().named('parent_transaction_id').nullable()();
  TextColumn get reimbursementExpenseAccountId =>
      text().named('reimbursement_expense_account_id').nullable()();
  TextColumn get mutationKind =>
      textEnum<MutationKind>().named('mutation_kind')();
  TextColumn get mutationPreviousTransactionId =>
      text().named('mutation_previous_transaction_id').nullable()();
  TextColumn get mutationReason =>
      textEnum<MutationReason>().named('mutation_reason').nullable()();
  TextColumn get businessState =>
      textEnum<BusinessState>().named('business_state')();
  BoolColumn get isExcludedFromStats =>
      boolean()
          .named('is_excluded_from_stats')
          .withDefault(const Constant(false))();
  BoolColumn get isExcludedFromBudget =>
      boolean()
          .named('is_excluded_from_budget')
          .withDefault(const Constant(false))();
  TextColumn get sourceKind => textEnum<SourceKind>().named('source_kind')();
  TextColumn get ownerType => text().named('owner_type').nullable()();
  TextColumn get ownerId => text().named('owner_id').nullable()();
  TextColumn get ownerRole => text().named('owner_role').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
