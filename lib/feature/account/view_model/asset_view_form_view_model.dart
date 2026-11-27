import 'package:flutter/foundation.dart' show setEquals;
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/analytics/analytics_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../domain/analytics/valobj/analytics_error_code.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'asset_view_form_view_model.g.dart';

final _logger = Logger('feature.asset_view_form');

class AssetViewFormState {
  AssetViewFormState({
    this.id,
    this.expectedVersion,
    this.source,
    this.name = '',
    Iterable<String> accountIds = const [],
    this.hasChanges = false,
    this.submitting = false,
  }) : accountIds = Set.unmodifiable(accountIds);
  final String? id;
  final int? expectedVersion;
  final AssetView? source;
  final String name;
  final Set<String> accountIds;
  final bool hasChanges;
  final bool submitting;
  bool get isBuiltin => id == AssetView.defaultId;
  bool get canSave =>
      !submitting &&
      name.trim().isNotEmpty &&
      (isBuiltin || accountIds.isNotEmpty) &&
      (id == null || hasChanges);
  AssetViewFormState copyWith({
    String? name,
    Iterable<String>? accountIds,
    bool? hasChanges,
    bool? submitting,
  }) => AssetViewFormState(
    id: id,
    expectedVersion: expectedVersion,
    source: source,
    name: name ?? this.name,
    accountIds: accountIds ?? this.accountIds,
    hasChanges: hasChanges ?? this.hasChanges,
    submitting: submitting ?? this.submitting,
  );
}

@riverpod
class AssetViewFormViewModel extends _$AssetViewFormViewModel {
  @override
  Future<AssetViewFormState> build(String? viewId, AssetView? copyFrom) async {
    final accountsQuery = ref.watch(accountQueryServiceProvider);
    final viewsQuery = ref.watch(assetViewQueryServiceProvider);
    if (copyFrom != null) {
      final accounts = (await accountsQuery.findAccountsById()).values
          .where(
            (account) =>
                (account.type == AccountType.asset ||
                    account.type == AccountType.liability) &&
                copyFrom.includesAccount(account.id),
          )
          .map((account) => account.id)
          .toSet();
      final names = (await viewsQuery.findViews())
          .map((view) => view.name)
          .toSet();
      final base =
          '${copyFrom.name.length > 110 ? copyFrom.name.substring(0, 110) : copyFrom.name} 副本';
      var name = base;
      var suffix = 2;
      while (names.contains(name)) {
        name = '$base ($suffix)';
        suffix++;
      }
      return AssetViewFormState(
        name: name,
        accountIds: accounts,
        source: copyFrom,
      );
    }
    if (viewId == null) return AssetViewFormState();
    final view = await viewsQuery.findView(viewId);
    if (view == null) throw BusinessException(AnalyticsErrorCode.viewNotFound);
    return AssetViewFormState(
      id: view.id,
      expectedVersion: view.version,
      name: view.name,
      accountIds: view.accountIds,
      source: view,
    );
  }

  void setName(String name) {
    final value = state.requireValue;
    if (value.name != name) {
      state = AsyncData(value.copyWith(name: name, hasChanges: true));
    }
  }

  void setAccounts(Set<String> ids) {
    final value = state.requireValue;
    if (!setEquals(value.accountIds, ids)) {
      state = AsyncData(value.copyWith(accountIds: ids, hasChanges: true));
    }
  }

  Future<UiActionOutcome<AssetView>> save() async {
    final value = state.requireValue;
    if (value.submitting) {
      return const UiActionOutcome.failure(UiError.unknown());
    }
    state = AsyncData(value.copyWith(submitting: true));
    try {
      return await guardUiAction(
        _logger,
        'Save asset view',
        () => ref
            .read(assetViewAppServiceProvider)
            .saveView(
              SaveAssetViewCommand(
                id: value.id,
                expectedVersion: value.expectedVersion,
                copyFrom: value.id == null ? value.source : null,
                name: value.name,
                accountIds: value.accountIds,
              ),
            ),
      );
    } finally {
      if (ref.mounted) state = AsyncData(value.copyWith(submitting: false));
    }
  }
}

class AssetViewFormPageState {
  const AssetViewFormPageState({required this.editor, required this.accounts});
  final AssetViewFormState editor;
  final List<Account> accounts;
}

@riverpod
AsyncValue<AssetViewFormPageState> assetViewFormPage(
  Ref ref,
  String? viewId,
  AssetView? copyFrom,
) {
  final editor = ref.watch(assetViewFormViewModelProvider(viewId, copyFrom));
  final accounts = ref.watch(accountListProvider);
  for (final value in <AsyncValue<Object?>>[editor, accounts]) {
    if (value.hasError) return AsyncError(value.error!, value.stackTrace!);
  }
  if (!editor.hasValue || !accounts.hasValue) return const AsyncLoading();
  return AsyncData(
    AssetViewFormPageState(
      editor: editor.requireValue,
      accounts: accounts.requireValue,
    ),
  );
}
