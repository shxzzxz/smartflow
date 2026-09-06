import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  group('DriftInstallmentRepository', () {
    test('maps missing aggregate save to persistence conflict', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);

      await expectLater(
        () => repository.saveAggregate(_contract(), const []),
        throwsA(
          isA<BusinessException>().having(
            (exception) => exception.code,
            'code',
            CreditErrorCode.contractPersistenceConflict.code,
          ),
        ),
      );
    });
  });
}

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'missing-contract',
    liabilityAccountId: 'liability',
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 1000),
    borrowingDate: DateTime(2026, 1, 1),
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'missing-contract:stage:1',
      totalPeriods: 2,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, 3, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.monthly,
      feeMinor: 0,
    ),
  );
}
