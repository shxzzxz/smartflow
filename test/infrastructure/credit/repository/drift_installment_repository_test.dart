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
    totalPeriods: 2,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, 3, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: InterestAccrualMethod.monthly,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}
