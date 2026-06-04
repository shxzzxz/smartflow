import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_installment_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  group('DriftInstallmentRepository', () {
    test('maps missing contract update to persistence conflict', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftInstallmentRepository(database);

      await expectLater(
        () => repository.updateContract(
          'missing-contract',
          const InstallmentContractPatch(totalPeriods: 2),
        ),
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
