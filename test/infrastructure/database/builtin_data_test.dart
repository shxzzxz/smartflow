import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/builtin_data.dart';
import 'package:smartflow/shared/account_group/initial_account_groups.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_product_repository.dart';
import 'package:smartflow/domain/credit/entity/installment_product.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';

import '../../helper/test_app_database.dart';

void main() {
  test(
    'v11 template upgrade retires old combination and preserves existing edits',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentProductRepository(database);
      final base = (await repository.find('builtin-loan-equal-installment'))!;
      await repository.save(
        InstallmentProduct(
          id: 'builtin-loan-interest-then-installment',
          name: '先息后本转等额本息',
          stages: const [
            InstallmentStageRule.repayment(
              id: 'retired-template-stage',
              method: InstallmentRepaymentMethod.interestFirst,
              intervalMonths: 1,
              ratePeriod: InterestRatePeriod.annual,
              accrual: InterestAccrualMethod.monthly,
            ),
          ],
          createdAt: DateTime(2026),
        ),
      );
      await (database.update(database.installmentProducts)
            ..where((p) => p.id.equals(base.id)))
          .write(const InstallmentProductsCompanion(name: Value('我的模板')));
      await repository.delete('builtin-loan-equal-principal');
      await repository.delete('builtin-loan-interest-first');
      await (database.update(database.appMetadata)
            ..where((row) => row.key.equals(builtinDataVersionKey)))
          .write(const AppMetadataCompanion(value: Value('11')));
      await ensureBuiltinData(database);
      expect((await repository.find(base.id))!.name, '我的模板');
      expect(
        (await repository.find(
          'builtin-loan-interest-then-installment',
        ))!.archived,
        isTrue,
      );
      expect(
        (await repository.find('builtin-loan-equal-principal'))!.name,
        '等额本金',
      );
      expect(
        (await repository.find('builtin-loan-interest-first'))!.name,
        '先息后本',
      );
    },
  );
  test(
    'seeds ordinary loan products once without per-loan parameters',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentProductRepository(database);
      final products = await repository.list();
      expect(
        products.map((p) => p.name),
        unorderedEquals(['等额本息', '等额本金', '一次性手续费', '先息后本', '国家助学贷款']),
      );
      for (final product in products) {
        product.validate();
      }
      final stages = await database
          .select(database.installmentStageConfigs)
          .get();
      expect(stages, hasLength(7));
      for (final stage in stages) {
        expect(stage.ownerType, 'product');
        expect(stage.ratePpm, isNull);
        expect(stage.periods, isNull);
        expect(stage.feeMinor, isNull);
        expect(stage.endPrincipalMinor, isNull);
      }
      await repository.delete(products.first.id);
      await ensureBuiltinData(database);
      expect(await repository.find(products.first.id), isNull);
      expect(await repository.list(), hasLength(4));
    },
  );
  test('builtin data assigns receivable and payable profile groups', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'receivable',
            name: 'Receivable',
            accountType: AccountType.asset,
            accountSubtype: const Value(AccountSubtype.receivable),
            accountProfileKey: const Value('ledger.receivable'),
          ),
        );
    await database
        .into(database.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'payable',
            name: 'Payable',
            accountType: AccountType.liability,
            accountSubtype: const Value(AccountSubtype.payable),
            accountProfileKey: const Value('ledger.payable'),
          ),
        );
    await (database.update(database.appMetadata)
          ..where((row) => row.key.equals(builtinDataVersionKey)))
        .write(const AppMetadataCompanion(value: Value('9')));

    await ensureBuiltinData(database);
    await ensureBuiltinData(database);

    final receivable = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('receivable'))).getSingle();
    final payable = await (database.select(
      database.accounts,
    )..where((row) => row.id.equals('payable'))).getSingle();
    expect(
      receivable.groupId,
      initialAccountGroupIdForProfile(AccountProfileKind.receivable),
    );
    expect(
      payable.groupId,
      initialAccountGroupIdForProfile(AccountProfileKind.payable),
    );
  });
}
