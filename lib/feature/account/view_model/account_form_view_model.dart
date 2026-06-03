import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'account_form_view_model.g.dart';

enum AccountFormKind { fund, credit, loan, reimbursement }

@riverpod
class AccountFormViewModel extends _$AccountFormViewModel {
  @override
  AccountFormState build() {
    return AccountFormState.initial();
  }

  void initializeForEdit(Account account) {
    if (state.initializedAccountId == account.id) return;
    final kind = accountFormKindForAccount(account);
    state = state.copyWith(
      kind: kind,
      iconKey: account.iconKey ?? defaultAccountIconKey(kind),
      billingDay: account.billingDay,
      repaymentDay: account.repaymentDay,
      initializedAccountId: account.id,
    );
  }

  void setKind(AccountFormKind value) {
    if (state.kind == value) return;
    state = state.copyWith(
      kind: value,
      iconKey: defaultAccountIconKey(value),
      billingDay: value == AccountFormKind.credit ? state.billingDay : null,
      repaymentDay: isLiabilityAccountKind(value) ? state.repaymentDay : null,
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

    state = state.copyWith(submitting: true);
    try {
      final service = ref.read(accountAppServiceProvider);
      if (editAccountId == null) {
        await service.createAccount(
          CreateAccountCommand(
            name: name,
            type: accountTypeForKind(state.kind),
            subtype: accountSubtypeForKind(state.kind),
            iconKey: state.iconKey,
            openingBalance: openingBalance,
            note: note,
            creditLimit: creditLimit,
            billingDay:
                state.kind == AccountFormKind.credit ? state.billingDay : null,
            repaymentDay:
                isLiabilityAccountKind(state.kind) ? state.repaymentDay : null,
          ),
        );
      } else {
        if (state.initializedAccountId != editAccountId) {
          return _invalidCommand('账户尚未加载。');
        }
        await service.editAccount(
          EditAccountCommand(
            id: editAccountId,
            name: name,
            iconKey: Patch.set(state.iconKey),
            note: note == null ? const Patch<String>.clear() : Patch.set(note),
            creditLimit:
                creditLimit == null
                    ? const Patch<Money>.clear()
                    : Patch.set(creditLimit),
            billingDay:
                state.kind == AccountFormKind.credit && state.billingDay != null
                    ? Patch.set(state.billingDay!)
                    : const Patch<int>.clear(),
            repaymentDay:
                isLiabilityAccountKind(state.kind) && state.repaymentDay != null
                    ? Patch.set(state.repaymentDay!)
                    : const Patch<int>.clear(),
            targetBalance:
                showsManualBalanceField(state.kind) ? openingBalance : null,
          ),
        );
      }
      return const SubmitOutcome.success();
    } on BusinessException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on CallException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
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

  SubmitOutcome _invalidCommand(String message) {
    return SubmitOutcome.failure(
      UiError(
        code: LedgerErrorCode.accountInvalidCommand.code,
        message: message,
      ),
    );
  }
}

class AccountFormState {
  const AccountFormState({
    required this.kind,
    required this.iconKey,
    required this.submitting,
    this.billingDay,
    this.repaymentDay,
    this.initializedAccountId,
  });

  factory AccountFormState.initial() {
    return AccountFormState(
      kind: AccountFormKind.fund,
      iconKey: defaultAccountIconKey(AccountFormKind.fund),
      submitting: false,
    );
  }

  final AccountFormKind kind;
  final String iconKey;
  final int? billingDay;
  final int? repaymentDay;
  final bool submitting;
  final String? initializedAccountId;

  AccountFormState copyWith({
    AccountFormKind? kind,
    String? iconKey,
    Object? billingDay = _sentinel,
    Object? repaymentDay = _sentinel,
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
      submitting: submitting ?? this.submitting,
      initializedAccountId:
          initializedAccountId == _sentinel
              ? this.initializedAccountId
              : initializedAccountId as String?,
    );
  }
}

AccountType accountTypeForKind(AccountFormKind kind) {
  return switch (kind) {
    AccountFormKind.fund || AccountFormKind.reimbursement => AccountType.asset,
    AccountFormKind.credit || AccountFormKind.loan => AccountType.liability,
  };
}

AccountSubtype? accountSubtypeForKind(AccountFormKind kind) {
  return switch (kind) {
    AccountFormKind.reimbursement => AccountSubtype.reimbursement,
    AccountFormKind.credit => AccountSubtype.consumerCredit,
    AccountFormKind.loan => AccountSubtype.loan,
    _ => null,
  };
}

String defaultAccountIconKey(AccountFormKind kind) {
  return switch (kind) {
    AccountFormKind.fund => 'alipay',
    AccountFormKind.reimbursement => 'reimburse',
    AccountFormKind.credit => 'cmb_credit_card',
    AccountFormKind.loan => 'loan',
  };
}

bool isLiabilityAccountKind(AccountFormKind kind) {
  return kind == AccountFormKind.credit || kind == AccountFormKind.loan;
}

bool showsManualBalanceField(AccountFormKind kind) {
  return kind == AccountFormKind.fund || isLiabilityAccountKind(kind);
}

String manualBalanceLabel({
  required AccountFormKind kind,
  required bool isEdit,
}) {
  if (isLiabilityAccountKind(kind)) return isEdit ? '当前欠款' : '初始欠款';
  return isEdit ? '当前余额' : '初始余额';
}

String manualBalanceHint({
  required AccountFormKind kind,
  required bool isEdit,
}) {
  if (isLiabilityAccountKind(kind)) return isEdit ? '请输入当前欠款' : '请输入初始欠款';
  return isEdit ? '请输入当前余额' : '请输入初始余额';
}

AccountFormKind accountFormKindForAccount(Account account) {
  if (account.type == AccountType.liability) {
    return account.subtype == AccountSubtype.loan
        ? AccountFormKind.loan
        : AccountFormKind.credit;
  }
  return account.subtype == AccountSubtype.reimbursement
      ? AccountFormKind.reimbursement
      : AccountFormKind.fund;
}

const Object _sentinel = Object();
const Money _invalidMoney = Money(minorUnits: -1);
