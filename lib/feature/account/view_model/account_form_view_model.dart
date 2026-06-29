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

part 'account_form_view_model.g.dart';

@riverpod
class AccountFormViewModel extends _$AccountFormViewModel {
  @override
  AccountFormState build() {
    return AccountFormState.initial();
  }

  void initializeForEdit(AccountView account) {
    if (state.initializedAccountId == account.id) return;
    state = state.copyWith(
      kind: account.kind,
      iconKey: account.iconKey ?? account.kind.iconKey,
      billingDay: account.billingDay,
      repaymentDay: account.repaymentDay,
      billingStartPeriod: account.billingStartPeriod,
      billingDayToNext: account.billingDayToNext ?? true,
      initializedAccountId: account.id,
    );
  }

  void setKind(AccountProfileKind value) {
    if (state.kind == value) return;
    state = state.copyWith(
      kind: value,
      iconKey: value.iconKey,
      billingDay: value == AccountProfileKind.credit ? state.billingDay : null,
      repaymentDay:
          value == AccountProfileKind.credit ? state.repaymentDay : null,
      billingStartPeriod:
          value == AccountProfileKind.credit
              ? state.billingStartPeriod ?? BillPeriod.fromDate(DateTime.now())
              : null,
      billingDayToNext: true,
    );
  }

  void setIconKey(String value) {
    if (state.iconKey == value) return;
    state = state.copyWith(iconKey: value);
  }

  void setBillingDay(int? value) {
    state = state.copyWith(billingDay: value);
  }

  void setRepaymentDay(int? value) {
    state = state.copyWith(repaymentDay: value);
  }

  void setBillingStartPeriod(BillPeriod value) {
    state = state.copyWith(billingStartPeriod: value);
  }

  void setBillingDayToNext(bool value) {
    state = state.copyWith(billingDayToNext: value);
  }

  Future<SubmitOutcome> submit({
    required String nameText,
    required String openingBalanceText,
    required String creditLimitText,
    required String noteText,
    String? editAccountId,
  }) async {
    final name = trimToNull(nameText);
    if (name == null) return _invalidCommand('请输入账户名称');
    final openingBalance = _openingBalanceForText(openingBalanceText);
    if (openingBalance == null) return _invalidCommand('请输入有效金额');
    final creditLimit = _creditLimitForText(creditLimitText);
    if (creditLimit == _invalidMoney) return _invalidCommand('请输入有效金额');
    final note = trimToNull(noteText);
    final cycleError = _validateCreditCycle();
    if (cycleError != null) return _invalidCommand(cycleError);

    state = state.copyWith(submitting: true);
    try {
      if (editAccountId == null) {
        await _createAccount(
          name: name,
          openingBalance: openingBalance,
          creditLimit: creditLimit,
          note: note,
        );
      } else {
        if (state.initializedAccountId != editAccountId) {
          return _invalidCommand('账户尚未加载。');
        }
        await _editAccount(
          id: editAccountId,
          name: name,
          openingBalance: openingBalance,
          creditLimit: creditLimit,
          note: note,
        );
      }
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      state = state.copyWith(submitting: false);
    }
  }

  Money? _openingBalanceForText(String openingBalanceText) {
    if (!showsManualBalanceField(state.kind)) return Money.zero();
    final money = Money.tryParse(openingBalanceText);
    if (money == null || money.minorUnits < 0) return null;
    return money;
  }

  Money? _creditLimitForText(String creditLimitText) {
    if (!isLiabilityAccountKind(state.kind)) return null;
    final text = creditLimitText.trim();
    if (text.isEmpty) return null;
    final money = Money.tryParse(text);
    if (money == null || money.minorUnits < 0) return _invalidMoney;
    return money;
  }

  Future<void> _createAccount({
    required String name,
    required Money openingBalance,
    required Money? creditLimit,
    required String? note,
  }) {
    if (!isLiabilityAccountKind(state.kind)) {
      return ref
          .read(accountAppServiceProvider)
          .createAccount(
            CreateAccountCommand(
              name: name,
              type: state.kind.accountType,
              subtype: state.kind.accountSubtype,
              profileKey: state.kind.key,
              iconKey: state.iconKey,
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
            kind: creditLiabilityKindForProfile(state.kind),
            iconKey: state.iconKey,
            openingBalance: openingBalance,
            note: note,
            creditLimit: creditLimit,
            billingDay:
                state.kind == AccountProfileKind.credit
                    ? state.billingDay
                    : null,
            repaymentDay:
                state.kind == AccountProfileKind.credit
                    ? state.repaymentDay
                    : null,
            billingStartPeriod:
                state.kind == AccountProfileKind.credit
                    ? state.billingStartPeriod
                    : null,
            billingDayToNext: state.billingDayToNext,
          ),
        )
        .then((_) {});
  }

  Future<void> _editAccount({
    required String id,
    required String name,
    required Money openingBalance,
    required Money? creditLimit,
    required String? note,
  }) {
    if (!isLiabilityAccountKind(state.kind)) {
      return ref
          .read(accountAppServiceProvider)
          .editAccount(
            EditAccountCommand(
              id: id,
              name: name,
              subtype:
                  state.kind.accountSubtype == null
                      ? const Patch<AccountSubtype>.clear()
                      : Patch.set(state.kind.accountSubtype!),
              profileKey: Patch.set(state.kind.key),
              iconKey: Patch.set(state.iconKey),
              note:
                  note == null ? const Patch<String>.clear() : Patch.set(note),
              targetBalance:
                  showsManualBalanceField(state.kind) ? openingBalance : null,
            ),
          );
    }
    return ref
        .read(creditAccountAppServiceProvider)
        .editAccount(
          EditCreditLiabilityAccountCommand(
            accountId: id,
            name: name,
            iconKey: Patch.set(state.iconKey),
            note: note == null ? const Patch<String>.clear() : Patch.set(note),
            creditLimit:
                creditLimit == null
                    ? const Patch<Money>.clear()
                    : Patch.set(creditLimit),
            billingDay:
                state.kind == AccountProfileKind.credit &&
                        state.billingDay != null
                    ? Patch.set(state.billingDay!)
                    : const Patch<int>.clear(),
            repaymentDay:
                state.kind == AccountProfileKind.credit &&
                        state.repaymentDay != null
                    ? Patch.set(state.repaymentDay!)
                    : const Patch<int>.clear(),
            billingStartPeriod:
                state.kind == AccountProfileKind.credit &&
                        state.billingStartPeriod != null
                    ? Patch.set(state.billingStartPeriod!)
                    : const Patch<BillPeriod>.clear(),
            billingDayToNext: state.billingDayToNext,
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

  String? _validateCreditCycle() {
    if (state.kind != AccountProfileKind.credit) return null;
    final billingDay = state.billingDay;
    final repaymentDay = state.repaymentDay;
    if (billingDay == null || repaymentDay == null) {
      return '请选择出账日和还款日';
    }
    if (billingDay < 1 ||
        billingDay > 28 ||
        repaymentDay < 1 ||
        repaymentDay > 28) {
      return '出账日和还款日只能选择 1-28 日';
    }
    if (state.billingStartPeriod == null) {
      return '请选择账单起始期';
    }
    return null;
  }
}

class AccountFormState {
  const AccountFormState({
    required this.kind,
    required this.iconKey,
    required this.submitting,
    this.billingDay,
    this.repaymentDay,
    this.billingStartPeriod,
    this.billingDayToNext = true,
    this.initializedAccountId,
  });

  factory AccountFormState.initial() {
    return AccountFormState(
      kind: AccountProfileKind.fund,
      iconKey: AccountProfileKind.fund.iconKey,
      submitting: false,
    );
  }

  final AccountProfileKind kind;
  final String iconKey;
  final int? billingDay;
  final int? repaymentDay;
  final BillPeriod? billingStartPeriod;
  final bool billingDayToNext;
  final bool submitting;
  final String? initializedAccountId;

  AccountFormState copyWith({
    AccountProfileKind? kind,
    String? iconKey,
    Object? billingDay = _sentinel,
    Object? repaymentDay = _sentinel,
    Object? billingStartPeriod = _sentinel,
    bool? billingDayToNext,
    bool? submitting,
    Object? initializedAccountId = _sentinel,
  }) {
    return AccountFormState(
      kind: kind ?? this.kind,
      iconKey: iconKey ?? this.iconKey,
      billingDay:
          billingDay == _sentinel ? this.billingDay : billingDay as int?,
      repaymentDay:
          repaymentDay == _sentinel ? this.repaymentDay : repaymentDay as int?,
      billingStartPeriod:
          billingStartPeriod == _sentinel
              ? this.billingStartPeriod
              : billingStartPeriod as BillPeriod?,
      billingDayToNext: billingDayToNext ?? this.billingDayToNext,
      submitting: submitting ?? this.submitting,
      initializedAccountId:
          initializedAccountId == _sentinel
              ? this.initializedAccountId
              : initializedAccountId as String?,
    );
  }
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
