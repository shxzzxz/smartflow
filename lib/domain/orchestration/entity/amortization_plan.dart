import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../ledger/valobj/account_amount_allocation.dart';
import '../service/amortization_schedule.dart';
import '../valobj/amortization_enums.dart';
import '../valobj/amortization_error_code.dart';
import 'amortization_period.dart';
import 'amortization_refund.dart';
import 'amortization_termination.dart';

class AmortizationPlan {
  AmortizationPlan({
    required this.id,
    required this.kind,
    required this.deferralAccountId,
    required this.originalAmount,
    required Iterable<AccountAmountAllocation> fundingAllocations,
    required Iterable<AccountAmountAllocation> categoryAllocations,
    required this.cadenceUnit,
    required this.cadenceInterval,
    required this.firstRecognitionAt,
    required this.recognitionCount,
    required this.initialTransactionId,
    required Iterable<AmortizationPeriod> periods,
    Iterable<AmortizationRefund> refunds = const [],
    this.termination,
  }) : periods = List.unmodifiable(periods),
       refunds = List.unmodifiable(refunds),
       fundingAllocations = List.unmodifiable(fundingAllocations),
       categoryAllocations = List.unmodifiable(categoryAllocations) {
    validate();
  }

  factory AmortizationPlan.create({
    required String id,
    required AmortizationKind kind,
    required String deferralAccountId,
    required List<AccountAmountAllocation> fundingAllocations,
    required List<AccountAmountAllocation> categoryAllocations,
    required Money originalAmount,
    required AmortizationCadenceUnit cadenceUnit,
    required int cadenceInterval,
    required DateTime firstRecognitionAt,
    required int recognitionCount,
    required String initialTransactionId,
  }) {
    return AmortizationPlan(
      id: id,
      kind: kind,
      deferralAccountId: deferralAccountId,
      originalAmount: originalAmount,
      fundingAllocations: fundingAllocations,
      categoryAllocations: categoryAllocations,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      firstRecognitionAt: firstRecognitionAt,
      recognitionCount: recognitionCount,
      initialTransactionId: initialTransactionId,
      periods: buildAmortizationSchedule(
        planId: id,
        total: originalAmount,
        firstRecognitionAt: firstRecognitionAt,
        cadenceUnit: cadenceUnit,
        cadenceInterval: cadenceInterval,
        recognitionCount: recognitionCount,
        categoryAllocations: categoryAllocations,
      ),
    );
  }

  AmortizationPlan reconfigured({
    required String deferralAccountId,
    required Money originalAmount,
    required List<AccountAmountAllocation> fundingAllocations,
    required List<AccountAmountAllocation> categoryAllocations,
    required AmortizationCadenceUnit cadenceUnit,
    required int cadenceInterval,
    required DateTime firstRecognitionAt,
    required int recognitionCount,
  }) {
    if (termination != null) {
      throw _invalid(
        'termination',
        'A terminated plan cannot be reconfigured.',
      );
    }
    final nextCategoryAllocations = subtractAllocations(
      base: categoryAllocations,
      reductions: refunds.expand((refund) => refund.categoryAllocations),
    );
    final nextNetAmount =
        originalAmount -
        refunds.fold(Money.zero(), (total, refund) => total + refund.amount);
    final draftPeriods = buildAmortizationSchedule(
      planId: id,
      total: nextNetAmount,
      firstRecognitionAt: firstRecognitionAt,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      recognitionCount: recognitionCount,
      categoryAllocations: nextCategoryAllocations,
    );
    final existingBySequence = {
      for (final period in periods) period.sequenceNo: period,
    };
    return AmortizationPlan(
      id: id,
      kind: kind,
      deferralAccountId: deferralAccountId,
      originalAmount: originalAmount,
      fundingAllocations: fundingAllocations,
      categoryAllocations: categoryAllocations,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      firstRecognitionAt: firstRecognitionAt,
      recognitionCount: recognitionCount,
      initialTransactionId: initialTransactionId,
      periods: [
        for (final draft in draftPeriods)
          _reconcileReconfiguredPeriod(
            existingBySequence[draft.sequenceNo],
            draft,
          ),
      ],
      refunds: refunds,
    );
  }

  /// Rebuilds the schedule from the plan's current financial inputs.
  ///
  /// Configuration changes only replace the recognition cadence.
  /// Original amount, funding/category allocations and refunds remain the
  /// authoritative inputs, so the same recalculation path also handles plans
  /// with posted periods or refunds.
  AmortizationPlan reconfiguredConfiguration({
    required AmortizationCadenceUnit cadenceUnit,
    required int cadenceInterval,
    required DateTime firstRecognitionAt,
    required int recognitionCount,
  }) {
    final nextCategoryAllocations = currentCategoryAllocations;
    final draftPeriods = buildAmortizationSchedule(
      planId: id,
      total: netAmount,
      firstRecognitionAt: firstRecognitionAt,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      recognitionCount: recognitionCount,
      categoryAllocations: nextCategoryAllocations,
    );
    final existingBySequence = {
      for (final period in periods) period.sequenceNo: period,
    };
    final terminationAt = termination?.terminatedAt;
    return AmortizationPlan(
      id: id,
      kind: kind,
      deferralAccountId: deferralAccountId,
      originalAmount: originalAmount,
      fundingAllocations: fundingAllocations,
      categoryAllocations: categoryAllocations,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      firstRecognitionAt: firstRecognitionAt,
      recognitionCount: recognitionCount,
      initialTransactionId: initialTransactionId,
      periods: [
        for (final draft in draftPeriods)
          if (terminationAt != null &&
              _dateOnly(draft.dueAt).isAfter(_dateOnly(terminationAt)))
            _canceledPeriod(draft)
          else
            _reconcileReconfiguredPeriod(
              existingBySequence[draft.sequenceNo],
              draft,
            ),
      ],
      refunds: refunds,
      termination: termination,
    );
  }

  final String id;
  final AmortizationKind kind;
  final String deferralAccountId;
  final Money originalAmount;
  final List<AccountAmountAllocation> fundingAllocations;
  final List<AccountAmountAllocation> categoryAllocations;
  final AmortizationCadenceUnit cadenceUnit;
  final int cadenceInterval;
  final DateTime firstRecognitionAt;
  final int recognitionCount;
  final String initialTransactionId;
  final List<AmortizationPeriod> periods;
  final List<AmortizationRefund> refunds;
  final AmortizationTermination? termination;

  Money get refundedAmount =>
      refunds.fold(Money.zero(), (total, refund) => total + refund.amount);

  Money get netAmount => originalAmount - refundedAmount;

  List<AccountAmountAllocation> get currentCategoryAllocations =>
      _categoryAllocationsAfterRefunds(refunds);

  List<AccountAmountAllocation> categoryAllocationsExcludingRefund(
    String refundId,
  ) {
    return _categoryAllocationsAfterRefunds(
      refunds.where((refund) => refund.id != refundId),
    );
  }

  AmortizationStatus get status {
    if (termination != null) return AmortizationStatus.terminated;
    if (periods.every((period) => period.isPosted || period.isZero)) {
      return AmortizationStatus.completed;
    }
    if (netAmount == Money.zero()) return AmortizationStatus.completed;
    return AmortizationStatus.active;
  }

  AmortizationPeriod? get nextPendingPeriod =>
      periods.where((period) => period.isPending).firstOrNull;

  int get postedPeriodCount =>
      periods.where((period) => period.isPosted).length;

  /// 当前待确认期次；终止计划不再有当前期次。
  AmortizationPeriod? get currentPendingPeriod {
    if (status == AmortizationStatus.terminated) return null;
    return periods
        .where((period) => period.isPending && period.amount.minorUnits > 0)
        .firstOrNull;
  }

  AmortizationTransactionFactKind? transactionFactKind(String transactionId) {
    if (transactionId == initialTransactionId) {
      return AmortizationTransactionFactKind.initial;
    }
    if (periods.any((period) => period.transactionId == transactionId)) {
      return AmortizationTransactionFactKind.recognition;
    }
    if (refunds.any(
      (refund) => refund.transferTransactionId == transactionId,
    )) {
      return AmortizationTransactionFactKind.refund;
    }
    if (termination?.recognitionTransactionId == transactionId) {
      return AmortizationTransactionFactKind.terminationRecognition;
    }
    if (termination?.returnTransactionId == transactionId) {
      return AmortizationTransactionFactKind.terminationReturn;
    }
    return null;
  }

  DateTime get lastRecognitionAt => periods.last.dueAt;

  Money get recognizedAmount => periods
      .where((period) => period.isPosted)
      .fold(Money.zero(), (total, period) => total + period.amount);

  Money get remainingAmount => status == AmortizationStatus.terminated
      ? Money.zero()
      : netAmount - recognizedAmount;

  List<AmortizationPeriod> duePeriods(DateTime now) => [
    for (final period in periods)
      if (period.isPending &&
          period.amount.minorUnits > 0 &&
          !_dateOnly(period.dueAt).isAfter(_dateOnly(now)))
        period,
  ];

  List<AccountAmountAllocation> get recognizedCategoryAllocations {
    final totals = <String, int>{};
    final order = <String>[];
    for (final period in periods.where((period) => period.isPosted)) {
      for (final allocation in period.categoryAllocations) {
        if (!totals.containsKey(allocation.accountId)) {
          order.add(allocation.accountId);
        }
        totals[allocation.accountId] =
            (totals[allocation.accountId] ?? 0) + allocation.amount.minorUnits;
      }
    }
    return [
      for (final accountId in order)
        if ((totals[accountId] ?? 0) > 0)
          AccountAmountAllocation(
            accountId: accountId,
            amount: Money(minorUnits: totals[accountId]!),
          ),
    ];
  }

  List<AccountAmountAllocation> get remainingCategoryAllocations =>
      status == AmortizationStatus.terminated
      ? const []
      : subtractAllocations(
          base: currentCategoryAllocations,
          reductions: recognizedCategoryAllocations,
        );

  /// Category balance available immediately before an existing termination.
  List<AccountAmountAllocation>
  get remainingCategoryAllocationsBeforeTermination => subtractAllocations(
    base: currentCategoryAllocations,
    reductions: recognizedCategoryAllocations,
  );

  /// Category balances recognized when the plan is terminated.
  ///
  /// Returned category balances stay attached to the termination return fact
  /// and must not be recognized again by the termination confirmation.
  List<AccountAmountAllocation> get terminationRecognitionCategoryAllocations =>
      subtractAllocations(
        base: remainingCategoryAllocationsBeforeTermination,
        reductions: termination?.categoryReturnAllocations ?? const [],
      );

  AmortizationPlan withPeriods(Iterable<AmortizationPeriod> nextPeriods) {
    return _copyWith(periods: nextPeriods);
  }

  AmortizationPlan withRefund(AmortizationRefund refund) {
    if (refund.planId != id) {
      throw _invalid('refund.planId', 'Refund plan does not match.');
    }
    if (status == AmortizationStatus.terminated) {
      throw _invalid('refund', 'A terminated plan cannot be refunded.');
    }
    if (refunds.any((existing) => existing.id == refund.id)) {
      throw _invalid('refund.id', 'Refund already exists.');
    }
    if (refund.amount.minorUnits > netAmount.minorUnits ||
        !allocationsFitAvailable(
          requested: refund.categoryAllocations,
          available: currentCategoryAllocations,
        )) {
      throw _invalid(
        'refund',
        'Refund exceeds the current amortization balance.',
      );
    }
    return _withRefundFacts([...refunds, refund]);
  }

  AmortizationPlan withUpdatedRefund(AmortizationRefund refund) {
    if (refund.planId != id) {
      throw _invalid('refund.planId', 'Refund plan does not match.');
    }
    if (status == AmortizationStatus.terminated) {
      throw _invalid('refund', 'A terminated plan cannot be refunded.');
    }
    final index = refunds.indexWhere((existing) => existing.id == refund.id);
    if (index < 0) {
      throw _invalid('refund.id', 'Refund does not exist.');
    }
    if (!allocationsFitAvailable(
      requested: refund.categoryAllocations,
      available: categoryAllocationsExcludingRefund(refund.id),
    )) {
      throw _invalid(
        'refund',
        'Refund exceeds the current amortization balance.',
      );
    }
    final nextRefunds = [...refunds]..[index] = refund;
    return _withRefundFacts(nextRefunds);
  }

  AmortizationPlan withoutRefund(String refundId) {
    if (!refunds.any((refund) => refund.id == refundId)) {
      throw _invalid('refund.id', 'Refund does not exist.');
    }
    return _withRefundFacts([
      for (final refund in refunds)
        if (refund.id != refundId) refund,
    ]);
  }

  AmortizationPlan _withRefundFacts(List<AmortizationRefund> nextRefunds) {
    final nextCategoryAllocations = _categoryAllocationsAfterRefunds(
      nextRefunds,
    );
    final nextNetAmount =
        originalAmount -
        nextRefunds.fold(
          Money.zero(),
          (total, refund) => total + refund.amount,
        );
    if (sumAllocations(nextCategoryAllocations) != nextNetAmount) {
      throw _invalid(
        'refunds',
        'Refund allocations must preserve the net amount.',
      );
    }
    final draftPeriods = buildAmortizationSchedule(
      planId: id,
      total: nextNetAmount,
      firstRecognitionAt: firstRecognitionAt,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      recognitionCount: recognitionCount,
      categoryAllocations: nextCategoryAllocations,
    );
    final currentById = {for (final period in periods) period.id: period};
    final nextPeriods = [
      for (final draft in draftPeriods)
        _reconcilePeriod(currentById[draft.id]!, draft),
    ];
    return AmortizationPlan(
      id: id,
      kind: kind,
      deferralAccountId: deferralAccountId,
      originalAmount: originalAmount,
      fundingAllocations: fundingAllocations,
      categoryAllocations: categoryAllocations,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      firstRecognitionAt: firstRecognitionAt,
      recognitionCount: recognitionCount,
      initialTransactionId: initialTransactionId,
      periods: nextPeriods,
      refunds: nextRefunds,
      termination: termination,
    );
  }

  AmortizationPlan terminatedWith({
    required AmortizationTermination termination,
    required Iterable<AmortizationPeriod> periods,
  }) {
    return AmortizationPlan(
      id: id,
      kind: kind,
      deferralAccountId: deferralAccountId,
      originalAmount: originalAmount,
      fundingAllocations: fundingAllocations,
      categoryAllocations: categoryAllocations,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      firstRecognitionAt: firstRecognitionAt,
      recognitionCount: recognitionCount,
      initialTransactionId: initialTransactionId,
      periods: periods,
      refunds: refunds,
      termination: termination,
    );
  }

  AmortizationPlan withoutTermination(Iterable<AmortizationPeriod> periods) {
    return AmortizationPlan(
      id: id,
      kind: kind,
      deferralAccountId: deferralAccountId,
      originalAmount: originalAmount,
      fundingAllocations: fundingAllocations,
      categoryAllocations: categoryAllocations,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      firstRecognitionAt: firstRecognitionAt,
      recognitionCount: recognitionCount,
      initialTransactionId: initialTransactionId,
      periods: periods,
      refunds: refunds,
    );
  }

  void validate() {
    if (id.trim().isEmpty) throw _invalid('id', 'Plan id is required.');
    if (deferralAccountId.trim().isEmpty) {
      throw _invalid('deferralAccountId', 'Deferral account is required.');
    }
    if (initialTransactionId.trim().isEmpty) {
      throw _invalid(
        'initialTransactionId',
        'Initial transaction is required.',
      );
    }
    if (originalAmount.minorUnits <= 0) {
      throw _invalid('originalAmount', 'Original amount must be positive.');
    }
    if (cadenceInterval <= 0 || recognitionCount <= 0) {
      throw _invalid(
        'schedule',
        'Cadence interval and recognition count must be positive.',
      );
    }
    _validateAllocations(
      fundingAllocations,
      originalAmount,
      'fundingAllocations',
    );
    _validateAllocations(
      categoryAllocations,
      originalAmount,
      'categoryAllocations',
    );

    final refundIds = <String>{};
    final transferIds = <String>{};
    for (final refund in refunds) {
      if (refund.planId != id ||
          !refundIds.add(refund.id) ||
          !transferIds.add(refund.transferTransactionId)) {
        throw _invalid('refunds', 'Refund identities must be unique.');
      }
    }
    final currentCategories = currentCategoryAllocations;
    if (sumAllocations(currentCategories) != netAmount) {
      throw _invalid(
        'refunds',
        'Refund allocations must preserve the net amount.',
      );
    }

    final expected = buildAmortizationSchedule(
      planId: id,
      total: netAmount,
      firstRecognitionAt: firstRecognitionAt,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      recognitionCount: recognitionCount,
      categoryAllocations: currentCategories,
    );
    if (periods.length != expected.length) {
      throw _invalid('periods', 'Amortization period count does not match.');
    }
    final transactionIds = <String>{};
    for (var index = 0; index < periods.length; index++) {
      final actual = periods[index];
      final planned = expected[index];
      if (actual.id != planned.id ||
          actual.planId != id ||
          actual.sequenceNo != index + 1 ||
          actual.dueAt != planned.dueAt ||
          actual.amount != planned.amount ||
          !_sameAllocations(
            actual.categoryAllocations,
            planned.categoryAllocations,
          )) {
        throw _invalid(
          'periods[$index]',
          'Amortization period does not match the current schedule.',
        );
      }
      if (actual.amount.minorUnits == 0) {
        if (actual.status != AmortizationPeriodStatus.zero &&
            actual.status != AmortizationPeriodStatus.canceled) {
          throw _invalid(
            'periods[$index]',
            'A zero period must be completed or canceled.',
          );
        }
      } else if (actual.status == AmortizationPeriodStatus.zero) {
        throw _invalid(
          'periods[$index]',
          'A positive period cannot be marked zero.',
        );
      }
      final transactionId = actual.transactionId;
      if (actual.status == AmortizationPeriodStatus.posted) {
        if (transactionId == null || !transactionIds.add(transactionId)) {
          throw _invalid(
            'periods[$index]',
            'Posted periods require a unique transaction.',
          );
        }
      } else if (transactionId != null) {
        throw _invalid(
          'periods[$index]',
          'Only posted periods can reference a transaction.',
        );
      }
    }
    if (termination != null) {
      _validateTermination(termination!);
    }
  }

  void _validateTermination(AmortizationTermination value) {
    if (value.planId != id) {
      throw _invalid('termination.planId', 'Termination plan does not match.');
    }
    final remainingBeforeTermination = subtractAllocations(
      base: currentCategoryAllocations,
      reductions: recognizedCategoryAllocations,
    );
    if (!allocationsFitAvailable(
      requested: value.categoryReturnAllocations,
      available: remainingBeforeTermination,
    )) {
      throw _invalid(
        'termination',
        'Termination return exceeds remaining category balances.',
      );
    }
  }

  List<AccountAmountAllocation> _categoryAllocationsAfterRefunds(
    Iterable<AmortizationRefund> values,
  ) {
    return subtractAllocations(
      base: categoryAllocations,
      reductions: values.expand((refund) => refund.categoryAllocations),
    );
  }

  AmortizationPlan _copyWith({
    Iterable<AmortizationPeriod>? periods,
    Iterable<AmortizationRefund>? refunds,
    AmortizationTermination? termination,
  }) {
    return AmortizationPlan(
      id: id,
      kind: kind,
      deferralAccountId: deferralAccountId,
      originalAmount: originalAmount,
      fundingAllocations: fundingAllocations,
      categoryAllocations: categoryAllocations,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      firstRecognitionAt: firstRecognitionAt,
      recognitionCount: recognitionCount,
      initialTransactionId: initialTransactionId,
      periods: periods ?? this.periods,
      refunds: refunds ?? this.refunds,
      termination: termination ?? this.termination,
    );
  }

  static AmortizationPeriod _reconcilePeriod(
    AmortizationPeriod current,
    AmortizationPeriod draft,
  ) {
    if (draft.amount.minorUnits == 0) {
      return AmortizationPeriod(
        id: draft.id,
        planId: draft.planId,
        sequenceNo: draft.sequenceNo,
        dueAt: draft.dueAt,
        amount: draft.amount,
        categoryAllocations: const [],
        status: AmortizationPeriodStatus.zero,
      );
    }
    return AmortizationPeriod(
      id: draft.id,
      planId: draft.planId,
      sequenceNo: draft.sequenceNo,
      dueAt: draft.dueAt,
      amount: draft.amount,
      categoryAllocations: draft.categoryAllocations,
      transactionId: current.transactionId,
      status: current.transactionId == null
          ? AmortizationPeriodStatus.pending
          : AmortizationPeriodStatus.posted,
    );
  }

  static AmortizationPeriod _reconcileReconfiguredPeriod(
    AmortizationPeriod? current,
    AmortizationPeriod draft,
  ) {
    if (draft.amount.minorUnits == 0) {
      return AmortizationPeriod(
        id: draft.id,
        planId: draft.planId,
        sequenceNo: draft.sequenceNo,
        dueAt: draft.dueAt,
        amount: draft.amount,
        categoryAllocations: const [],
        status: AmortizationPeriodStatus.zero,
      );
    }
    final currentTransactionId = current?.isPosted == true
        ? current!.transactionId
        : null;
    return AmortizationPeriod(
      id: draft.id,
      planId: draft.planId,
      sequenceNo: draft.sequenceNo,
      dueAt: draft.dueAt,
      amount: draft.amount,
      categoryAllocations: draft.categoryAllocations,
      transactionId: currentTransactionId,
      status: currentTransactionId == null
          ? AmortizationPeriodStatus.pending
          : AmortizationPeriodStatus.posted,
    );
  }

  static AmortizationPeriod _canceledPeriod(AmortizationPeriod draft) {
    return AmortizationPeriod(
      id: draft.id,
      planId: draft.planId,
      sequenceNo: draft.sequenceNo,
      dueAt: draft.dueAt,
      amount: draft.amount,
      categoryAllocations: draft.categoryAllocations,
      status: AmortizationPeriodStatus.canceled,
    );
  }

  static void _validateAllocations(
    Iterable<AccountAmountAllocation> allocations,
    Money total,
    String field,
  ) {
    if (allocations.isEmpty) {
      throw _invalid(field, 'Plan allocations cannot be empty.');
    }
    final accountIds = <String>{};
    for (final allocation in allocations) {
      if (allocation.amount.minorUnits <= 0 ||
          !accountIds.add(allocation.accountId)) {
        throw _invalid(
          field,
          'Plan allocations must be positive and unique by account.',
        );
      }
    }
    if (sumAllocations(allocations) != total) {
      throw _invalid(field, 'Plan allocations must equal the original amount.');
    }
  }

  static bool _sameAllocations(
    Iterable<AccountAmountAllocation> left,
    Iterable<AccountAmountAllocation> right,
  ) {
    final leftList = left.toList(growable: false);
    final rightList = right.toList(growable: false);
    if (leftList.length != rightList.length) return false;
    for (var index = 0; index < leftList.length; index++) {
      if (leftList[index].accountId != rightList[index].accountId ||
          leftList[index].amount != rightList[index].amount) {
        return false;
      }
    }
    return true;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

BusinessException _invalid(String field, String message) {
  return BusinessException(
    AmortizationErrorCode.invalidCommand,
    message: '$message ($field)',
  );
}
