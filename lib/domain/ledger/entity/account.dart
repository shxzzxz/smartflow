import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../valobj/ledger_error_code.dart';
import '../valobj/ledger_enum.dart';
import '../valobj/ledger_violation_reason.dart';
import '../service/posting/posting_rule.dart';
import 'entry.dart';

class AccountProfilePatch {
  const AccountProfilePatch({
    this.name,
    this.sortOrder,
    this.isHidden,
    this.subtype,
    this.profileKey,
    this.groupId,
    this.iconKey,
    this.note,
  });

  final String? name;
  final int? sortOrder;
  final bool? isHidden;
  final Patch<AccountSubtype>? subtype;
  final Patch<String>? profileKey;
  final Patch<String>? groupId;
  final Patch<String>? iconKey;
  final Patch<String>? note;
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
    this.profileKey,
    this.groupId,
    this.parentId,
    this.iconKey,
    this.note,
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
  String? profileKey;
  String? groupId;
  String? parentId;
  Money balance;
  String? iconKey;
  String? note;
  int sortOrder;
  bool isHidden;
  DateTime? archivedAt;
  int version;

  bool get isArchived => archivedAt != null;

  bool get isManageableCategory => type.isCategory && systemKey == null;

  bool get supportsManualBalance => type.supportsManualBalance(subtype);

  void archive(DateTime archivedAt) {
    if (!type.isUserAccount || systemKey != null) {
      LedgerViolationReason.accountArchiveNotAllowed.throwException();
    }
    if (isArchived) {
      LedgerViolationReason.accountArchived.throwException();
    }
    this.archivedAt = archivedAt;
  }

  void restore() {
    if (!type.isUserAccount || systemKey != null) {
      LedgerViolationReason.accountArchiveNotAllowed.throwException();
    }
    if (!isArchived) {
      throw BusinessException(
        LedgerErrorCode.accountUnavailable,
        message: 'Account is not archived.',
      );
    }
    archivedAt = null;
  }

  void moveToGroup(String? groupId, {required int sortOrder}) {
    _ensureUserAccountEditable();
    this.groupId = trimToNull(groupId);
    this.sortOrder = sortOrder;
  }

  /// 是否可以作为"用户账户"被编辑(通过 EditAccountCommand 修改属性)。
  /// 系统类账户(income / expense / equity)走 CategoryService 或其它路径。
  LedgerViolationReason? checkEditable() {
    if (isArchived) {
      return LedgerViolationReason.accountArchived;
    }
    if (!type.isUserAccount) {
      return LedgerViolationReason.accountTypeNotEditable;
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
    profileKey = patch.profileKey.applyMappedTo(profileKey, trimToNull);
    groupId = patch.groupId.applyMappedTo(groupId, trimToNull);
    iconKey = patch.iconKey.applyMappedTo(iconKey, trimToNull);
    note = patch.note.applyMappedTo(note, trimToNull);
    sortOrder = patch.sortOrder ?? sortOrder;
    isHidden = patch.isHidden ?? isHidden;
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

  LedgerViolationReason? checkBalanceAdjustmentTarget(Money target) {
    if (isArchived) {
      return LedgerViolationReason.accountArchived;
    }
    if (!supportsManualBalance) {
      return LedgerViolationReason.accountTargetBalanceNotSupported;
    }
    if (target.minorUnits < 0) {
      return LedgerViolationReason.accountTargetBalanceNegative;
    }
    final deltaMinor = target.minorUnits - balance.minorUnits;
    if (deltaMinor == 0) {
      return LedgerViolationReason.balanceAdjustmentZeroDelta;
    }
    return null;
  }

  Money balanceDeltaTo(Money target) {
    return Money(minorUnits: target.minorUnits - balance.minorUnits);
  }

  /// 校验当前账户能否作为新分类的父节点。
  /// 当前实现限制分类树为二层(顶层 + 子节点),所以 parent 自己不能再有 parent。
  LedgerViolationReason? checkValidCategoryParent(AccountType expectedType) {
    if (isArchived) {
      return LedgerViolationReason.categoryParentArchived;
    }
    if (type != expectedType) {
      return LedgerViolationReason.categoryParentTypeMismatch;
    }
    if (parentId != null) {
      return LedgerViolationReason.categoryDepthExceeded;
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

  static LedgerViolationReason? validateSubtypeCompatibility({
    required AccountType type,
    required AccountSubtype? subtype,
  }) {
    if (subtype == null) return null;
    if (isSubtypeCompatible(type: type, subtype: subtype)) return null;
    return LedgerViolationReason.accountSubtypeTypeMismatch;
  }

  static bool isSubtypeCompatible({
    required AccountType type,
    required AccountSubtype? subtype,
  }) {
    if (subtype == null) return true;
    return switch (type) {
      AccountType.asset => subtype == AccountSubtype.reimbursement,
      AccountType.liability => false,
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
}
