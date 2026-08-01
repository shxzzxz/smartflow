import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'data_cleanup_view_model.g.dart';

class DataCleanupState {
  const DataCleanupState({
    this.categoryIds = const {},
    this.accountIds = const {},
    this.occurredFrom,
    this.occurredUntilExclusive,
    this.submitting = false,
  });

  /// 选中的分类账户 ID；空集合表示不限分类。
  final Set<String> categoryIds;

  /// 选中的资金/负债账户 ID；空集合表示不限账户。
  final Set<String> accountIds;

  final DateTime? occurredFrom;

  /// 排他端点；与 [occurredFrom] 同时为 null 表示不限时间。
  final DateTime? occurredUntilExclusive;

  final bool submitting;

  bool get hasTimeRange =>
      occurredFrom != null && occurredUntilExclusive != null;

  TransactionCleanupQuery toQuery() {
    return TransactionCleanupQuery(
      categoryIds: categoryIds.isEmpty ? null : categoryIds,
      accountIds: accountIds.isEmpty ? null : accountIds,
      occurredFrom: occurredFrom,
      occurredUntil: occurredUntilExclusive,
    );
  }

  static const _sentinel = Object();

  DataCleanupState copyWith({
    Set<String>? categoryIds,
    Set<String>? accountIds,
    Object? occurredFrom = _sentinel,
    Object? occurredUntilExclusive = _sentinel,
    bool? submitting,
  }) {
    return DataCleanupState(
      categoryIds: categoryIds ?? this.categoryIds,
      accountIds: accountIds ?? this.accountIds,
      occurredFrom:
          occurredFrom == _sentinel
              ? this.occurredFrom
              : occurredFrom as DateTime?,
      occurredUntilExclusive:
          occurredUntilExclusive == _sentinel
              ? this.occurredUntilExclusive
              : occurredUntilExclusive as DateTime?,
      submitting: submitting ?? this.submitting,
    );
  }
}

@riverpod
class DataCleanupViewModel extends _$DataCleanupViewModel {
  @override
  DataCleanupState build() => const DataCleanupState();

  void setCategoryIds(Set<String> ids) {
    state = state.copyWith(categoryIds: Set.unmodifiable(ids));
  }

  void setAccountIds(Set<String> ids) {
    state = state.copyWith(accountIds: Set.unmodifiable(ids));
  }

  Future<List<CategoryNode>> categoryTreeOptions(AccountType type) {
    return ref.read(categoryQueryServiceProvider).findCategoryTree(type);
  }

  Future<List<Account>> accountOptions() {
    return ref.read(accountQueryServiceProvider).findAccounts({
      AccountType.asset,
      AccountType.liability,
    });
  }

  /// [from] 与 [untilInclusive] 都是日历日；范围换算为排他端点存储。
  void setTimeRange({required DateTime from, required DateTime untilInclusive}) {
    final start = DateTime(from.year, from.month, from.day);
    final untilExclusive = DateTime(
      untilInclusive.year,
      untilInclusive.month,
      untilInclusive.day + 1,
    );
    state = state.copyWith(
      occurredFrom: start,
      occurredUntilExclusive: untilExclusive,
    );
  }

  void clearTimeRange() {
    state = state.copyWith(occurredFrom: null, occurredUntilExclusive: null);
  }

  Future<UiActionOutcome<TransactionCleanupResult>> cleanup() async {
    if (state.submitting) {
      return const UiActionOutcome.failure(
        UiError(code: 'cleanup_in_progress', message: '清理正在进行中'),
      );
    }
    state = state.copyWith(submitting: true);
    try {
      final query = state.toQuery();
      final result = await ref
          .read(transactionCleanupAppServiceProvider)
          .cleanupTransactions(
            CleanupTransactionsCommand(
              categoryIds: query.categoryIds,
              accountIds: query.accountIds,
              occurredFrom: query.occurredFrom,
              occurredUntil: query.occurredUntil,
            ),
          );
      return UiActionOutcome.success(result);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(UiError.unknown());
    } finally {
      state = state.copyWith(submitting: false);
    }
  }
}

@riverpod
Stream<TransactionCleanupPreview> dataCleanupPreview(Ref ref) {
  final (categoryIds, accountIds, occurredFrom, occurredUntilExclusive) = ref
      .watch(
        dataCleanupViewModelProvider.select(
          (state) => (
            state.categoryIds,
            state.accountIds,
            state.occurredFrom,
            state.occurredUntilExclusive,
          ),
        ),
      );
  return ref
      .watch(transactionQueryServiceProvider)
      .watchCleanupPreview(
        TransactionCleanupQuery(
          categoryIds: categoryIds.isEmpty ? null : categoryIds,
          accountIds: accountIds.isEmpty ? null : accountIds,
          occurredFrom: occurredFrom,
          occurredUntil: occurredUntilExclusive,
        ),
      );
}
