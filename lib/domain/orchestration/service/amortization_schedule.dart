import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../ledger/valobj/account_amount_allocation.dart';
import '../entity/amortization_entry.dart';
import '../valobj/amortization_enums.dart';
import '../valobj/amortization_error_code.dart';

List<AmortizationEntry> buildAmortizationSchedule({
  required String planId,
  required Money total,
  required DateTime firstRecognitionAt,
  required AmortizationCadenceUnit cadenceUnit,
  required int cadenceInterval,
  required int recognitionCount,
  List<AccountAmountAllocation> categoryAllocations = const [],
}) {
  if (planId.trim().isEmpty) {
    throw _invalid('planId', 'Plan id is required.');
  }
  if (total.minorUnits <= 0) {
    throw _invalid('total', 'Amortization total must be positive.');
  }
  if (cadenceInterval <= 0) {
    throw _invalid('cadenceInterval', 'Cadence interval must be positive.');
  }
  if (recognitionCount <= 0 || total.minorUnits < recognitionCount) {
    throw _invalid(
      'recognitionCount',
      'Recognition count must be positive and no greater than the total '
          'number of minor units.',
    );
  }
  if (categoryAllocations.isNotEmpty) {
    final categoryIds = <String>{};
    for (final allocation in categoryAllocations) {
      if (allocation.amount.minorUnits <= 0 ||
          !categoryIds.add(allocation.accountId)) {
        throw _invalid(
          'categoryAllocations',
          'Category allocations must be positive and unique.',
        );
      }
    }
    if (sumAllocations(categoryAllocations) != total) {
      throw _invalid(
        'categoryAllocations',
        'Category allocations must equal the amortization total.',
      );
    }
  }

  final baseAmount = total.minorUnits ~/ recognitionCount;
  final remainder = total.minorUnits % recognitionCount;
  var remainingCategories = [...categoryAllocations];
  return [
    for (var index = 0; index < recognitionCount; index++)
      () {
        final amount = Money(
          minorUnits:
              baseAmount + (index == recognitionCount - 1 ? remainder : 0),
        );
        final allocations = remainingCategories.isEmpty
            ? const <AccountAmountAllocation>[]
            : index == recognitionCount - 1
            ? List<AccountAmountAllocation>.unmodifiable(remainingCategories)
            : _allocatePeriod(amount: amount, remaining: remainingCategories);
        remainingCategories = subtractAllocations(
          base: remainingCategories,
          reductions: allocations,
        );
        return AmortizationEntry(
          id: '$planId:${index + 1}',
          planId: planId,
          sequenceNo: index + 1,
          dueAt: addAmortizationInterval(
            firstRecognitionAt,
            cadenceUnit,
            cadenceInterval * index,
          ),
          amount: amount,
          categoryAllocations: allocations,
        );
      }(),
  ];
}

List<AccountAmountAllocation> _allocatePeriod({
  required Money amount,
  required List<AccountAmountAllocation> remaining,
}) {
  final remainingTotal = sumAllocations(remaining).minorUnits;
  if (remainingTotal <= 0) {
    throw _invalid('categoryAllocations', 'Category balance is exhausted.');
  }
  final amounts = <int>[];
  final remainders = <int>[];
  for (final allocation in remaining) {
    final numerator = amount.minorUnits * allocation.amount.minorUnits;
    amounts.add(numerator ~/ remainingTotal);
    remainders.add(numerator % remainingTotal);
  }
  var unallocated = amount.minorUnits - amounts.fold(0, (a, b) => a + b);
  final order = [for (var index = 0; index < remaining.length; index++) index]
    ..sort((left, right) {
      final byRemainder = remainders[right].compareTo(remainders[left]);
      return byRemainder != 0 ? byRemainder : left.compareTo(right);
    });
  for (final index in order) {
    if (unallocated == 0) break;
    amounts[index]++;
    unallocated--;
  }
  if (unallocated != 0) {
    throw _invalid('categoryAllocations', 'Period allocations do not balance.');
  }
  return [
    for (var index = 0; index < remaining.length; index++)
      if (amounts[index] > 0)
        AccountAmountAllocation(
          accountId: remaining[index].accountId,
          amount: Money(minorUnits: amounts[index]),
        ),
  ];
}

DateTime addAmortizationInterval(
  DateTime anchor,
  AmortizationCadenceUnit unit,
  int amount,
) {
  if (amount == 0) return anchor;
  return switch (unit) {
    AmortizationCadenceUnit.daily => DateTime(
      anchor.year,
      anchor.month,
      anchor.day + amount,
      anchor.hour,
      anchor.minute,
      anchor.second,
      anchor.millisecond,
      anchor.microsecond,
    ),
    AmortizationCadenceUnit.monthly => _addMonths(anchor, amount),
    AmortizationCadenceUnit.yearly => _addYears(anchor, amount),
  };
}

DateTime _addMonths(DateTime anchor, int months) {
  final monthIndex = anchor.year * 12 + anchor.month - 1 + months;
  final year = monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final day = _clampedDay(year, month, anchor.day);
  return DateTime(
    year,
    month,
    day,
    anchor.hour,
    anchor.minute,
    anchor.second,
    anchor.millisecond,
    anchor.microsecond,
  );
}

DateTime _addYears(DateTime anchor, int years) {
  final year = anchor.year + years;
  final day = _clampedDay(year, anchor.month, anchor.day);
  return DateTime(
    year,
    anchor.month,
    day,
    anchor.hour,
    anchor.minute,
    anchor.second,
    anchor.millisecond,
    anchor.microsecond,
  );
}

int _clampedDay(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return day > lastDay ? lastDay : day;
}

BusinessException _invalid(String field, String message) {
  return BusinessException(
    AmortizationErrorCode.invalidCommand,
    message: '$message ($field)',
  );
}
