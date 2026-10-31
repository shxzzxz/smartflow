import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../core/money/money.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'amortization_form_view_model.g.dart';

final _logger = Logger('feature.amortization.form');

@riverpod
class AmortizationFormViewModel extends _$AmortizationFormViewModel {
  @override
  AsyncValue<AmortizationFormState> build(
    String initialKind,
    String? initialDeferralAccountId,
  ) {
    final accounts = ref.watch(accountListProvider);
    final expenseTree = ref.watch(categoryTreeProvider(AccountType.expense));
    final incomeTree = ref.watch(categoryTreeProvider(AccountType.income));
    if (accounts case AsyncError(:final error, :final stackTrace)) {
      return AsyncValue.error(error, stackTrace);
    }
    if (expenseTree case AsyncError(:final error, :final stackTrace)) {
      return AsyncValue.error(error, stackTrace);
    }
    if (incomeTree case AsyncError(:final error, :final stackTrace)) {
      return AsyncValue.error(error, stackTrace);
    }
    if (!accounts.hasValue || !expenseTree.hasValue || !incomeTree.hasValue) {
      return const AsyncValue.loading();
    }
    final kind = AmortizationKind.values.firstWhere(
      (value) => value.name == initialKind,
      orElse: () => AmortizationKind.prepaidExpense,
    );
    return AsyncValue.data(
      AmortizationFormState.initial(
        accounts: accounts.requireValue,
        expenseTree: expenseTree.requireValue,
        incomeTree: incomeTree.requireValue,
        kind: kind,
        deferralAccountId: initialDeferralAccountId,
      ),
    );
  }

  void setKind(AmortizationKind value) {
    _update((current) => current.withKind(value));
  }

  void setFundingAccountId(String? value) {
    _update((current) => current.copyWith(fundingAccountId: value));
  }

  void setDeferralAccountId(String? value) {
    _update((current) => current.copyWith(deferralAccountId: value));
  }

  void setCategoryAccountId(String? value) {
    _update((current) => current.copyWith(categoryAccountId: value));
  }

  void setOccurredAt(DateTime value) {
    _update((current) => current.copyWith(occurredAt: value));
  }

  void setFirstRecognitionAt(DateTime value) {
    _update((current) => current.copyWith(firstRecognitionAt: value));
  }

  void setCadenceUnit(AmortizationCadenceUnit value) {
    _update((current) => current.copyWith(cadenceUnit: value));
  }

  void setDefaultExcludedFromStats(bool value) {
    _update((current) => current.copyWith(excludeStats: value));
  }

  void setDefaultExcludedFromBudget(bool value) {
    _update((current) => current.copyWith(excludeBudget: value));
  }

  Future<UiActionOutcome<String>> submit({
    required String amountText,
    required String intervalText,
    required String countText,
    required String feeText,
    required String noteText,
  }) async {
    final current = state.value;
    if (current == null) {
      return const UiActionOutcome.failure(
        UiError(
          code: 'orchestration.amortization.invalid_command',
          message: '摊销表单尚未加载',
        ),
      );
    }
    final amount = Money.tryParse(amountText);
    final interval = int.tryParse(intervalText);
    final count = int.tryParse(countText);
    final fee =
        current.kind == AmortizationKind.deferredIncome ||
            feeText.trim().isEmpty
        ? Money.zero()
        : Money.tryParse(feeText);
    if (amount == null || amount.minorUnits <= 0) {
      return _invalid('请输入有效金额');
    }
    if (interval == null || interval <= 0) {
      return _invalid('请输入正的摊销间隔');
    }
    if (count == null || count <= 0) {
      return _invalid('请输入正的摊销期数');
    }
    if (fee == null || fee.minorUnits < 0) {
      return _invalid('请输入有效手续费');
    }
    final fundingAccountId = current.fundingAccountId;
    final deferralAccountId = current.deferralAccountId;
    final categoryAccountId = current.categoryAccountId;
    if (fundingAccountId == null ||
        deferralAccountId == null ||
        categoryAccountId == null) {
      return _invalid('请选择资金、递延和分类账户');
    }
    _update((current) => current.copyWith(submitting: true));
    try {
      return await guardUiAction(
        _logger,
        'Amortization plan submit',
        () => ref
            .read(amortizationPlanAppServiceProvider)
            .createPlan(
              CreateAmortizationPlanCommand(
                kind: current.kind,
                total: amount,
                fundingAccountId: fundingAccountId,
                deferralAccountId: deferralAccountId,
                categoryAccountId: categoryAccountId,
                firstRecognitionAt: current.firstRecognitionAt,
                cadenceUnit: current.cadenceUnit,
                cadenceInterval: interval,
                recognitionCount: count,
                occurredAt: current.occurredAt,
                defaultIsExcludedFromStats: current.excludeStats,
                defaultIsExcludedFromBudget: current.excludeBudget,
                feeAmount: fee.minorUnits == 0 ? null : fee,
                note: noteText.trim().isEmpty ? null : noteText.trim(),
              ),
            ),
      );
    } finally {
      _update((current) => current.copyWith(submitting: false));
    }
  }

  void _update(AmortizationFormState Function(AmortizationFormState) update) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(update(current));
  }

  UiActionOutcome<String> _invalid(String message) {
    return UiActionOutcome.failure(
      UiError(
        code: 'orchestration.amortization.invalid_command',
        message: message,
      ),
    );
  }
}

class AmortizationFormState {
  AmortizationFormState({
    required this.kind,
    required this.accounts,
    required this.expenseTree,
    required this.incomeTree,
    required this.occurredAt,
    required this.firstRecognitionAt,
    required this.cadenceUnit,
    required this.excludeStats,
    required this.excludeBudget,
    required this.submitting,
    this.fundingAccountId,
    this.deferralAccountId,
    this.categoryAccountId,
  });

  factory AmortizationFormState.initial({
    required List<Account> accounts,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    required AmortizationKind kind,
    String? deferralAccountId,
  }) {
    final now = DateTime.now();
    final state = AmortizationFormState(
      kind: kind,
      accounts: List.unmodifiable(accounts),
      expenseTree: List.unmodifiable(expenseTree),
      incomeTree: List.unmodifiable(incomeTree),
      occurredAt: now,
      firstRecognitionAt: _oneMonthAfter(now),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      excludeStats: false,
      excludeBudget: false,
      submitting: false,
    );
    return state.copyWith(
      deferralAccountId:
          deferralAccountId ?? state.deferralAccounts.firstOrNull?.id,
      fundingAccountId: state.fundAccounts.firstOrNull?.id,
      categoryAccountId: state.categoryAccounts.firstOrNull?.id,
    );
  }

  final AmortizationKind kind;
  final List<Account> accounts;
  final List<CategoryNode> expenseTree;
  final List<CategoryNode> incomeTree;
  final DateTime occurredAt;
  final DateTime firstRecognitionAt;
  final AmortizationCadenceUnit cadenceUnit;
  final bool excludeStats;
  final bool excludeBudget;
  final bool submitting;
  final String? fundingAccountId;
  final String? deferralAccountId;
  final String? categoryAccountId;

  List<Account> get fundAccounts => [
    for (final account in accounts)
      if (account.type == AccountType.asset &&
          account.subtype == AccountSubtype.fund &&
          account.archivedAt == null)
        account,
  ];

  List<Account> get deferralAccounts => [
    for (final account in accounts)
      if (account.subtype == expectedDeferralSubtype &&
          account.archivedAt == null)
        account,
  ];

  List<CategoryNode> get categoryTree =>
      kind == AmortizationKind.prepaidExpense ? expenseTree : incomeTree;

  List<Account> get categoryAccounts => [
    for (final node in categoryTree) ...[node.account, ...node.children],
  ];

  AccountSubtype get expectedDeferralSubtype => switch (kind) {
    AmortizationKind.prepaidExpense => AccountSubtype.prepaidExpense,
    AmortizationKind.deferredIncome => AccountSubtype.deferredIncome,
  };

  AmortizationFormState withKind(AmortizationKind value) {
    final next = copyWith(kind: value);
    final deferral = next.deferralAccounts
        .where((account) => account.id == deferralAccountId)
        .firstOrNull;
    final category = next.categoryAccounts
        .where((account) => account.id == categoryAccountId)
        .firstOrNull;
    return next.copyWith(
      deferralAccountId: deferral?.id ?? next.deferralAccounts.firstOrNull?.id,
      categoryAccountId: category?.id ?? next.categoryAccounts.firstOrNull?.id,
    );
  }

  AmortizationFormState copyWith({
    AmortizationKind? kind,
    DateTime? occurredAt,
    DateTime? firstRecognitionAt,
    AmortizationCadenceUnit? cadenceUnit,
    bool? excludeStats,
    bool? excludeBudget,
    bool? submitting,
    Object? fundingAccountId = _sentinel,
    Object? deferralAccountId = _sentinel,
    Object? categoryAccountId = _sentinel,
  }) {
    return AmortizationFormState(
      kind: kind ?? this.kind,
      accounts: accounts,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      occurredAt: occurredAt ?? this.occurredAt,
      firstRecognitionAt: firstRecognitionAt ?? this.firstRecognitionAt,
      cadenceUnit: cadenceUnit ?? this.cadenceUnit,
      excludeStats: excludeStats ?? this.excludeStats,
      excludeBudget: excludeBudget ?? this.excludeBudget,
      submitting: submitting ?? this.submitting,
      fundingAccountId: fundingAccountId == _sentinel
          ? this.fundingAccountId
          : fundingAccountId as String?,
      deferralAccountId: deferralAccountId == _sentinel
          ? this.deferralAccountId
          : deferralAccountId as String?,
      categoryAccountId: categoryAccountId == _sentinel
          ? this.categoryAccountId
          : categoryAccountId as String?,
    );
  }
}

DateTime _oneMonthAfter(DateTime value) {
  final month = DateTime(value.year, value.month + 1);
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(
    month.year,
    month.month,
    value.day > lastDay ? lastDay : value.day,
  );
}

const Object _sentinel = Object();
