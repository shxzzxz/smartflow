import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/text/text_normalizer.dart';
import '../../entity/account.dart';
import '../../valobj/ledger_error_code.dart';
import '../../valobj/ledger_enum.dart';

class CategoryFactory {
  const CategoryFactory();

  Account createCategory({
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
      throw BusinessException(
        LedgerErrorCode.categoryInvalidCommand,
        message: 'Category name is required.',
      );
    }
    if (!type.isCategory) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidCommand,
        message: 'Only income and expense category can be created.',
      );
    }
    if (parent != null) {
      _ensureValidParent(parent, type);
    }

    return Account(
      id: id,
      name: normalizedName,
      type: type,
      parentId: parent?.id,
      balance: const Money(minorUnits: 0),
      iconKey: trimToNull(iconKey),
      note: trimToNull(note),
      sortOrder: sortOrder,
    );
  }

  void _ensureValidParent(Account parent, AccountType expectedType) {
    if (parent.isArchived) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidParent,
        message: 'Archived category cannot be used as parent.',
      );
    }
    if (parent.type != expectedType) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidParent,
        message: 'Parent category type must match child category type.',
      );
    }
    if (parent.parentId != null) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidParent,
        message: 'Categories support one child level in this stage.',
      );
    }
  }
}
