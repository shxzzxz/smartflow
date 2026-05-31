import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../core/text/text_normalizer.dart';
import '../entity/account.dart';
import '../valobj/ledger_enum.dart';

class CategoryFactory {
  const CategoryFactory();

  Result<Account> createCategory({
    required String id,
    required String name,
    required AccountType type,
    Account? parent,
    String? iconKey,
    String? note,
    int sortOrder = 0,
  }) {
    final normalizedName = trimToNull(name);
    if (normalizedName == null) {
      return const Result.failure(
        Failure(
          code: 'category_name_required',
          message: 'Category name is required.',
        ),
      );
    }
    if (!type.isCategory) {
      return const Result.failure(
        Failure(
          code: 'category_type_invalid',
          message: 'Only income and expense category can be created.',
        ),
      );
    }
    if (parent != null) {
      final failure = parent.checkValidCategoryParent(type);
      if (failure != null) return Result.failure(failure);
    }

    return Result.success(
      Account(
        id: id,
        name: normalizedName,
        type: type,
        parentId: parent?.id,
        balance: const Money(minorUnits: 0),
        iconKey: trimToNull(iconKey),
        note: trimToNull(note),
        sortOrder: sortOrder,
      ),
    );
  }
}
