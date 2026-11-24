import '../../../core/error/app_exception.dart';
import '../valobj/ledger_error_code.dart';

class Book {
  Book({required this.id, required String name, this.sortOrder = 0})
    : name = _validatedName(name);

  static const dailyId = 'builtin-daily-book';
  static const dailyName = '日常账本';

  final String id;
  String name;
  final int sortOrder;

  bool get isBuiltin => id == dailyId;

  void rename(String value) => name = _validatedName(value);

  void assertCanDelete({required bool hasTransactions}) {
    if (isBuiltin) {
      throw BusinessException(LedgerErrorCode.bookBuiltin);
    }
    if (hasTransactions) {
      throw BusinessException(LedgerErrorCode.bookInUse);
    }
  }

  static String _validatedName(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      throw BusinessException(LedgerErrorCode.bookInvalidCommand);
    }
    return name;
  }
}
