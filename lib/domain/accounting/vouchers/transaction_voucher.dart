import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../entities/account.dart';
import '../entities/account_usage.dart';
import '../enums/accounting_enums.dart';
import '../ledger/posting_protocol.dart';
import '../repositories/account_repository.dart';
import '../repositories/system_account_resolver.dart';
import '../services/transaction_query_service.dart';

/// 凭证组装器:每个业务流图原语一个 Voucher。
///
/// - `build` 返回蓝字方向的 PostTransactionCommand;mutation 元数据
///   (mutationKind / mutationPreviousTransactionId / businessState 等)
///   不在 voucher 内设置,由 [VoucherRunner] 注入。
/// - 同一 voucher 同时服务 create 与 correction 路径:差异通过输入类型自身的
///   工厂(`fromCreate / fromCorrect`)体现。
abstract class TransactionVoucher<I> {
  const TransactionVoucher();

  /// 输入校验 + 必要数据查询 + 组装。
  /// 失败原因(金额非正、币种不一致、必填账户缺失、依赖数据缺失等)
  /// 一律以 [Failure] 返回。
  Future<Result<PostTransactionCommand>> build(I input, VoucherContext ctx);
}

/// Voucher 共享的领域能力:账户查找、查询服务、系统科目解析。
/// 同时提供两个高频校验 helper,避免每个 voucher 各写一遍。
class VoucherContext {
  const VoucherContext({
    required this.accountRepository,
    required this.queryService,
    required this.systemAccountResolver,
  });

  final AccountRepository accountRepository;
  final TransactionQueryService queryService;
  final SystemAccountResolver systemAccountResolver;

  /// 同时校验账户类型与 usage。types / usages 任一为空则跳过对应检查。
  Future<Failure?> validateAccountConstraints({
    Map<int, Set<AccountType>> types = const {},
    Map<int, AccountUsage> usages = const {},
  }) async {
    final typeFailure = await validateAccountRoles(types);
    if (typeFailure != null) {
      return typeFailure;
    }
    return validateAccountUsages(usages);
  }

  Future<Failure?> validateAccountRoles(
    Map<int, Set<AccountType>> expectedTypesByAccountId,
  ) async {
    if (expectedTypesByAccountId.isEmpty) return null;
    final accounts = await accountRepository.findAccountsByIds(
      expectedTypesByAccountId.keys.toSet(),
    );
    final accountsById = {for (final account in accounts) account.id: account};
    for (final MapEntry(key: accountId, value: expectedTypes)
        in expectedTypesByAccountId.entries) {
      final account = accountsById[accountId];
      if (account == null) {
        return Failure(
          code: 'account_not_found',
          message: 'Account $accountId does not exist.',
        );
      }
      if (account.archivedAt != null) {
        return Failure(
          code: 'account_archived',
          message: 'Account $accountId is archived.',
        );
      }
      if (!expectedTypes.contains(account.type)) {
        return Failure(
          code: 'account_role_invalid',
          message: 'Account $accountId cannot be used for this transaction.',
        );
      }
    }
    return null;
  }

  Future<Failure?> validateAccountUsages(
    Map<int, AccountUsage> expectedUsageByAccountId,
  ) async {
    if (expectedUsageByAccountId.isEmpty) return null;
    final accounts = await accountRepository.findAccountsByIds(
      expectedUsageByAccountId.keys.toSet(),
    );
    final accountsById = {for (final account in accounts) account.id: account};
    for (final MapEntry(key: accountId, value: usage)
        in expectedUsageByAccountId.entries) {
      final account = accountsById[accountId];
      if (account == null) {
        return Failure(
          code: 'account_not_found',
          message: 'Account $accountId does not exist.',
        );
      }
      if (!accountMatchesUsage(account, usage)) {
        return Failure(
          code: account.archivedAt == null
              ? 'account_role_invalid'
              : 'account_archived',
          message: 'Account $accountId cannot be used for this transaction.',
        );
      }
    }
    return null;
  }

  Future<Map<int, AccountType>> loadAccountTypes(
    Iterable<int> accountIds,
  ) async {
    final ids = accountIds.toSet();
    if (ids.isEmpty) return const {};
    final accounts = await accountRepository.findAccountsByIds(ids);
    return {for (final account in accounts) account.id: account.type};
  }

  Future<Map<int, Account>> loadAccountsByIds(Iterable<int> accountIds) async {
    final ids = accountIds.toSet();
    if (ids.isEmpty) return const {};
    final accounts = await accountRepository.findAccountsByIds(ids);
    return {for (final account in accounts) account.id: account};
  }
}
