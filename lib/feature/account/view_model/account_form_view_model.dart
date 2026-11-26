import '../../shared/provider/book_providers.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/analytics/analytics_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart' show AccountType;
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../domain/analytics/valobj/analytics_error_code.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import 'asset_views_provider.dart';
import '../../../widget/business/icon/business_icon_registry.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'account_view.dart';
import 'account_views_provider.dart';

part 'account_form_view_model.g.dart';

final _logger = Logger('feature.account.form');

@riverpod
class AccountFormViewModel extends _$AccountFormViewModel {
  AccountFormState? _initializedState;
  AccountProfileKind _creationKind = AccountProfileKind.fund;
  String? _creationIconKey;

  @override
  AsyncValue<AccountFormState?> build(String? accountId, {String? viewId}) {
    final views = ref.watch(assetViewsProvider);
    final selected = _initializedState == null && viewId == null
        ? ref.watch(selectedAssetViewProvider)
        : null;
    for (final value in <AsyncValue<Object?>>[views, ?selected]) {
      if (value.hasError) return AsyncError(value.error!, value.stackTrace!);
      if (!value.hasValue) return const AsyncLoading();
    }
    final resolvedId =
        _initializedState?.viewId ?? viewId ?? selected!.requireValue.id;
    final view = views.requireValue
        .where((view) => view.id == resolvedId)
        .firstOrNull;
    if (view == null) {
      return AsyncError(
        BusinessException(AnalyticsErrorCode.viewNotFound),
        StackTrace.current,
      );
    }
    if (accountId == null) {
      return AsyncData(
        _initializedState ??= AccountFormState.initial(
          view: view,
          kind: _creationKind,
          iconKey: _creationIconKey,
        ),
      );
    }
    return ref.watch(accountViewProvider(accountId)).whenData((account) {
      if (account == null) return null;
      return _initializedState ??= AccountFormState.fromAccount(
        account,
        view: view,
      );
    });
  }

  String? _groupForProfile(AccountProfileKind profile) {
    final viewId = state.value?.viewId;
    final view = ref
        .read(assetViewsProvider)
        .value
        ?.where((view) => view.id == viewId)
        .firstOrNull;
    return view == null ? null : initialAssetViewGroupId(view, profile);
  }

  void setKind(AccountProfileKind value) {
    _update((current) {
      if (current.kind == value) return current;
      return current.copyWith(
        kind: value,
        groupId: _groupForProfile(value),
        iconKey: value.iconKey,
        billingDay: value == AccountProfileKind.credit
            ? current.billingDay
            : null,
        repaymentDay: value == AccountProfileKind.credit
            ? current.repaymentDay
            : null,
        billingDayToNext: true,
      );
    });
  }

  void initializeNewAccount({
    required AccountProfileKind kind,
    required String iconKey,
  }) {
    if (accountId != null) return;
    _creationKind = kind;
    _creationIconKey = iconKey;
    if (!state.hasValue) {
      ref.invalidateSelf();
      return;
    }
    _update(
      (current) => current.copyWith(
        kind: kind,
        groupId: _groupForProfile(kind),
        iconKey: iconKey,
        billingDay: null,
        repaymentDay: null,
        billingDayToNext: true,
      ),
    );
  }

  void setIconKey(String value) {
    _update(
      (current) =>
          current.iconKey == value ? current : current.copyWith(iconKey: value),
    );
  }

  void setGroupId(String? value) =>
      _update((current) => current.copyWith(groupId: value));

  void setBillingDay(int? value) =>
      _update((current) => current.copyWith(billingDay: value));

  void setRepaymentDay(int? value) =>
      _update((current) => current.copyWith(repaymentDay: value));

  void setBillingDayToNext(bool value) =>
      _update((current) => current.copyWith(billingDayToNext: value));

  Future<SubmitOutcome> submit({
    required String nameText,
    required String openingBalanceText,
    required String creditLimitText,
    required String noteText,
    String? iconRef,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalidCommand('账户表单尚未加载');
    if (current.submitting) return _invalidCommand('账户正在保存');

    final name = trimToNull(nameText);
    if (name == null) return _invalidCommand('请输入账户名称');
    final openingBalance = _openingBalanceForText(openingBalanceText, current);
    if (openingBalance == null) return _invalidCommand('请输入有效金额');
    final creditLimit = _creditLimitForText(creditLimitText, current);
    if (creditLimit == _invalidMoney) return _invalidCommand('请输入有效金额');
    final note = trimToNull(noteText);
    final cycleError = _validateCreditCycle(current);
    if (cycleError != null) return _invalidCommand(cycleError);

    _update((current) => current.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Account form submit', () async {
        final targetAccountId = accountId;
        if (targetAccountId == null) {
          await _createAccount(
            formState: current,
            iconRef: iconRef ?? _canonicalIconRef(current.iconKey),
            name: name,
            openingBalance: openingBalance,
            creditLimit: creditLimit,
            note: note,
          );
        } else {
          await _editAccount(
            formState: current,
            iconRef: iconRef ?? _canonicalIconRef(current.iconKey),
            id: targetAccountId,
            name: name,
            openingBalance: openingBalance,
            creditLimit: creditLimit,
            note: note,
          );
        }
      });
    } finally {
      _update((current) => current.copyWith(submitting: false));
    }
  }

  void _update(AccountFormState Function(AccountFormState) update) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = update(current);
    _initializedState = next;
    state = AsyncValue.data(next);
  }

  Money? _openingBalanceForText(
    String openingBalanceText,
    AccountFormState formState,
  ) {
    if (!showsManualBalanceField(formState.kind)) return Money.zero();
    final money = Money.tryParse(openingBalanceText);
    if (money == null || money.minorUnits < 0) return null;
    return money;
  }

  Money? _creditLimitForText(
    String creditLimitText,
    AccountFormState formState,
  ) {
    if (!isCreditManagedAccountKind(formState.kind)) return null;
    final text = creditLimitText.trim();
    if (text.isEmpty) return null;
    final money = Money.tryParse(text);
    if (money == null || money.minorUnits < 0) return _invalidMoney;
    return money;
  }

  Future<void> _createAccount({
    required AccountFormState formState,
    required String iconRef,
    required String name,
    required Money openingBalance,
    required Money? creditLimit,
    required String? note,
  }) async {
    await ref
        .read(assetViewAccountAppServiceProvider)
        .createAccount(
          CreateAssetViewAccountCommand(
            viewId: formState.viewId,
            groupId: formState.groupId,
            account: AssetViewAccountDraft(
              transactionBookId:
                  (await ref
                          .read(bookSelectionViewModelProvider.notifier)
                          .snapshot())
                      .currentBook
                      .id,
              profile: formState.kind,
              name: name,
              openingBalance: openingBalance,
              iconKey: iconRef,
              note: note,
              creditLimit: creditLimit,
              billingDay: formState.kind == AccountProfileKind.credit
                  ? formState.billingDay
                  : null,
              repaymentDay: formState.kind == AccountProfileKind.credit
                  ? formState.repaymentDay
                  : null,
              billingDayToNext: formState.billingDayToNext,
            ),
          ),
        );
  }

  Future<void> _editAccount({
    required AccountFormState formState,
    required String iconRef,
    required String id,
    required String name,
    required Money openingBalance,
    required Money? creditLimit,
    required String? note,
  }) async {
    await ref
        .read(assetViewAccountAppServiceProvider)
        .editAccount(
          EditAssetViewAccountCommand(
            viewId: formState.viewId,
            groupId: !formState.isInView
                ? null
                : formState.groupId == null
                ? const Patch<String>.clear()
                : Patch.set(formState.groupId!),
            account: AssetViewAccountEdit(
              transactionBookId:
                  (await ref
                          .read(bookSelectionViewModelProvider.notifier)
                          .snapshot())
                      .currentBook
                      .id,
              accountId: id,
              profile: formState.kind,
              name: name,
              iconKey: Patch.set(iconRef),
              note: note == null
                  ? const Patch<String>.clear()
                  : Patch.set(note),
              targetBalance: showsManualBalanceField(formState.kind)
                  ? openingBalance
                  : null,
              creditLimit: creditLimit == null
                  ? const Patch<Money>.clear()
                  : Patch.set(creditLimit),
              billingDay:
                  formState.kind == AccountProfileKind.credit &&
                      formState.billingDay != null
                  ? Patch.set(formState.billingDay!)
                  : const Patch<int>.clear(),
              repaymentDay:
                  formState.kind == AccountProfileKind.credit &&
                      formState.repaymentDay != null
                  ? Patch.set(formState.repaymentDay!)
                  : const Patch<int>.clear(),
              billingDayToNext: formState.billingDayToNext,
            ),
          ),
        );
    if (ref.mounted && isCreditManagedAccountKind(formState.kind)) {
      ref
        ..invalidate(billQueryServiceProvider)
        ..invalidate(creditAccountQueryServiceProvider);
    }
  }

  String _canonicalIconRef(String value) {
    final parsed = BusinessIconRef.tryParse(value);
    if (parsed != null) return parsed.id;
    return BusinessIconRef(
      origin: BusinessIconOrigin.builtin,
      type: BusinessIconType.account,
      groupId: defaultBusinessIconGroupId,
      key: value,
    ).id;
  }

  SubmitOutcome _invalidCommand(String message) {
    return SubmitOutcome.failure(
      UiError(
        code: LedgerErrorCode.accountInvalidCommand.code,
        message: message,
      ),
    );
  }

  String? _validateCreditCycle(AccountFormState formState) {
    if (formState.kind != AccountProfileKind.credit) return null;
    final billingDay = formState.billingDay;
    final repaymentDay = formState.repaymentDay;
    if (billingDay == null || repaymentDay == null) {
      return '请选择出账日和还款日';
    }
    if (billingDay < 1 ||
        billingDay > 28 ||
        repaymentDay < 1 ||
        repaymentDay > 28) {
      return '出账日和还款日只能选择 1-28 日';
    }
    return null;
  }
}

class AccountFormState {
  const AccountFormState({
    required this.initialValues,
    required this.kind,
    required this.iconKey,
    required this.submitting,
    required this.viewId,
    this.isInView = true,
    this.groupId,
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext = true,
  });

  factory AccountFormState.initial({
    required AssetView view,
    AccountProfileKind kind = AccountProfileKind.fund,
    String? iconKey,
  }) => AccountFormState(
    initialValues: const AccountFormInitialValues(),
    kind: kind,
    viewId: view.id,
    groupId: initialAssetViewGroupId(view, kind),
    iconKey: iconKey ?? 'bank-account',
    submitting: false,
  );

  factory AccountFormState.fromAccount(
    AccountView account, {
    required AssetView view,
  }) => AccountFormState(
    initialValues: AccountFormInitialValues.fromAccount(account),
    kind: account.kind,
    viewId: view.id,
    isInView: view.includesAccount(account.id),
    groupId: view.groupIdFor(account.id),
    iconKey: account.iconKey ?? 'bank-account',
    billingDay: account.billingDay,
    repaymentDay: account.repaymentDay,
    billingDayToNext: account.billingDayToNext ?? true,
    submitting: false,
  );

  final AccountFormInitialValues initialValues;
  final String viewId;
  final bool isInView;
  final AccountProfileKind kind;
  final String iconKey;
  final int? billingDay;
  final int? repaymentDay;
  final bool billingDayToNext;
  final bool submitting;
  final String? groupId;

  AccountFormState copyWith({
    AccountFormInitialValues? initialValues,
    AccountProfileKind? kind,
    String? iconKey,
    Object? billingDay = _sentinel,
    Object? repaymentDay = _sentinel,
    bool? billingDayToNext,
    bool? submitting,
    Object? groupId = _sentinel,
  }) {
    return AccountFormState(
      initialValues: initialValues ?? this.initialValues,
      viewId: viewId,
      isInView: isInView,
      kind: kind ?? this.kind,
      iconKey: iconKey ?? this.iconKey,
      billingDay: billingDay == _sentinel
          ? this.billingDay
          : billingDay as int?,
      repaymentDay: repaymentDay == _sentinel
          ? this.repaymentDay
          : repaymentDay as int?,
      billingDayToNext: billingDayToNext ?? this.billingDayToNext,
      submitting: submitting ?? this.submitting,
      groupId: groupId == _sentinel ? this.groupId : groupId as String?,
    );
  }
}

/// Text values captured once from the loaded account snapshot for controller
/// construction. These are not the live text state of the form.
class AccountFormInitialValues {
  const AccountFormInitialValues({
    this.name = '',
    this.openingBalance = '0',
    this.creditLimit = '',
    this.note = '',
  });

  factory AccountFormInitialValues.fromAccount(AccountView account) {
    return AccountFormInitialValues(
      name: account.name,
      openingBalance: account.balance.format(),
      creditLimit: account.creditLimit?.format() ?? '',
      note: account.note ?? '',
    );
  }

  final String name;
  final String openingBalance;
  final String creditLimit;
  final String note;
}

bool isLiabilityAccountKind(AccountProfileKind kind) {
  return kind.accountType == AccountType.liability;
}

bool isCreditManagedAccountKind(AccountProfileKind kind) {
  return kind == AccountProfileKind.credit || kind == AccountProfileKind.loan;
}

CreditLiabilityAccountKind creditLiabilityKindForProfile(
  AccountProfileKind kind,
) {
  return switch (kind) {
    AccountProfileKind.credit => CreditLiabilityAccountKind.credit,
    AccountProfileKind.loan => CreditLiabilityAccountKind.loan,
    _ => throw ArgumentError.value(kind, 'kind', 'Not a credit account kind.'),
  };
}

bool showsManualBalanceField(AccountProfileKind kind) {
  return kind != AccountProfileKind.reimbursement;
}

String manualBalanceLabel({
  required AccountProfileKind kind,
  required bool isEdit,
}) {
  if (isCreditManagedAccountKind(kind)) {
    return '当前欠款';
  }
  if (kind == AccountProfileKind.receivable) {
    return isEdit ? '当前应收' : '应收金额';
  }
  if (kind == AccountProfileKind.prepaidExpense) {
    return '预付金额';
  }
  if (kind == AccountProfileKind.deferredIncome) {
    return '预收金额';
  }
  if (isLiabilityAccountKind(kind)) {
    return isEdit ? '当前应付' : '应付金额';
  }
  return isEdit ? '当前余额' : '初始余额';
}

String manualBalanceHint({
  required AccountProfileKind kind,
  required bool isEdit,
}) {
  if (isCreditManagedAccountKind(kind)) {
    return '请输入当前欠款';
  }
  if (kind == AccountProfileKind.receivable) {
    return isEdit ? '请输入当前应收' : '请输入应收金额';
  }
  if (kind == AccountProfileKind.prepaidExpense) {
    return '请输入预付金额';
  }
  if (kind == AccountProfileKind.deferredIncome) {
    return '请输入预收金额';
  }
  if (isLiabilityAccountKind(kind)) {
    return isEdit ? '请输入当前应付' : '请输入应付金额';
  }
  return isEdit ? '请输入当前余额' : '请输入初始余额';
}

const Object _sentinel = Object();
const Money _invalidMoney = Money(minorUnits: -1);
