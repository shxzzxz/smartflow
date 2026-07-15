import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:logging/logging.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/installment_query_providers.dart';
import '../provider/credit_account_query_providers.dart';

part 'installment_form_view_model.g.dart';

final _logger = Logger('feature.credit.installment_form');

@riverpod
class InstallmentFormViewModel extends _$InstallmentFormViewModel {
  @override
  Future<InstallmentFormState> build(InstallmentFormArgs args) async {
    final liabilityAccounts = await ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.repaymentTarget,
      ).future,
    );
    final fundAccounts = await ref.watch(
      accountsForSelectionPurposeProvider(AccountSelectionPurpose.fund).future,
    );
    final liability = _findAccount(liabilityAccounts, args.liabilityAccountId);
    if (liability == null) {
      return InstallmentFormState.notFound(
        liabilityAccounts: liabilityAccounts,
        fundAccounts: fundAccounts,
      );
    }

    final now = DateTime.now();
    return InstallmentFormState.loaded(
      liabilityAccounts: liabilityAccounts,
      fundAccounts: fundAccounts,
      liability: liability,
      sourceType: InstallmentSourceType.disbursement,
      borrowingDate: now,
      firstRepaymentDate: DateTime(now.year, now.month + 1, now.day),
    );
  }

  void setBorrowingDate(DateTime value) {
    _updateLoaded((state) {
      return state.copyWith(
        borrowingDate: value,
        firstRepaymentDate:
            state.firstDateTouched
                ? state.firstRepaymentDate
                : _addMonths(value, 1),
      );
    });
  }

  void setFirstRepaymentDate(DateTime value) {
    _updateLoaded(
      (state) =>
          state.copyWith(firstRepaymentDate: value, firstDateTouched: true),
    );
  }

  void setLastRepaymentDate(DateTime value) {
    _updateLoaded((state) => state.copyWith(lastRepaymentDate: value));
  }

  void setMethod(InstallmentRepaymentMethod value) =>
      _updateLoaded((state) => state.copyWith(method: value));

  void setRatePeriod(InterestRatePeriod value) =>
      _updateLoaded((state) => state.copyWith(ratePeriod: value));

  void setAccrualMethod(InterestAccrualMethod value) =>
      _updateLoaded((state) => state.copyWith(accrualMethod: value));

  void setDisbursementAccountId(String? value) =>
      _updateLoaded((state) => state.copyWith(disbursementAccountId: value));

  void setCreateDisbursementTransaction(bool value) => _updateLoaded(
    (state) => state.copyWith(createDisbursementTransaction: value),
  );

  Future<UiActionOutcome<String>> submit({
    required String principalText,
    required String totalPeriodsText,
    required String rateText,
    required String totalFeeText,
    required String overrideInstallmentText,
    required String noteText,
  }) async {
    final current = _loadedOrNull();
    if (current == null) return _invalidAction('分期表单尚未加载');

    final principal = _parsePositiveMoney(principalText);
    if (principal == null) return _invalidAction('请输入有效本金');
    final totalPeriods = int.tryParse(totalPeriodsText.trim());
    if (totalPeriods == null || totalPeriods <= 0) {
      return _invalidAction('请输入有效期数');
    }
    final lastRepaymentDate = current.lastRepaymentDate;
    if (lastRepaymentDate != null &&
        totalPeriods > 1 &&
        !lastRepaymentDate.isAfter(current.firstRepaymentDate)) {
      return _invalidAction('末期还款日必须晚于首期还款日');
    }
    if (current.isDisbursement &&
        current.createDisbursementTransaction &&
        current.disbursementAccountId == null) {
      return _invalidAction('请选择放款入账账户');
    }

    final ratePpm = _parseRatePpm(rateText);
    final totalFee = _parseOptionalMoney(totalFeeText);
    if (totalFee == null) return _invalidAction('请输入有效手续费');
    final overrideMinor =
        current.method == InstallmentRepaymentMethod.equalInstallment
            ? _parseOptionalOverride(overrideInstallmentText)
            : null;

    _setLoaded(current.copyWith(submitting: true));
    try {
      final service = ref.read(installmentAppServiceProvider);
      final note = trimToNull(noteText);
      final result = await service.createDisbursementContract(
        CreateDisbursementContractCommand(
          liabilityAccountId: current.liability.id,
          disbursementAccountId:
              current.createDisbursementTransaction
                  ? current.disbursementAccountId
                  : null,
          principal: principal,
          totalPeriods: totalPeriods,
          borrowingDate: current.borrowingDate,
          firstRepaymentDate: current.firstRepaymentDate,
          lastRepaymentDate: current.lastRepaymentDate,
          repaymentMethod: current.method,
          interestRatePeriod: ratePpm == null ? null : current.ratePeriod,
          interestRatePpm: ratePpm,
          interestAccrualMethod: current.accrualMethod,
          totalFeeMinor: totalFee.minorUnits,
          equalInstallmentOverrideMinor: overrideMinor,
          note: note,
        ),
      );
      ref.invalidate(
        installmentContractsByAccountProvider(current.liability.id),
      );
      ref.invalidate(creditAccountOverviewProvider(current.liability.id));
      return UiActionOutcome.success(result.contractId);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception catch (exception, stackTrace) {
      _logger.severe(
        'Installment form submission failed unexpectedly.',
        exception,
        stackTrace,
      );
      return const UiActionOutcome.failure(UiError.unknown());
    } finally {
      final latest = _loadedOrNull();
      if (latest != null) {
        _setLoaded(latest.copyWith(submitting: false));
      }
    }
  }

  InstallmentFormLoaded? _loadedOrNull() {
    final current = state.asData?.value;
    return current is InstallmentFormLoaded ? current : null;
  }

  void _updateLoaded(
    InstallmentFormLoaded Function(InstallmentFormLoaded state) update,
  ) {
    final current = _loadedOrNull();
    if (current == null) return;
    _setLoaded(update(current));
  }

  void _setLoaded(InstallmentFormLoaded value) {
    state = AsyncData(value);
  }

  UiActionOutcome<String> _invalidAction(String message) {
    return UiActionOutcome.failure(
      UiError(
        code: CreditErrorCode.contractInvalidCommand.code,
        message: message,
      ),
    );
  }
}

class InstallmentFormArgs {
  const InstallmentFormArgs({
    required this.liabilityAccountId,
    this.lockedSourceType,
  });

  final String liabilityAccountId;
  final InstallmentSourceType? lockedSourceType;

  @override
  bool operator ==(Object other) {
    return other is InstallmentFormArgs &&
        other.liabilityAccountId == liabilityAccountId &&
        other.lockedSourceType == lockedSourceType;
  }

  @override
  int get hashCode => Object.hash(liabilityAccountId, lockedSourceType);
}

sealed class InstallmentFormState {
  const InstallmentFormState({
    required this.liabilityAccounts,
    required this.fundAccounts,
  });

  factory InstallmentFormState.loaded({
    required List<Account> liabilityAccounts,
    required List<Account> fundAccounts,
    required Account liability,
    required InstallmentSourceType sourceType,
    required DateTime borrowingDate,
    required DateTime firstRepaymentDate,
    DateTime? lastRepaymentDate,
  }) {
    return InstallmentFormLoaded.initial(
      liabilityAccounts: liabilityAccounts,
      fundAccounts: fundAccounts,
      liability: liability,
      sourceType: sourceType,
      borrowingDate: borrowingDate,
      firstRepaymentDate: firstRepaymentDate,
      lastRepaymentDate: lastRepaymentDate,
    );
  }

  factory InstallmentFormState.notFound({
    required List<Account> liabilityAccounts,
    required List<Account> fundAccounts,
  }) {
    return InstallmentFormNotFound(
      liabilityAccounts: liabilityAccounts,
      fundAccounts: fundAccounts,
    );
  }

  final List<Account> liabilityAccounts;
  final List<Account> fundAccounts;
}

class InstallmentFormNotFound extends InstallmentFormState {
  const InstallmentFormNotFound({
    required super.liabilityAccounts,
    required super.fundAccounts,
  });
}

class InstallmentFormLoaded extends InstallmentFormState {
  const InstallmentFormLoaded({
    required super.liabilityAccounts,
    required super.fundAccounts,
    required this.liability,
    required this.sourceType,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.lastRepaymentDate,
    required this.firstDateTouched,
    required this.method,
    required this.ratePeriod,
    required this.accrualMethod,
    required this.createDisbursementTransaction,
    required this.submitting,
    this.disbursementAccountId,
  });

  factory InstallmentFormLoaded.initial({
    required List<Account> liabilityAccounts,
    required List<Account> fundAccounts,
    required Account liability,
    required InstallmentSourceType sourceType,
    required DateTime borrowingDate,
    required DateTime firstRepaymentDate,
    DateTime? lastRepaymentDate,
  }) {
    return InstallmentFormLoaded(
      liabilityAccounts: liabilityAccounts,
      fundAccounts: fundAccounts,
      liability: liability,
      sourceType: sourceType,
      borrowingDate: borrowingDate,
      firstRepaymentDate: firstRepaymentDate,
      lastRepaymentDate: lastRepaymentDate,
      firstDateTouched: false,
      method: InstallmentRepaymentMethod.equalInstallment,
      ratePeriod: InterestRatePeriod.monthly,
      accrualMethod: InterestAccrualMethod.daily,
      createDisbursementTransaction: true,
      submitting: false,
    );
  }

  final Account liability;
  final InstallmentSourceType sourceType;
  final String? disbursementAccountId;
  final DateTime borrowingDate;
  final DateTime firstRepaymentDate;
  final DateTime? lastRepaymentDate;
  final bool firstDateTouched;
  final InstallmentRepaymentMethod method;
  final InterestRatePeriod ratePeriod;
  final InterestAccrualMethod accrualMethod;
  final bool createDisbursementTransaction;
  final bool submitting;

  bool get isDisbursement => sourceType == InstallmentSourceType.disbursement;

  InstallmentFormLoaded copyWith({
    InstallmentSourceType? sourceType,
    Object? disbursementAccountId = _sentinel,
    DateTime? borrowingDate,
    DateTime? firstRepaymentDate,
    DateTime? lastRepaymentDate,
    bool? firstDateTouched,
    InstallmentRepaymentMethod? method,
    InterestRatePeriod? ratePeriod,
    InterestAccrualMethod? accrualMethod,
    bool? createDisbursementTransaction,
    bool? submitting,
  }) {
    return InstallmentFormLoaded(
      liabilityAccounts: liabilityAccounts,
      fundAccounts: fundAccounts,
      liability: liability,
      sourceType: sourceType ?? this.sourceType,
      disbursementAccountId:
          disbursementAccountId == _sentinel
              ? this.disbursementAccountId
              : disbursementAccountId as String?,
      borrowingDate: borrowingDate ?? this.borrowingDate,
      firstRepaymentDate: firstRepaymentDate ?? this.firstRepaymentDate,
      lastRepaymentDate: lastRepaymentDate ?? this.lastRepaymentDate,
      firstDateTouched: firstDateTouched ?? this.firstDateTouched,
      method: method ?? this.method,
      ratePeriod: ratePeriod ?? this.ratePeriod,
      accrualMethod: accrualMethod ?? this.accrualMethod,
      createDisbursementTransaction:
          createDisbursementTransaction ?? this.createDisbursementTransaction,
      submitting: submitting ?? this.submitting,
    );
  }
}

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

Money? _parsePositiveMoney(String value) {
  final money = Money.tryParse(value);
  return money != null && money.minorUnits > 0 ? money : null;
}

Money? _parseOptionalMoney(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return Money.zero();
  return Money.tryParse(trimmed);
}

int? _parseOptionalOverride(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final money = Money.tryParse(trimmed);
  if (money == null || money.minorUnits <= 0) return null;
  return money.minorUnits;
}

int? _parseRatePpm(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final percent = double.tryParse(trimmed);
  if (percent == null || percent <= 0) return null;
  return (percent * 10000).round();
}

DateTime _addMonths(DateTime date, int months) {
  return DateTime(date.year, date.month + months, date.day);
}

const Object _sentinel = Object();
