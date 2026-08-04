import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/category/view_model/categories_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  group('CategoriesViewModel.migrateTransactions', () {
    test('assembles the migration command and maps success', () async {
      final service = _FakeCategoryTransactionMigrationAppService();
      final container = _container(service);

      final outcome = await container
          .read(categoriesViewModelProvider.notifier)
          .migrateTransactions(
            sourceCategoryId: 'source',
            targetCategoryId: 'target',
          );

      expect(
        outcome,
        isA<UiActionSuccess<CategoryTransactionMigrationResult>>(),
      );
      final command = service.commands.single;
      expect(command.sourceCategoryId, 'source');
      expect(command.targetCategoryId, 'target');
      expect(
        (outcome as UiActionSuccess<CategoryTransactionMigrationResult>)
            .value
            .migratedGroupCount,
        2,
      );
    });

    test('maps an application rejection to a failure outcome', () async {
      final service = _FakeCategoryTransactionMigrationAppService(
        exception: BusinessException(
          LedgerErrorCode.categoryUnavailable,
          message: '系统分类不能迁移。',
        ),
      );
      final container = _container(service);

      final outcome = await container
          .read(categoriesViewModelProvider.notifier)
          .migrateTransactions(
            sourceCategoryId: 'system-source',
            targetCategoryId: 'target',
          );

      expect(
        outcome,
        isA<UiActionFailure<CategoryTransactionMigrationResult>>(),
      );
      final failure =
          outcome as UiActionFailure<CategoryTransactionMigrationResult>;
      expect(failure.error.code, LedgerErrorCode.categoryUnavailable.code);
      expect(failure.error.message, '系统分类不能迁移。');
    });
  });
}

ProviderContainer _container(
  _FakeCategoryTransactionMigrationAppService service,
) {
  final container = ProviderContainer(
    overrides: [
      categoryTransactionMigrationAppServiceProvider.overrideWith(
        (ref) => service,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeCategoryTransactionMigrationAppService
    implements CategoryTransactionMigrationAppService {
  _FakeCategoryTransactionMigrationAppService({this.exception});

  final AppException? exception;
  final commands = <CategoryTransactionMigrationCommand>[];

  @override
  Future<CategoryTransactionMigrationResult> migrate(
    CategoryTransactionMigrationCommand command,
  ) async {
    commands.add(command);
    final failure = exception;
    if (failure != null) throw failure;
    return const CategoryTransactionMigrationResult(migratedGroupCount: 2);
  }
}
