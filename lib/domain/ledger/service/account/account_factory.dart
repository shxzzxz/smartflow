import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/text/text_normalizer.dart';
import '../../entity/account.dart';
import '../../valobj/ledger_error_code.dart';
import '../../valobj/ledger_enum.dart';

class AccountFactory {
  const AccountFactory();

  Account createUserAccount({
    required String id,
    required String name,
    required AccountType type,
    AccountSubtype? subtype,
    String? profileKey,
    String? groupId,
    String? iconKey,
    String? note,
    int sortOrder = 0,
    bool isHidden = false,
  }) {
    final normalizedName = trimToNull(name);
    if (normalizedName == null) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Account name is required.',
      );
    }
    if (!type.isUserAccount) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Only asset and liability account can be created here.',
      );
    }
    if (!Account.isSubtypeCompatible(type: type, subtype: subtype)) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Account subtype does not match account type.',
      );
    }

    return Account(
      id: id,
      name: normalizedName,
      type: type,
      subtype: subtype,
      profileKey: trimToNull(profileKey),
      groupId: trimToNull(groupId),
      balance: const Money(minorUnits: 0),
      iconKey: trimToNull(iconKey),
      note: trimToNull(note),
      sortOrder: sortOrder,
      isHidden: isHidden,
    );
  }
}
