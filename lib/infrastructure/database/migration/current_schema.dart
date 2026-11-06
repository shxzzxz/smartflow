import 'package:drift/drift.dart';

import '../app_database.dart';

/// Creates the complete schema at the database's current version.
///
/// Schema changes must add fixed `vN -> vN+1` steps instead of
/// changing this initializer or rebuilding tables from current definitions.
Future<void> createCurrentSchema(
  AppDatabase database,
  Migrator migrator,
) async {
  await migrator.createAll();
  await database.customStatement(
    'CREATE UNIQUE INDEX budgets_total_unique '
    'ON budgets (month_key) '
    'WHERE account_id IS NULL',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX budgets_account_unique '
    'ON budgets (month_key, account_id) '
    'WHERE account_id IS NOT NULL',
  );
  await _createTransactionRowIndexes(database);
  await _createTransactionLineIndexes(database);
  await database.customStatement(
    'CREATE INDEX entries_transaction_idx ON entries (transaction_id)',
  );
  await database.customStatement(
    'CREATE INDEX entries_account_transaction_idx '
    'ON entries (account_id, transaction_id)',
  );
  await database.customStatement(
    'CREATE INDEX installment_contracts_liability_status_idx '
    'ON installment_contracts (liability_account_id, status)',
  );
  await database.customStatement(
    'CREATE INDEX installment_schedules_contract_period_idx '
    'ON installment_schedules (contract_id, period_no)',
  );
  await database.customStatement(
    'CREATE INDEX installment_refund_reductions_contract_idx '
    'ON installment_refund_reductions (contract_id)',
  );
  await _createBillIndexes(database);
  await _createRepaymentIndexes(database);
  await _createImportIndexes(database);
  await _createTagIndexes(database);
  await _createCounterpartyIndexes(database);
  await database.customStatement(
    'CREATE INDEX amortization_periods_pending_idx '
    'ON amortization_periods (due_at) '
    "WHERE status = 'pending' AND amount_minor > 0",
  );
  await database.customStatement(
    'CREATE INDEX amortization_allocations_subject_idx '
    'ON amortization_allocations (subject_type, subject_id, dimension)',
  );
  await _createInsuranceIndexes(database);
  await _createBusinessActivityIndexes(database);
}

Future<void> _createInsuranceIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX commercial_insurance_insured_people_person_idx '
    'ON commercial_insurance_insured_people (insured_person_id)',
  );
  await database.customStatement(
    'CREATE INDEX coverage_responsibilities_insurance_idx '
    'ON coverage_responsibilities (commercial_insurance_id, sort_order)',
  );
  await database.customStatement(
    'CREATE INDEX responsibility_points_responsibility_idx '
    'ON responsibility_points (responsibility_id, sort_order)',
  );
  await database.customStatement(
    'CREATE INDEX insurance_attachments_insurance_idx '
    'ON insurance_attachments (commercial_insurance_id, created_at)',
  );
  await database.customStatement(
    'CREATE INDEX social_medical_insurances_person_idx '
    'ON social_medical_insurances (insured_person_id)',
  );
  await database.customStatement(
    'CREATE INDEX social_pension_insurances_person_idx '
    'ON social_pension_insurances (insured_person_id)',
  );
}

Future<void> _createBusinessActivityIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_top_level_owner_occurred_idx '
    'ON transactions (owner_type, occurred_at DESC, owner_id DESC, id DESC) '
    'WHERE parent_transaction_id IS NULL AND owner_type IS NOT NULL',
  );
}

Future<void> _createTransactionLineIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transaction_lines_transaction_idx '
    'ON transaction_lines (transaction_id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transaction_lines_account_role_idx '
    'ON transaction_lines (account_id, role)',
  );
}

Future<void> _createCounterpartyIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS counterparties_name_unique '
    'ON counterparties (name)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_counterparty_idx '
    'ON transactions (counterparty_id) WHERE counterparty_id IS NOT NULL',
  );
}

Future<void> _createTagIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS tags_name_unique ON tags (name)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transaction_tags_tag_idx '
    'ON transaction_tags (tag_id)',
  );
}

Future<void> _createBillIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX bills_account_period_idx ON bills (account_id, period)',
  );
  await database.customStatement(
    'CREATE INDEX bill_items_bill_idx ON bill_items (bill_id)',
  );
  await database.customStatement(
    'CREATE INDEX bill_items_contract_idx ON bill_items (contract_id) '
    'WHERE contract_id IS NOT NULL',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX bill_items_consumption_unique '
    'ON bill_items (bill_id) WHERE item_type = \'consumption\'',
  );
}

Future<void> _createRepaymentIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS repayments_target_idx '
    'ON repayments (target_type, target_id, created_at)',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS repayments_transaction_unique '
    'ON repayments (transaction_id) '
    'WHERE transaction_id IS NOT NULL',
  );
  await database.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS repayments_generated_contract_unique '
    'ON repayments (generated_contract_id) '
    'WHERE generated_contract_id IS NOT NULL',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS repayment_items_repayment_idx '
    'ON repayment_items (repayment_id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS repayment_items_bill_item_idx '
    'ON repayment_items (bill_item_id) '
    'WHERE bill_item_id IS NOT NULL',
  );
}

Future<void> _createTransactionRowIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_top_level_occurred_idx '
    'ON transactions (parent_transaction_id, occurred_at, id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_parent_purpose_idx '
    'ON transactions (parent_transaction_id, business_purpose, '
    'occurred_at, id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_occurred_stats_idx '
    'ON transactions (occurred_at, is_excluded_from_stats)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_posted_billing_idx '
    'ON transactions (business_purpose, posted_at)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS transactions_owner_idx '
    'ON transactions (owner_type, owner_id)',
  );
}

Future<void> _createImportIndexes(AppDatabase database) async {
  await database.customStatement(
    'CREATE UNIQUE INDEX IF NOT EXISTS import_entity_mapping_unique '
    'ON import_entity_mappings (source, entity_kind, source_entity_key)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS import_batch_items_batch_idx '
    'ON import_batch_items (batch_id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS import_batch_items_operation_idx '
    'ON import_batch_items (source_operation_key)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS import_batch_items_fingerprint_idx '
    'ON import_batch_items (source_operation_fingerprint, fingerprint_version)',
  );
}
