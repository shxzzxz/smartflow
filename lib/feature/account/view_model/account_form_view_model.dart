import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'account_view.dart';
import 'account_views_provider.dart';

part 'account_form_view_model.g.dart';

final _logger = Logger('feature.account.form');

@riverpod
class AccountFormViewModel extends _$AccountFormViewModel {
  AccountFormState? _initializedState;

  @override
  AsyncValue<AccountFormState?> build(String? accountId) {
    if (accountId == null) {
      return AsyncValue.data(_initializedState ??= AccountFormState.initial());
    }

    return ref.watch(accountViewProvider(accountId)).whenData((account) {
      if (account == null) return null;
      return _initializedState ??= AccountFormState.fromAccount(account);
    });
  }

  void setKind(AccountProfileKind value) {
    _update((current) {
      if (current.kind == value) return current;
      return current.copyWith(
        kind: value,
        iconKey: value.iconKey,
        billingDay:
            value == AccountProfileKind.credit ? current.billingDay : null,
        repaymentDay:
            value == AccountProfileKind.credit ? current.repaymentDay : null,
        billingDayToNext: true,
      );
    });
  }

  void setIconKey(String value) {
    _update(
      (current) =>
          current.iconKey == value ? current : current.copyWith(iconKey: value),
    );
  }

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
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalidCommand('账户表单尚未加载');

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
      final targetAccountId = accountId;
      if (targetAccountId == null) {
        await _createAccount(
          formState: current,
          name: name,
          openingBalance: openingBalance,
          creditLimit: creditLimit,
          note: note,
        );
      } else {
        await _editAccount(
          formState: current,
          id: targetAccountId,
          name: name,
          openingBalance: openingBalance,
          creditLimit: creditLimit,
          note: note,
        );
      }
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception catch (exception, stackTrace) {
      _logger.severe(
        'Account form submit failed unexpectedly.',
        exception,
        stackTrace,
      );
      return const SubmitOutcome.failure(UiError.unknown());
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
    if (!isLiabilityAccountKind(formState.kind)) return null;
    final text = creditLimitText.trim();
    if (text.isEmpty) return null;
    final money = Money.tryParse(text);
    if (money == null || money.minorUnits < 0) return _invalidMoney;
    return money;
  }

  Future<void> _createAccount({
    required AccountFormState formState,
    required String name,
    required Money openingBalance,
    required Money? creditLimit,
    required String? note,
  }) {
    if (!isLiabilityAccountKind(formState.kind)) {
      return ref
          .read(accountAppServiceProvider)
          .createAccount(
            CreateAccountCommand(
              name: name,
              type: formState.kind.accountType,
              subtype: formState.kind.accountSubtype,
              profileKey: formState.kind.key,
              iconKey: formState.iconKey,
              openingBalance: openingBalance,
              note: note,
            ),
          )
          .then((_) {});
    }
    return ref
        .read(creditAccountAppServiceProvider)
        .createAccount(
          CreateCreditLiabilityAccountCommand(
            name: name,
            kind: creditLiabilityKindForProfile(formState.kind),
            iconKey: formState.iconKey,
            openingBalance: openingBalance,
            note: note,
            creditLimit: creditLimit,
            billingDay:
                formState.kind == AccountProfileKind.credit
                    ? formState.billingDay
                    : null,
            repaymentDay:
                formState.kind == AccountProfileKind.credit
                    ? formState.repaymentDay
                    : null,
            billingDayToNext: formState.billingDayToNext,
          ),
        )
        .then((_) {});
  }

  Future<void> _editAccount({
    required AccountFormState formState,
    required String id,
    required String name,
    required Money openingBalance,
    required Money? creditLimit,
    required String? note,
  }) {
    if (!isLiabilityAccountKind(formState.kind)) {
      return ref
          .read(accountAppServiceProvider)
          .editAccount(
            EditAccountCommand(
              id: id,
              name: name,
              subtype:
                  formState.kind.accountSubtype == null
                      ? const Patch<AccountSubtype>.clear()
                      : Patch.set(formState.kind.accountSubtype!),
              profileKey: Patch.set(formState.kind.key),
              iconKey: Patch.set(formState.iconKey),
              note:
                  note == null ? const Patch<String>.clear() : Patch.set(note),
              targetBalance:
                  showsManualBalanceField(formState.kind)
                      ? openingBalance
                      : null,
            ),
          );
    }
    return ref
        .read(creditAccountAppServiceProvider)
        .editAccount(
          EditCreditLiabilityAccountCommand(
            accountId: id,
            name: name,
            iconKey: Patch.set(formState.iconKey),
            note: note == null ? const Patch<String>.clear() : Patch.set(note),
            creditLimit:
                creditLimit == null
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
            targetBalance: openingBalance,
          ),
        );
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
    this.billingDay,
    this.repaymentDay,
    this.billingDayToNext = true,
  });

  factory AccountFormState.initial() {
    return AccountFormState(
      initialValues: const AccountFormInitialValues(),
      kind: AccountProfileKind.fund,
      iconKey: AccountProfileKind.fund.iconKey,
      submitting: false,
    );
  }

  factory AccountFormState.fromAccount(AccountView account) {
    return AccountFormState(
      initialValues: AccountFormInitialValues.fromAccount(account),
      kind: account.kind,
      iconKey: account.iconKey ?? account.kind.iconKey,
      billingDay: account.billingDay,
      repaymentDay: account.repaymentDay,
      billingDayToNext: account.billingDayToNext ?? true,
      submitting: false,
    );
  }

  final AccountFormInitialValues initialValues;
  final AccountProfileKind kind;
  final String iconKey;
  final int? billingDay;
  final int? repaymentDay;
  final bool billingDayToNext;
  final bool submitting;

  AccountFormState copyWith({
    AccountFormInitialValues? initialValues,
    AccountProfileKind? kind,
    String? iconKey,
    Object? billingDay = _sentinel,
    Object? repaymentDay = _sentinel,
    bool? billingDayToNext,
    bool? submitting,
  }) {
    return AccountFormState(
      initialValues: initialValues ?? this.initialValues,
      kind: kind ?? this.kind,
      iconKey: iconKey ?? this.iconKey,
      billingDay:
          billingDay == _sentinel ? this.billingDay : billingDay as int?,
      repaymentDay:
          repaymentDay == _sentinel ? this.repaymentDay : repaymentDay as int?,
      billingDayToNext: billingDayToNext ?? this.billingDayToNext,
      submitting: submitting ?? this.submitting,
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
  return kind == AccountProfileKind.fund || isLiabilityAccountKind(kind);
}

String manualBalanceLabel({
  required AccountProfileKind kind,
  required bool isEdit,
}) {
  if (isLiabilityAccountKind(kind)) return isEdit ? '当前欠款' : '初始欠款';
  return isEdit ? '当前余额' : '初始余额';
}

String manualBalanceHint({
  required AccountProfileKind kind,
  required bool isEdit,
}) {
  if (isLiabilityAccountKind(kind)) return isEdit ? '请输入当前欠款' : '请输入初始欠款';
  return isEdit ? '请输入当前余额' : '请输入初始余额';
}

const Object _sentinel = Object();
const Money _invalidMoney = Money(minorUnits: -1);
