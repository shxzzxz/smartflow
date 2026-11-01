import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../ledger/valobj/account_amount_allocation.dart';
import '../service/amortization_schedule.dart';
import '../valobj/amortization_enums.dart';
import '../valobj/amortization_error_code.dart';
import 'amortization_entry.dart';

class AmortizationPlan {
  AmortizationPlan({
    required this.id,
    required this.kind,
    required this.deferralAccountId,
    required this.total,
    required this.cadenceUnit,
    required this.cadenceInterval,
    required this.firstRecognitionAt,
    required this.recognitionCount,
    required this.defaultIsExcludedFromStats,
    required this.defaultIsExcludedFromBudget,
    required this.initialTransactionId,
    required Iterable<AmortizationEntry> entries,
    this.counterpartyId,
    this.note,
    this.terminatedAt,
    this.terminationRecognitionTransactionId,
    this.refundTransactionId,
    this.refundAmount,
  }) : entries = List.unmodifiable(entries) {
    validate();
  }

  factory AmortizationPlan.create({
    required String id,
    required AmortizationKind kind,
    required String deferralAccountId,
    required List<AccountAmountAllocation> recognitionAllocations,
    required Money total,
    required AmortizationCadenceUnit cadenceUnit,
    required int cadenceInterval,
    required DateTime firstRecognitionAt,
    required int recognitionCount,
    required bool defaultIsExcludedFromStats,
    required bool defaultIsExcludedFromBudget,
    required String initialTransactionId,
    String? counterpartyId,
    String? note,
  }) {
    return AmortizationPlan(
      id: id,
      kind: kind,
      deferralAccountId: deferralAccountId,
      total: total,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      firstRecognitionAt: firstRecognitionAt,
      recognitionCount: recognitionCount,
      defaultIsExcludedFromStats: defaultIsExcludedFromStats,
      defaultIsExcludedFromBudget: defaultIsExcludedFromBudget,
      initialTransactionId: initialTransactionId,
      counterpartyId: counterpartyId,
      note: note,
      entries: buildAmortizationSchedule(
        planId: id,
        total: total,
        firstRecognitionAt: firstRecognitionAt,
        cadenceUnit: cadenceUnit,
        cadenceInterval: cadenceInterval,
        recognitionCount: recognitionCount,
        categoryAllocations: recognitionAllocations,
      ),
    );
  }

  final String id;
  final AmortizationKind kind;
  final String deferralAccountId;
  final Money total;
  final AmortizationCadenceUnit cadenceUnit;
  final int cadenceInterval;
  final DateTime firstRecognitionAt;
  final int recognitionCount;
  final bool defaultIsExcludedFromStats;
  final bool defaultIsExcludedFromBudget;
  final String initialTransactionId;
  final List<AmortizationEntry> entries;
  final String? counterpartyId;
  final String? note;
  final DateTime? terminatedAt;
  final String? terminationRecognitionTransactionId;
  final String? refundTransactionId;
  final Money? refundAmount;

  AmortizationStatus get status {
    if (terminatedAt != null) return AmortizationStatus.terminated;
    if (entries.every((entry) => entry.isGenerated || entry.isCanceled)) {
      return AmortizationStatus.completed;
    }
    return AmortizationStatus.active;
  }

  AmortizationEntry? get nextPendingEntry => entries
      .where((entry) => !entry.isGenerated && !entry.isCanceled)
      .firstOrNull;

  DateTime get lastRecognitionAt => entries.last.dueAt;

  Money get recognizedAmount => entries
      .where((entry) => entry.isGenerated && !entry.isCanceled)
      .fold(Money.zero(), (sum, entry) => sum + entry.amount);

  Money get remainingAmount =>
      terminatedAt == null ? total - recognizedAmount : Money.zero();

  List<AccountAmountAllocation> get recognitionAllocations =>
      _sumCategoryAllocations(entries);

  List<AccountAmountAllocation> get remainingCategoryAllocations =>
      terminatedAt == null
      ? subtractAllocations(
          base: recognitionAllocations,
          reductions: _sumCategoryAllocations(
            entries.where((entry) => entry.isGenerated && !entry.isCanceled),
          ),
        )
      : const [];

  List<AmortizationEntry> dueEntries(DateTime now) => [
    for (final entry in entries)
      if (!entry.isGenerated &&
          !entry.isCanceled &&
          !_dateOnly(entry.dueAt).isAfter(_dateOnly(now)))
        entry,
  ];

  AmortizationPlan withEntries(Iterable<AmortizationEntry> nextEntries) {
    return _copyWith(entries: nextEntries);
  }

  AmortizationPlan withDefaults({
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
  }) {
    return _copyWith(
      defaultIsExcludedFromStats: isExcludedFromStats,
      defaultIsExcludedFromBudget: isExcludedFromBudget,
    );
  }

  AmortizationPlan terminated({
    required DateTime terminatedAt,
    required Money refundAmount,
    required Iterable<AmortizationEntry> entries,
    String? recognitionTransactionId,
    String? refundTransactionId,
  }) {
    return _copyWith(
      entries: entries,
      terminatedAt: terminatedAt,
      terminationRecognitionTransactionId: recognitionTransactionId,
      refundTransactionId: refundTransactionId,
      refundAmount: refundAmount,
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
    for (final entry in entries) {
      if (entry.categoryAllocations.isEmpty) {
        throw _invalid(
          'entries',
          'Every amortization entry requires category allocations.',
        );
      }
      final accountIds = <String>{};
      for (final allocation in entry.categoryAllocations) {
        if (allocation.amount.minorUnits <= 0 ||
            !accountIds.add(allocation.accountId)) {
          throw _invalid(
            'entries',
            'Entry category allocations must be positive and unique.',
          );
        }
      }
      if (sumAllocations(entry.categoryAllocations) != entry.amount) {
        throw _invalid(
          'entries',
          'Entry category allocations must equal the entry amount.',
        );
      }
    }
    final expected = buildAmortizationSchedule(
      planId: id,
      total: total,
      firstRecognitionAt: firstRecognitionAt,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      recognitionCount: recognitionCount,
    );
    if (entries.length != expected.length) {
      throw _invalid('entries', 'Amortization entry count does not match.');
    }
    final entryTotal = entries.fold(
      Money.zero(),
      (sum, entry) => sum + entry.amount,
    );
    if (entryTotal != total) {
      throw _invalid('entries', 'Amortization entries must equal the total.');
    }
    for (var index = 0; index < entries.length; index++) {
      final actual = entries[index];
      final planned = expected[index];
      if (actual.id != planned.id ||
          actual.planId != id ||
          actual.sequenceNo != index + 1 ||
          actual.dueAt != planned.dueAt ||
          actual.amount != planned.amount ||
          actual.amount.minorUnits <= 0) {
        throw _invalid(
          'entries[$index]',
          'Amortization entry does not match the plan schedule.',
        );
      }
    }
    if (refundAmount != null && refundAmount!.minorUnits < 0) {
      throw _invalid('refundAmount', 'Refund amount cannot be negative.');
    }
    if (terminatedAt == null &&
        (terminationRecognitionTransactionId != null ||
            refundTransactionId != null ||
            refundAmount != null)) {
      throw _invalid(
        'terminatedAt',
        'Termination transaction facts require a termination time.',
      );
    }
  }

  AmortizationPlan _copyWith({
    Iterable<AmortizationEntry>? entries,
    bool? defaultIsExcludedFromStats,
    bool? defaultIsExcludedFromBudget,
    DateTime? terminatedAt,
    String? terminationRecognitionTransactionId,
    String? refundTransactionId,
    Money? refundAmount,
  }) {
    return AmortizationPlan(
      id: id,
      kind: kind,
      deferralAccountId: deferralAccountId,
      total: total,
      cadenceUnit: cadenceUnit,
      cadenceInterval: cadenceInterval,
      firstRecognitionAt: firstRecognitionAt,
      recognitionCount: recognitionCount,
      defaultIsExcludedFromStats:
          defaultIsExcludedFromStats ?? this.defaultIsExcludedFromStats,
      defaultIsExcludedFromBudget:
          defaultIsExcludedFromBudget ?? this.defaultIsExcludedFromBudget,
      initialTransactionId: initialTransactionId,
      entries: entries ?? this.entries,
      counterpartyId: counterpartyId,
      note: note,
      terminatedAt: terminatedAt ?? this.terminatedAt,
      terminationRecognitionTransactionId:
          terminationRecognitionTransactionId ??
          this.terminationRecognitionTransactionId,
      refundTransactionId: refundTransactionId ?? this.refundTransactionId,
      refundAmount: refundAmount ?? this.refundAmount,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static List<AccountAmountAllocation> _sumCategoryAllocations(
    Iterable<AmortizationEntry> entries,
  ) {
    final amounts = <String, int>{};
    final order = <String>[];
    for (final entry in entries) {
      for (final allocation in entry.categoryAllocations) {
        if (!amounts.containsKey(allocation.accountId)) {
          order.add(allocation.accountId);
        }
        amounts[allocation.accountId] =
            (amounts[allocation.accountId] ?? 0) + allocation.amount.minorUnits;
      }
    }
    return [
      for (final accountId in order)
        AccountAmountAllocation(
          accountId: accountId,
          amount: Money(minorUnits: amounts[accountId]!),
        ),
    ];
  }
}

BusinessException _invalid(String field, String message) {
  return BusinessException(
    AmortizationErrorCode.invalidCommand,
    message: '$message ($field)',
  );
}
