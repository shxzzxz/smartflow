import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/patch/patch.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'categories_view_model.g.dart';

final _logger = Logger('feature.category.manage');

@riverpod
class CategoriesViewModel extends _$CategoriesViewModel {
  @override
  void build() {}

  Future<UiActionOutcome<CategoryDeletionPreview>> previewDeletion(
    String categoryId,
  ) {
    return guardUiAction(_logger, 'Category deletion preview', () {
      return ref
          .read(categoryAppServiceProvider)
          .previewCategoryDeletion(categoryId);
    });
  }

  Future<UiActionOutcome<void>> deleteCategory(String categoryId) {
    return guardUiAction(_logger, 'Category delete', () {
      return ref
          .read(categoryAppServiceProvider)
          .deleteCategory(DeleteCategoryCommand(id: categoryId));
    });
  }

  Future<UiActionOutcome<CategoryTransactionMigrationResult>>
  migrateTransactions({
    required String sourceCategoryId,
    required String targetCategoryId,
  }) {
    return guardUiAction(_logger, 'Category transaction migration', () {
      return ref
          .read(categoryTransactionMigrationAppServiceProvider)
          .migrate(
            CategoryTransactionMigrationCommand(
              sourceCategoryId: sourceCategoryId,
              targetCategoryId: targetCategoryId,
            ),
          );
    });
  }

  Future<UiActionOutcome<void>> moveCategory(
    String categoryId, {
    required String? newParentId,
  }) {
    return guardUiAction(_logger, 'Category move', () {
      return ref
          .read(categoryAppServiceProvider)
          .editCategory(
            EditCategoryCommand(
              id: categoryId,
              parentId:
                  newParentId == null
                      ? const Patch<String>.clear()
                      : Patch.set(newParentId),
            ),
          );
    });
  }
}
