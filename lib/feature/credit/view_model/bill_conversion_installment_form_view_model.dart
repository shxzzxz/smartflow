import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart' as credit;
import '../../../application/credit/credit_query_api.dart' as credit_query;
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/bill_query_providers.dart';
import '../provider/credit_account_query_providers.dart';
import '../provider/installment_query_providers.dart';
import 'bill_repayment_allocation_view_model.dart';

part 'bill_conversion_installment_form_view_model.g.dart';

@riverpod
class BillConversionInstallmentFormViewModel
    extends _$BillConversionInstallmentFormViewModel {
  @override
  Future<BillConversionInstallmentFormState> build(String billId) async {
    final detail = await ref.watch(billDetailProvider(billId).future);
    if (detail == null) {
      return const BillConversionInstallmentFormState.notFound();
    }
    if (detail.summary.status != credit.BillStatus.billed) {
      return BillConversionInstallmentFormState.notEligible(
        summary: detail.summary,
      );
    }

    final lines = _conversionLines(detail);
    if (lines.isEmpty) {
      return BillConversionInstallmentFormState.noPending(
        summary: detail.summary,
      );
    }

    final principal = _pendingPrincipal(lines);
    final borrowingDate = detail.summary.dueDate ?? DateTime.now();
    return BillConversionInstallmentFormState.loaded(
      summary: detail.summary,
      lines: lines,
      principalText: principal.format(),
      totalPeriodsText: '12',
      borrowingDate: borrowingDate,
      firstRepaymentDate: _addMonths(borrowingDate, 1),
    );
  }

  void setPrincipalText(String value) =>
      _updateLoaded((state) => state.copyWith(principalText: value));

  void setTotalPeriodsText(String value) =>
      _updateLoaded((state) => state.copyWith(totalPeriodsText: value));

  void setRateText(String value) =>
      _updateLoaded((state) => state.copyWith(rateText: value));

  void setTotalFeeText(String value) =>
      _updateLoaded((state) => state.copyWith(totalFeeText: value));

  void setOverrideInstallmentText(String value) =>
      _updateLoaded((state) => state.copyWith(overrideInstallmentText: value));

  void setNoteText(String value) =>
      _updateLoaded((state) => state.copyWith(noteText: value));

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

  void setMethod(credit.InstallmentRepaymentMethod value) =>
      _updateLoaded((state) => state.copyWith(method: value));

  void setRatePeriod(credit.InterestRatePeriod value) =>
      _updateLoaded((state) => state.copyWith(ratePeriod: value));

  void setAccrualMethod(credit.InterestAccrualMethod value) =>
      _updateLoaded((state) => state.copyWith(accrualMethod: value));

  void setAllocationMode(BillRepaymentAllocationMode value) =>
      _updateLoaded((state) => state.copyWith(allocationMode: value));

  Future<UiActionOutcome<String>> submit() async {
    final current = _loadedOrNull();
    if (current == null) return _invalidAction('账单分期表单尚未加载');

    final principal = _parsePositiveMoney(current.principalText);
    if (principal == null) return _invalidAction('请输入有效本金');
    if (principal.minorUnits > current.convertiblePrincipal.minorUnits) {
      return _invalidAction('分期本金不能超过可分期本金');
    }

    final totalPeriods = int.tryParse(current.totalPeriodsText.trim());
    if (totalPeriods == null || totalPeriods <= 0) {
      return _invalidAction('请输入有效期数');
    }

    final ratePpm = _parseRatePpm(current.rateText);
    final totalFee = _parseOptionalMoney(current.totalFeeText);
    if (totalFee == null) return _invalidAction('请输入有效手续费');
    final overrideMinor =
        current.method == credit.InstallmentRepaymentMethod.equalInstallment
            ? _parseOptionalOverride(current.overrideInstallmentText)
            : null;

    final review = _allocationReview(
      lines: current.lines,
      mode: current.allocationMode,
      amount: credit.RepaymentAmountBreakdown(
        principal: principal,
        interest: Money.zero(),
        fee: Money.zero(),
        discount: Money.zero(),
      ),
    );
    if (review.allocations.isEmpty ||
        review.totalAllocated.principal.minorUnits <= 0) {
      return _invalidAction('账单没有可分期明细');
    }

    _setLoaded(current.copyWith(submitting: true));
    try {
      final result = await ref
          .read(repaymentAppServiceProvider)
          .createBillConversionInstallmentRepayment(
            credit.CreateBillConversionInstallmentRepaymentCommand(
              billId: billId,
              allocations: review.allocations,
              totalPeriods: totalPeriods,
              borrowingDate: current.borrowingDate,
              firstRepaymentDate: current.firstRepaymentDate,
              repaymentMethod: current.method,
              interestRatePeriod: ratePpm == null ? null : current.ratePeriod,
              interestRatePpm: ratePpm,
              interestAccrualMethod: current.accrualMethod,
              totalFeeMinor: totalFee.minorUnits,
              equalInstallmentOverrideMinor: overrideMinor,
              note: trimToNull(current.noteText),
            ),
          );
      _invalidateAfterSubmit(accountId: current.summary.accountId);
      return UiActionOutcome.success(result.contractId!);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(UiError.unknown());
    } finally {
      final latest = _loadedOrNull();
      if (latest != null) {
        _setLoaded(latest.copyWith(submitting: false));
      }
    }
  }

  void _invalidateAfterSubmit({required String accountId}) {
    ref.invalidate(billDetailProvider(billId));
    ref.invalidate(billSummariesByAccountProvider(accountId));
    ref.invalidate(creditAccountOverviewProvider(accountId));
    ref.invalidate(installmentContractsByAccountProvider(accountId));
  }

  BillConversionInstallmentLoaded? _loadedOrNull() {
    final current = state.asData?.value;
    return current is BillConversionInstallmentLoaded ? current : null;
  }

  void _updateLoaded(
    BillConversionInstallmentLoaded Function(BillConversionInstallmentLoaded)
    update,
  ) {
    final current = _loadedOrNull();
    if (current == null) return;
    _setLoaded(update(current));
  }

  void _setLoaded(BillConversionInstallmentLoaded value) {
    state = AsyncData(value);
  }

  UiActionOutcome<String> _invalidAction(String message) {
    return UiActionOutcome.failure(
      UiError(
        code: credit.CreditErrorCode.billInvalidCommand.code,
        message: message,
      ),
    );
  }
}

sealed class BillConversionInstallmentFormState {
  const BillConversionInstallmentFormState();

  const factory BillConversionInstallmentFormState.loaded({
    required credit_query.BillSummaryReadModel summary,
    required List<BillRepaymentAllocationLine> lines,
    required String principalText,
    required String totalPeriodsText,
    required DateTime borrowingDate,
    required DateTime firstRepaymentDate,
  }) = BillConversionInstallmentLoaded;

  const factory BillConversionInstallmentFormState.notFound() =
      BillConversionInstallmentNotFound;

  const factory BillConversionInstallmentFormState.notEligible({
    required credit_query.BillSummaryReadModel summary,
  }) = BillConversionInstallmentNotEligible;

  const factory BillConversionInstallmentFormState.noPending({
    required credit_query.BillSummaryReadModel summary,
  }) = BillConversionInstallmentNoPending;
}

class BillConversionInstallmentLoaded
    extends BillConversionInstallmentFormState {
  const BillConversionInstallmentLoaded({
    required this.summary,
    required this.lines,
    required this.principalText,
    required this.totalPeriodsText,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    this.firstDateTouched = false,
    this.method = credit.InstallmentRepaymentMethod.equalInstallment,
    this.ratePeriod = credit.InterestRatePeriod.monthly,
    this.accrualMethod = credit.InterestAccrualMethod.daily,
    this.allocationMode = BillRepaymentAllocationMode.fifo,
    this.rateText = '',
    this.totalFeeText = '',
    this.overrideInstallmentText = '',
    this.noteText = '',
    this.submitting = false,
  });

  final credit_query.BillSummaryReadModel summary;
  final List<BillRepaymentAllocationLine> lines;
  final String principalText;
  final String totalPeriodsText;
  final DateTime borrowingDate;
  final DateTime firstRepaymentDate;
  final bool firstDateTouched;
  final credit.InstallmentRepaymentMethod method;
  final credit.InterestRatePeriod ratePeriod;
  final credit.InterestAccrualMethod accrualMethod;
  final BillRepaymentAllocationMode allocationMode;
  final String rateText;
  final String totalFeeText;
  final String overrideInstallmentText;
  final String noteText;
  final bool submitting;

  Money get convertiblePrincipal => _pendingPrincipal(lines);

  BillConversionInstallmentLoaded copyWith({
    String? principalText,
    String? totalPeriodsText,
    DateTime? borrowingDate,
    DateTime? firstRepaymentDate,
    bool? firstDateTouched,
    credit.InstallmentRepaymentMethod? method,
    credit.InterestRatePeriod? ratePeriod,
    credit.InterestAccrualMethod? accrualMethod,
    BillRepaymentAllocationMode? allocationMode,
    String? rateText,
    String? totalFeeText,
    String? overrideInstallmentText,
    String? noteText,
    bool? submitting,
  }) {
    return BillConversionInstallmentLoaded(
      summary: summary,
      lines: lines,
      principalText: principalText ?? this.principalText,
      totalPeriodsText: totalPeriodsText ?? this.totalPeriodsText,
      borrowingDate: borrowingDate ?? this.borrowingDate,
      firstRepaymentDate: firstRepaymentDate ?? this.firstRepaymentDate,
      firstDateTouched: firstDateTouched ?? this.firstDateTouched,
      method: method ?? this.method,
      ratePeriod: ratePeriod ?? this.ratePeriod,
      accrualMethod: accrualMethod ?? this.accrualMethod,
      allocationMode: allocationMode ?? this.allocationMode,
      rateText: rateText ?? this.rateText,
      totalFeeText: totalFeeText ?? this.totalFeeText,
      overrideInstallmentText:
          overrideInstallmentText ?? this.overrideInstallmentText,
      noteText: noteText ?? this.noteText,
      submitting: submitting ?? this.submitting,
    );
  }
}

class BillConversionInstallmentNotFound
    extends BillConversionInstallmentFormState {
  const BillConversionInstallmentNotFound();
}

class BillConversionInstallmentNotEligible
    extends BillConversionInstallmentFormState {
  const BillConversionInstallmentNotEligible({required this.summary});

  final credit_query.BillSummaryReadModel summary;
}

class BillConversionInstallmentNoPending
    extends BillConversionInstallmentFormState {
  const BillConversionInstallmentNoPending({required this.summary});

  final credit_query.BillSummaryReadModel summary;
}

List<BillRepaymentAllocationLine> _conversionLines(
  credit_query.BillDetailReadModel detail,
) {
  return [
    for (final item in detail.items)
      if (item.itemType == credit.BillItemType.consumption &&
          item.status == credit.BillItemStatus.pending)
        BillRepaymentAllocationLine(
          billItemId: item.id,
          itemType: item.itemType,
          expected: credit.RepaymentAmountBreakdown(
            principal: item.expectedPrincipal,
            interest: Money.zero(),
            fee: Money.zero(),
            discount: Money.zero(),
          ),
          alreadyAllocated: item.allocated,
        ),
  ];
}

Money _pendingPrincipal(List<BillRepaymentAllocationLine> lines) {
  return Money(
    minorUnits: lines.fold<int>(
      0,
      (sum, line) => sum + line.remainingPrincipal,
    ),
  );
}

BillRepaymentAllocationReview _allocationReview({
  required List<BillRepaymentAllocationLine> lines,
  required BillRepaymentAllocationMode mode,
  required credit.RepaymentAmountBreakdown amount,
}) {
  return BillRepaymentAllocationViewModel(
    lines: lines,
  ).suggest(mode: mode, amount: amount);
}

Money? _parsePositiveMoney(String value) {
  final money = Money.tryParse(value);
  return money != null && money.minorUnits > 0 ? money : null;
}

Money? _parseOptionalMoney(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return Money.zero();
  final money = Money.tryParse(trimmed);
  return money != null && money.minorUnits >= 0 ? money : null;
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
