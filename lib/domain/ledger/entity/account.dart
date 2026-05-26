import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../valobj/ledger_enum.dart';
import '../service/ledger_rule.dart';
import '../valobj/post_receipt.dart';
import 'transaction.dart';

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

  final int id;
  final String name;
  final AccountType type;
  final AccountSubtype? subtype;
  final int? parentId;
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

  /// 重命名。null 表示不改;trim 后非空才更新。
  Result<Account> renamed(String? name) {
    if (name == null) return Result.success(this);
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Result.failure(
        Failure(
          code: 'account_name_required',
          message: 'Account name is required.',
        ),
      );
    }
    if (trimmed == this.name) return Result.success(this);
    return Result.success(copyWith(name: trimmed));
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
    int? parentId,
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
}
