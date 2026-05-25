import 'package:drift/drift.dart';

import '../../../domain/credit/enums/installment_enums.dart';

@DataClassName('InstallmentContractRow')
class InstallmentContracts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get liabilityAccountId => integer().named('liability_account_id')();
  TextColumn get sourceType =>
      textEnum<InstallmentSourceType>().named('source_type')();
  IntColumn get disbursementAccountId =>
      integer().named('disbursement_account_id').nullable()();
  IntColumn get disbursementTransactionId =>
      integer().named('disbursement_transaction_id').nullable()();
  IntColumn get principalMinor => integer().named('principal_minor')();
  IntColumn get totalPeriods => integer().named('total_periods')();

  /// 借款日期 / 合同起算日（旧字段 start_date 沿用，语义统一为借款日期）。
  DateTimeColumn get borrowingDate => dateTime().named('start_date')();

  /// 首期还款日。
  DateTimeColumn get firstRepaymentDate =>
      dateTime().named('first_repayment_date')();

  /// 末期还款日。默认 = 首期 + (期数-1) 月，可独调。
  DateTimeColumn get lastRepaymentDate =>
      dateTime().named('last_repayment_date')();

  TextColumn get repaymentMethod =>
      textEnum<InstallmentRepaymentMethod>().named('repayment_method')();
  TextColumn get interestRatePeriod =>
      textEnum<InterestRatePeriod>().named('interest_rate_period').nullable()();
  IntColumn get interestRatePpm =>
      integer().named('interest_rate_ppm').nullable()();

  /// 计息方式（按日 / 按月）。drift 序列化为 enum.name，存量行默认 'daily' 保留旧行为。
  TextColumn get interestAccrualMethod =>
      textEnum<InterestAccrualMethod>()
          .named('interest_accrual_method')
          .withDefault(const Constant('daily'))();

  /// 合同总手续费，用于编辑时按 method 重新分配。
  IntColumn get totalFeeMinor =>
      integer().named('total_fee_minor').withDefault(const Constant(0))();

  TextColumn get status =>
      textEnum<InstallmentContractStatus>().named('status')();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (principal_minor > 0)',
    'CHECK (total_periods > 0)',
    'CHECK (total_fee_minor >= 0)',
    'CHECK (interest_rate_ppm IS NULL OR interest_rate_ppm >= 0)',
    'CHECK ('
        '(source_type = \'disbursement\' '
        'AND disbursement_account_id IS NOT NULL '
        'AND disbursement_transaction_id IS NOT NULL) '
        'OR (source_type = \'billConversion\' '
        'AND disbursement_account_id IS NULL '
        'AND disbursement_transaction_id IS NULL)'
        ')',
    'CHECK ('
        '(interest_rate_period IS NULL AND interest_rate_ppm IS NULL) '
        'OR (interest_rate_period IS NOT NULL AND interest_rate_ppm IS NOT NULL)'
        ')',
  ];
}
