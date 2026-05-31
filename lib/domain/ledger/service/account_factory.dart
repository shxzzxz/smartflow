import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../core/text/text_normalizer.dart';
import '../entity/account.dart';
import '../valobj/ledger_enum.dart';

class AccountFactory {
  const AccountFactory();

  Result<Account> createUserAccount({
    required String id,
    required String name,
    required AccountType type,
    AccountSubtype? subtype,
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
      return const Result.failure(
        Failure(
          code: 'account_name_required',
          message: 'Account name is required.',
        ),
      );
    }
    if (!type.isUserAccount) {
      return const Result.failure(
        Failure(
          code: 'account_type_invalid',
          message: 'Only asset and liability account can be created here.',
        ),
      );
    }
    final subtypeFailure = Account.validateSubtypeCompatibility(
      type: type,
      subtype: subtype,
    );
    if (subtypeFailure != null) return Result.failure(subtypeFailure);
    final creditFailure = _validateCreditFields(
      type: type,
      creditLimit: creditLimit,
      billingDay: billingDay,
      repaymentDay: repaymentDay,
    );
    if (creditFailure != null) return Result.failure(creditFailure);

    return Result.success(
      Account(
        id: id,
        name: normalizedName,
        type: type,
        subtype: subtype,
        balance: const Money(minorUnits: 0),
        iconKey: trimToNull(iconKey),
        note: trimToNull(note),
        creditLimit: creditLimit,
        billingDay: billingDay,
        repaymentDay: repaymentDay,
        sortOrder: sortOrder,
        isHidden: isHidden,
      ),
    );
  }

  Failure? _validateCreditFields({
    required AccountType type,
    required Money? creditLimit,
    required int? billingDay,
    required int? repaymentDay,
  }) {
    if (type != AccountType.liability &&
        (creditLimit != null || billingDay != null || repaymentDay != null)) {
      return const Failure(
        code: 'credit_profile_not_supported',
        message: 'Credit profile is only supported for liability accounts.',
      );
    }
    if (creditLimit != null && creditLimit.minorUnits < 0) {
      return const Failure(
        code: 'credit_limit_negative',
        message: 'Credit limit cannot be negative.',
      );
    }
    if (billingDay != null && (billingDay < 1 || billingDay > 31)) {
      return const Failure(
        code: 'billing_day_invalid',
        message: 'Billing day must be between 1 and 31.',
      );
    }
    if (repaymentDay != null && (repaymentDay < 1 || repaymentDay > 31)) {
      return const Failure(
        code: 'repayment_day_invalid',
        message: 'Repayment day must be between 1 and 31.',
      );
    }
    return null;
  }
}
