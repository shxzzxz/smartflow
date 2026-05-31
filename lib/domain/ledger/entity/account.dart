import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../../../core/text/text_normalizer.dart';
import '../valobj/ledger_enum.dart';
import '../service/ledger_rule.dart';
import 'entry.dart';

class AccountProfilePatch {
  const AccountProfilePatch({
    this.name,
    this.sortOrder,
    this.isHidden,
    this.subtype,
    this.iconKey,
    this.note,
  });

  final String? name;
  final int? sortOrder;
  final bool? isHidden;
  final Patch<AccountSubtype>? subtype;
  final Patch<String>? iconKey;
  final Patch<String>? note;
}

class AccountCreditProfilePatch {
  const AccountCreditProfilePatch({
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
  });

  final Patch<Money>? creditLimit;
  final Patch<int>? billingDay;
  final Patch<int>? repaymentDay;
}

class Account {
  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.subtype,
    this.parentId,
    this.iconKey,
    this.note,
    this.creditLimit,
    this.billingDay,
    this.repaymentDay,
    this.sortOrder = 0,
    this.isHidden = false,
    this.archivedAt,
    this.version = 0,
    this.systemKey,
    this.source = AccountSource.user,
  });

  final String id;
  final AccountType type;
  final SystemKey? systemKey;
  final AccountSource source;
  String name;
  AccountSubtype? subtype;
  String? parentId;
  Money balance;
  String? iconKey;
  String? note;
  Money? creditLimit;
  int? billingDay;
  int? repaymentDay;
  int sortOrder;
  bool isHidden;
  DateTime? archivedAt;
  int version;

  bool get isArchived => archivedAt != null;

  bool get supportsManualBalance => type.supportsManualBalance(subtype);

  /// 是否可以作为"用户账户"被编辑(通过 EditAccountCommand 修改属性)。
  /// 系统类账户(income / expense / equity)走 CategoryService 或其它路径。
  Failure? checkEditable() {
    if (isArchived) {
      return const Failure(
        code: 'account_archived',
        message: 'Archived account cannot be edited.',
      );
    }
    if (!type.isUserAccount) {
      return const Failure(
        code: 'account_type_not_editable',
        message: 'Only asset and liability account can be edited here.',
      );
    }
    return null;
  }

  Result<void> changeProfile(AccountProfilePatch patch) {
    final editFailure = checkEditable();
    if (editFailure != null) return Result.failure(editFailure);
    final normalizedName = patch.name == null ? name : trimToNull(patch.name);
    if (normalizedName == null) {
      return const Result.failure(
        Failure(
          code: 'account_name_required',
          message: 'Account name is required.',
        ),
      );
    }
    final nextSubtype = patch.subtype.applyTo(subtype);
    final subtypeFailure = validateSubtypeCompatibility(
      type: type,
      subtype: nextSubtype,
    );
    if (subtypeFailure != null) return Result.failure(subtypeFailure);

    name = normalizedName;
    subtype = nextSubtype;
    iconKey = patch.iconKey.applyMappedTo(iconKey, trimToNull);
    note = patch.note.applyMappedTo(note, trimToNull);
    sortOrder = patch.sortOrder ?? sortOrder;
    isHidden = patch.isHidden ?? isHidden;
    return const Result.success(null);
  }

  Result<void> changeCreditProfile(AccountCreditProfilePatch patch) {
    final editFailure = checkEditable();
    if (editFailure != null) return Result.failure(editFailure);
    final nextCreditLimit = patch.creditLimit.applyTo(creditLimit);
    final nextBillingDay = patch.billingDay.applyTo(billingDay);
    final nextRepaymentDay = patch.repaymentDay.applyTo(repaymentDay);
    final failure = _validateCreditFields(
      type: type,
      creditLimit: nextCreditLimit,
      billingDay: nextBillingDay,
      repaymentDay: nextRepaymentDay,
    );
    if (failure != null) return Result.failure(failure);

    creditLimit = nextCreditLimit;
    billingDay = nextBillingDay;
    repaymentDay = nextRepaymentDay;
    return const Result.success(null);
  }

  Result<void> moveCategoryTo(Account? parent) {
    if (!type.isCategory) {
      return const Result.failure(
        Failure(
          code: 'category_type_invalid',
          message: 'Only income and expense category can be moved.',
        ),
      );
    }
    if (parent != null) {
      final failure = parent.checkValidCategoryParent(type);
      if (failure != null) return Result.failure(failure);
    }
    parentId = parent?.id;
    return const Result.success(null);
  }

  /// 计算把余额调整到 [target] 所需的 signed delta(可负)。
  /// archived / 不支持手动调整 / 目标负数 / delta == 0 均视为失败。
  Result<Money> targetBalanceDeltaTo(Money target) {
    if (isArchived) {
      return const Result.failure(
        Failure(
          code: 'account_archived',
          message: 'Cannot adjust archived account.',
        ),
      );
    }
    if (!supportsManualBalance) {
      return const Result.failure(
        Failure(
          code: 'account_target_balance_not_supported',
          message: 'This account type does not support balance adjustment.',
        ),
      );
    }
    if (target.minorUnits < 0) {
      return const Result.failure(
        Failure(
          code: 'account_target_balance_negative',
          message: 'Target balance cannot be negative.',
        ),
      );
    }
    final deltaMinor = target.minorUnits - balance.minorUnits;
    if (deltaMinor == 0) {
      return const Result.failure(
        Failure(
          code: 'balance_adjustment_zero_delta',
          message: 'Balance is already at the target value.',
        ),
      );
    }
    return Result.success(Money(minorUnits: deltaMinor));
  }

  /// 校验当前账户能否作为新分类的父节点。
  /// 当前实现限制分类树为二层(顶层 + 子节点),所以 parent 自己不能再有 parent。
  Failure? checkValidCategoryParent(AccountType expectedType) {
    if (isArchived) {
      return const Failure(
        code: 'category_parent_archived',
        message: 'Archived category cannot be used as parents.',
      );
    }
    if (type != expectedType) {
      return const Failure(
        code: 'category_parent_type_mismatch',
        message: 'Parent category type must match child category type.',
      );
    }
    if (parentId != null) {
      return const Failure(
        code: 'category_depth_exceeded',
        message: 'Categories support one child level in this stage.',
      );
    }
    return null;
  }

  void applyEntryImpact(Entry entry) {
    final delta = balanceDeltaMinor(
      accountType: type,
      direction: entry.direction,
      amountMinor: entry.amount.minorUnits,
    );
    balance = Money(minorUnits: balance.minorUnits + delta);
  }

  void applyEntryImpacts(Iterable<Entry> entries) {
    for (final entry in entries) {
      if (entry.accountId == id) {
        applyEntryImpact(entry);
      }
    }
  }

  void removeEntryImpact(Entry entry) {
    final delta = balanceDeltaMinor(
      accountType: type,
      direction: entry.direction,
      amountMinor: entry.amount.minorUnits,
    );
    balance = Money(minorUnits: balance.minorUnits - delta);
  }

  static Failure? validateSubtypeCompatibility({
    required AccountType type,
    required AccountSubtype? subtype,
  }) {
    if (subtype == null) return null;
    final compatible = switch (type) {
      AccountType.asset =>
        subtype == AccountSubtype.cash ||
            subtype == AccountSubtype.bankCard ||
            subtype == AccountSubtype.thirdParty ||
            subtype == AccountSubtype.investment ||
            subtype == AccountSubtype.reimbursement,
      AccountType.liability =>
        subtype == AccountSubtype.creditCard ||
            subtype == AccountSubtype.loan ||
            subtype == AccountSubtype.consumerCredit,
      AccountType.equity || AccountType.income || AccountType.expense => false,
    };
    if (compatible) return null;
    return const Failure(
      code: 'account_subtype_type_mismatch',
      message: 'Account subtype does not match account type.',
    );
  }

  static Failure? _validateCreditFields({
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
