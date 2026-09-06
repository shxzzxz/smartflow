import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart' as credit;
import '../../../application/credit/credit_query_api.dart' as credit_query;
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/bill_repayment_allocation.dart';
import '../provider/bill_query_providers.dart';
import '../provider/credit_account_query_providers.dart';
import '../provider/installment_query_providers.dart';
import 'bill_repayment_command_mapping.dart';
import 'installment_terms_draft.dart';

part 'bill_conversion_installment_form_view_model.g.dart';

final _logger = Logger('feature.credit.bill_conversion_form');

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
    final borrowingDate = detail.summary.windowRepaymentDate ?? DateTime.now();
    return BillConversionInstallmentFormState.loaded(
      summary: detail.summary,
      lines: lines,
      principalText: principal.format(),
      borrowingDate: borrowingDate,
      termsDraft: InstallmentTermsDraft.loan(borrowingDate),
    );
  }

  void setBorrowingDate(DateTime value) =>
      _updateLoaded((s) => s.copyWith(borrowingDate: value));
  void setTermsDraft(InstallmentTermsDraft value) =>
      _updateLoaded((s) => s.copyWith(termsDraft: value));

  Future<UiActionOutcome<credit_query.LoanCalculation>> preview(
    String principalText,
  ) => guardUiAction(_logger, 'Preview bill installment', () async {
    final current = state.requireValue as BillConversionInstallmentLoaded;
    final principal = _parsePositiveMoney(principalText);
    if (principal == null ||
        principal.minorUnits > current.convertiblePrincipal.minorUnits) {
      throw BusinessException(
        credit.CreditErrorCode.billInvalidCommand,
        message: '请输入不超过可分期本金的有效金额',
      );
    }
    return ref
        .read(loanCalculatorQueryProvider)
        .calculate(
          current.termsDraft.contractTerms().planTerms(
            principal,
            current.borrowingDate,
          ),
        );
  });

  void setAllocationMode(BillRepaymentAllocationMode value) =>
      _updateLoaded((state) => state.copyWith(allocationMode: value));

  Future<UiActionOutcome<String>> submit({
    required String principalText,
    required String noteText,
  }) async {
    final current = _loadedOrNull();
    if (current == null) return _invalidAction('账单分期表单尚未加载');

    final principal = _parsePositiveMoney(principalText);
    if (principal == null) return _invalidAction('请输入有效本金');
    if (principal.minorUnits > current.convertiblePrincipal.minorUnits) {
      return _invalidAction('分期本金不能超过可分期本金');
    }

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
      return await guardUiAction(
        _logger,
        'Bill installment conversion submit',
        () async {
          final result = await ref
              .read(repaymentAppServiceProvider)
              .createBillConversionInstallmentRepayment(
                credit.CreateBillConversionInstallmentRepaymentCommand(
                  billId: billId,
                  allocations: billRepaymentCommandAllocations(
                    review.allocations,
                  ),
                  borrowingDate: current.borrowingDate,
                  stageTerms: current.termsDraft.contractTerms(),
                  note: trimToNull(noteText),
                ),
              );
          _invalidateAfterSubmit(accountId: current.summary.accountId);
          return result.contractId!;
        },
      );
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
    required DateTime borrowingDate,
    required InstallmentTermsDraft termsDraft,
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
    required this.borrowingDate,
    required this.termsDraft,
    this.allocationMode = BillRepaymentAllocationMode.fifo,
    this.submitting = false,
  });
  final credit_query.BillSummaryReadModel summary;
  final List<BillRepaymentAllocationLine> lines;
  final String principalText;
  final DateTime borrowingDate;
  final InstallmentTermsDraft termsDraft;
  final BillRepaymentAllocationMode allocationMode;
  final bool submitting;
  Money get convertiblePrincipal => _pendingPrincipal(lines);
  BillConversionInstallmentLoaded copyWith({
    DateTime? borrowingDate,
    InstallmentTermsDraft? termsDraft,
    BillRepaymentAllocationMode? allocationMode,
    bool? submitting,
  }) => BillConversionInstallmentLoaded(
    summary: summary,
    lines: lines,
    principalText: principalText,
    borrowingDate: borrowingDate ?? this.borrowingDate,
    termsDraft: termsDraft ?? this.termsDraft,
    allocationMode: allocationMode ?? this.allocationMode,
    submitting: submitting ?? this.submitting,
  );
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
          (item.status == credit.BillItemStatus.pending ||
              item.status == credit.BillItemStatus.partiallyPaid))
        BillRepaymentAllocationLine(
          billItemId: item.id,
          itemType: item.itemType,
          expected: credit.RepaymentAmountBreakdown(
            principal: item.expectedPrincipal,
            interest: Money.zero(),
            fee: Money.zero(),
            discount: Money.zero(),
          ),
          alreadyAllocated: credit.RepaymentAmountBreakdown(
            principal: item.allocated.principal,
            interest: item.allocated.interest,
            fee: item.allocated.fee,
            discount: item.allocated.discount,
          ),
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
  return BillRepaymentAllocator(
    lines: lines,
  ).suggest(mode: mode, amount: amount);
}

Money? _parsePositiveMoney(String value) {
  final money = Money.tryParse(value);
  return money != null && money.minorUnits > 0 ? money : null;
}
