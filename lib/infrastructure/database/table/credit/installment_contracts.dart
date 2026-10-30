import 'package:drift/drift.dart';

import '../../../../domain/credit/valobj/installment_enums.dart';

@DataClassName('InstallmentContractRow')
class InstallmentContracts extends Table {
  TextColumn get id => text()();

  /// 正常创建由合同填入借款日期名称；空值仅供迁移添加列后回填。
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get dayCount => text().withDefault(const Constant('thirty360'))();
  TextColumn get rounding => text().withDefault(const Constant('halfUp'))();
  TextColumn get liabilityAccountId => text().named('liability_account_id')();
  TextColumn get installmentType =>
      textEnum<InstallmentType>().named('installment_type')();
  TextColumn get sourceRefId => text().named('source_ref_id').nullable()();
  IntColumn get principalMinor => integer().named('principal_minor')();

  /// 借款日期 / 合同起算日。
  DateTimeColumn get borrowingDate => dateTime()();

  TextColumn get status =>
      textEnum<InstallmentContractStatus>().named('status')();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (principal_minor > 0)',
    'CHECK (installment_type IN ('
        '\'disbursement\', \'billConversion\', \'purchase\'))',
    'CHECK (installment_type = \'disbursement\' OR source_ref_id IS NOT NULL)',
    'UNIQUE(installment_type, source_ref_id)',
  ];
}
