import '../../../core/error/app_exception.dart';
import '../../../core/text/text_normalizer.dart';
import '../valobj/ledger_error_code.dart';

class AccountGroup {
  AccountGroup({
    required this.id,
    required String name,
    this.sortOrder = 0,
    this.version = 0,
  }) : name = _normalizeName(name);

  final String id;
  String name;
  int sortOrder;
  int version;

  void rename(String value) {
    name = _normalizeName(value);
  }

  void reorder(int value) {
    sortOrder = value;
  }

  static String _normalizeName(String value) {
    final normalized = trimToNull(value);
    if (normalized == null) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Account group name is required.',
      );
    }
    return normalized;
  }
}
