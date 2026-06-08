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
    String? iconKey,
    String? note,
    Money? creditLimit,
    int? billingDay,
    int? repaymentDay,
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
    _ensureCreditFields(
      type: type,
      creditLimit: creditLimit,
      billingDay: billingDay,
      repaymentDay: repaymentDay,
    );

    return Account(
      id: id,
      name: normalizedName,
      type: type,
      subtype: subtype,
      profileKey: trimToNull(profileKey),
      balance: const Money(minorUnits: 0),
      iconKey: trimToNull(iconKey),
      note: trimToNull(note),
      creditLimit: creditLimit,
      billingDay: billingDay,
      repaymentDay: repaymentDay,
      sortOrder: sortOrder,
      isHidden: isHidden,
    );
  }

  void _ensureCreditFields({
    required AccountType type,
    required Money? creditLimit,
    required int? billingDay,
    required int? repaymentDay,
  }) {
    if (type != AccountType.liability &&
        (creditLimit != null || billingDay != null || repaymentDay != null)) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Credit profile is only supported for liability accounts.',
      );
    }
    if (creditLimit != null && creditLimit.minorUnits < 0) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Credit limit cannot be negative.',
      );
    }
    if (billingDay != null && (billingDay < 1 || billingDay > 31)) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Billing day must be between 1 and 31.',
      );
    }
    if (repaymentDay != null && (repaymentDay < 1 || repaymentDay > 31)) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Repayment day must be between 1 and 31.',
      );
    }
  }
}
