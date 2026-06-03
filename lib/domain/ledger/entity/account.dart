import '../../../core/error/failure.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../../../core/text/text_normalizer.dart';
import '../valobj/ledger_error_code.dart';
import '../valobj/ledger_enum.dart';
import '../service/posting/posting_rule.dart';
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

class CategoryProfilePatch {
  const CategoryProfilePatch({this.name, this.iconKey, this.note});

  final String? name;
  final Patch<String>? iconKey;
  final Patch<String>? note;
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

  void changeProfile(AccountProfilePatch patch) {
    _ensureUserAccountEditable();
    final normalizedName = patch.name == null ? name : trimToNull(patch.name);
    if (normalizedName == null) {
      throw BusinessException(
        LedgerErrorCode.accountInvalidCommand,
        message: 'Account name is required.',
      );
    }
    final nextSubtype = patch.subtype.applyTo(subtype);
    _ensureSubtypeCompatibility(type: type, subtype: nextSubtype);

    name = normalizedName;
    subtype = nextSubtype;
    iconKey = patch.iconKey.applyMappedTo(iconKey, trimToNull);
    note = patch.note.applyMappedTo(note, trimToNull);
    sortOrder = patch.sortOrder ?? sortOrder;
    isHidden = patch.isHidden ?? isHidden;
  }

  void changeCreditProfile(AccountCreditProfilePatch patch) {
    _ensureUserAccountEditable();
    final nextCreditLimit = patch.creditLimit.applyTo(creditLimit);
    final nextBillingDay = patch.billingDay.applyTo(billingDay);
    final nextRepaymentDay = patch.repaymentDay.applyTo(repaymentDay);
    _ensureCreditFields(
      type: type,
      creditLimit: nextCreditLimit,
      billingDay: nextBillingDay,
      repaymentDay: nextRepaymentDay,
    );

    creditLimit = nextCreditLimit;
    billingDay = nextBillingDay;
    repaymentDay = nextRepaymentDay;
  }

  void moveCategoryTo(Account? parent) {
    _ensureCategoryEditable();
    if (!type.isCategory) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidCommand,
        message: 'Only income and expense category can be moved.',
      );
    }
    if (parent != null) {
      parent._ensureValidCategoryParent(type);
    }
    parentId = parent?.id;
  }

  void changeCategoryProfile(CategoryProfilePatch patch) {
    _ensureCategoryEditable();
    if (!type.isCategory) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidCommand,
        message: 'Only income and expense category can be edited.',
      );
    }
    final normalizedName = patch.name == null ? name : trimToNull(patch.name);
    if (normalizedName == null) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidCommand,
        message: 'Category name is required.',
      );
    }

    name = normalizedName;
    iconKey = patch.iconKey.applyMappedTo(iconKey, trimToNull);
    note = patch.note.applyMappedTo(note, trimToNull);
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
    if (isSubtypeCompatible(type: type, subtype: subtype)) return null;
    return const Failure(
      code: 'account_subtype_type_mismatch',
      message: 'Account subtype does not match account type.',
    );
  }

  static bool isSubtypeCompatible({
    required AccountType type,
    required AccountSubtype? subtype,
  }) {
    if (subtype == null) return true;
    return switch (type) {
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
  }

  void _ensureUserAccountEditable() {
    if (isArchived) {
      throw BusinessException(
        LedgerErrorCode.accountUnavailable,
        message: 'Archived account cannot be edited.',
      );
    }
    if (!type.isUserAccount) {
      throw BusinessException(
        LedgerErrorCode.accountUnavailable,
        message: 'Only asset and liability account can be edited here.',
      );
    }
  }

  void _ensureCategoryEditable() {
    if (isArchived) {
      throw BusinessException(
        LedgerErrorCode.categoryUnavailable,
        message: 'Archived category cannot be edited.',
      );
    }
  }

  void _ensureValidCategoryParent(AccountType expectedType) {
    if (isArchived) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidParent,
        message: 'Archived category cannot be used as parent.',
      );
    }
    if (type != expectedType) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidParent,
        message: 'Parent category type must match child category type.',
      );
    }
    if (parentId != null) {
      throw BusinessException(
        LedgerErrorCode.categoryInvalidParent,
        message: 'Categories support one child level in this stage.',
      );
    }
  }

  static void _ensureSubtypeCompatibility({
    required AccountType type,
    required AccountSubtype? subtype,
  }) {
    if (isSubtypeCompatible(type: type, subtype: subtype)) return;
    throw BusinessException(
      LedgerErrorCode.accountInvalidCommand,
      message: 'Account subtype does not match account type.',
    );
  }

  static void _ensureCreditFields({
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
