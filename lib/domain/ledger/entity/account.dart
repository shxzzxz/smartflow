import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../valobj/ledger_enum.dart';
import '../service/ledger_rule.dart';
import '../valobj/post_receipt.dart';
import 'transaction.dart';

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
  const Account({
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
    this.systemKey,
    this.source = AccountSource.user,
  });

  final String id;
  final String name;
  final AccountType type;
  final AccountSubtype? subtype;
  final String? parentId;
  final Money balance;
  final String? iconKey;
  final String? note;
  final Money? creditLimit;
  final int? billingDay;
  final int? repaymentDay;
  final int sortOrder;
  final bool isHidden;
  final DateTime? archivedAt;
  final SystemKey? systemKey;
  final AccountSource source;

  bool get isArchived => archivedAt != null;

  bool get supportsManualBalance => type.supportsManualBalance(subtype);

  static Result<Account> createUserAccount({
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
    final normalizedName = _normalizeRequiredName(name);
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
    final creditFailure = _validateCreditFields(
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
        iconKey: _blankToNull(iconKey),
        note: _blankToNull(note),
        creditLimit: creditLimit,
        billingDay: billingDay,
        repaymentDay: repaymentDay,
        sortOrder: sortOrder,
        isHidden: isHidden,
      ),
    );
  }

  static Result<Account> createCategory({
    required String id,
    required String name,
    required AccountType type,
    Account? parent,
    String? iconKey,
    String? note,
    int sortOrder = 0,
  }) {
    final normalizedName = _normalizeRequiredName(name);
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
        iconKey: _blankToNull(iconKey),
        note: _blankToNull(note),
        sortOrder: sortOrder,
      ),
    );
  }

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

  Result<Account> changeProfile(AccountProfilePatch patch) {
    final editFailure = checkEditable();
    if (editFailure != null) return Result.failure(editFailure);
    final normalizedName =
        patch.name == null ? name : _normalizeRequiredName(patch.name!);
    if (normalizedName == null) {
      return const Result.failure(
        Failure(
          code: 'account_name_required',
          message: 'Account name is required.',
        ),
      );
    }

    return Result.success(
      Account(
        id: id,
        name: normalizedName,
        type: type,
        subtype: _applyPatch(subtype, patch.subtype),
        parentId: parentId,
        balance: balance,
        iconKey: _applyStringPatch(iconKey, patch.iconKey),
        note: _applyStringPatch(note, patch.note),
        creditLimit: creditLimit,
        billingDay: billingDay,
        repaymentDay: repaymentDay,
        sortOrder: patch.sortOrder ?? sortOrder,
        isHidden: patch.isHidden ?? isHidden,
        archivedAt: archivedAt,
        systemKey: systemKey,
        source: source,
      ),
    );
  }

  Result<Account> changeCreditProfile(AccountCreditProfilePatch patch) {
    final editFailure = checkEditable();
    if (editFailure != null) return Result.failure(editFailure);
    final nextCreditLimit = _applyPatch(creditLimit, patch.creditLimit);
    final nextBillingDay = _applyPatch(billingDay, patch.billingDay);
    final nextRepaymentDay = _applyPatch(repaymentDay, patch.repaymentDay);
    final failure = _validateCreditFields(
      creditLimit: nextCreditLimit,
      billingDay: nextBillingDay,
      repaymentDay: nextRepaymentDay,
    );
    if (failure != null) return Result.failure(failure);

    return Result.success(
      Account(
        id: id,
        name: name,
        type: type,
        subtype: subtype,
        parentId: parentId,
        balance: balance,
        iconKey: iconKey,
        note: note,
        creditLimit: nextCreditLimit,
        billingDay: nextBillingDay,
        repaymentDay: nextRepaymentDay,
        sortOrder: sortOrder,
        isHidden: isHidden,
        archivedAt: archivedAt,
        systemKey: systemKey,
        source: source,
      ),
    );
  }

  Result<Account> moveCategoryTo(Account? parent) {
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
    return Result.success(
      Account(
        id: id,
        name: name,
        type: type,
        subtype: subtype,
        parentId: parent?.id,
        balance: balance,
        iconKey: iconKey,
        note: note,
        creditLimit: creditLimit,
        billingDay: billingDay,
        repaymentDay: repaymentDay,
        sortOrder: sortOrder,
        isHidden: isHidden,
        archivedAt: archivedAt,
        systemKey: systemKey,
        source: source,
      ),
    );
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

  Account applyTransaction(Transaction transaction) {
    var account = this;
    for (final entry in transaction.entries) {
      if (entry.accountId != id) continue;
      account = account.applyEntryImpact(entry);
    }
    return account;
  }

  Account applyEntryImpact(ReceiptEntry entry) {
    final delta = balanceDeltaMinor(
      accountType: type,
      direction: entry.direction,
      amountMinor: entry.amount.minorUnits,
    );
    return copyWith(balance: Money(minorUnits: balance.minorUnits + delta));
  }

  Account removeEntryImpact(ReceiptEntry entry) {
    final delta = balanceDeltaMinor(
      accountType: type,
      direction: entry.direction,
      amountMinor: entry.amount.minorUnits,
    );
    return copyWith(balance: Money(minorUnits: balance.minorUnits - delta));
  }

  Account copyWith({
    String? name,
    AccountType? type,
    AccountSubtype? subtype,
    String? parentId,
    Money? balance,
    String? iconKey,
    String? note,
    Money? creditLimit,
    int? billingDay,
    int? repaymentDay,
    int? sortOrder,
    bool? isHidden,
    DateTime? archivedAt,
    SystemKey? systemKey,
    AccountSource? source,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      parentId: parentId ?? this.parentId,
      balance: balance ?? this.balance,
      iconKey: iconKey ?? this.iconKey,
      note: note ?? this.note,
      creditLimit: creditLimit ?? this.creditLimit,
      billingDay: billingDay ?? this.billingDay,
      repaymentDay: repaymentDay ?? this.repaymentDay,
      sortOrder: sortOrder ?? this.sortOrder,
      isHidden: isHidden ?? this.isHidden,
      archivedAt: archivedAt ?? this.archivedAt,
      systemKey: systemKey ?? this.systemKey,
      source: source ?? this.source,
    );
  }

  static String? _normalizeRequiredName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static T? _applyPatch<T>(T? current, Patch<T>? patch) {
    return switch (patch) {
      null => current,
      PatchClear<T>() => null,
      PatchSet<T>(:final value) => value,
    };
  }

  static String? _applyStringPatch(String? current, Patch<String>? patch) {
    return switch (patch) {
      null => current,
      PatchClear<String>() => null,
      PatchSet<String>(:final value) => _blankToNull(value),
    };
  }

  static Failure? _validateCreditFields({
    required Money? creditLimit,
    required int? billingDay,
    required int? repaymentDay,
  }) {
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
