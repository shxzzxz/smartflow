import '../../entity/bill.dart';
import '../../entity/credit_liability_account.dart';
import '../../entity/installment_contract.dart';
import '../../entity/installment_schedule.dart';
import '../../valobj/bill_enums.dart';
import '../../valobj/bill_period.dart';
import '../../valobj/bill_window.dart';
import '../../valobj/credit_account_enums.dart';
import '../../valobj/installment_enums.dart';

const billGenerationStrategies =
    <CreditLiabilityAccountKind, BillGenerationStrategy>{
      CreditLiabilityAccountKind.credit: CreditAccountBillGenerationStrategy(),
      CreditLiabilityAccountKind.loan: LoanAccountBillGenerationStrategy(),
    };

/// Account-specific period and source rules. Persistence and settlement remain
/// in the generation module, shared by scheduled and explicit operations.
abstract interface class BillGenerationStrategy {
  BillPeriod currentPeriod(
    CreditLiabilityAccount account,
    DateTime now,
    Iterable<Bill> bills,
  );

  BillGenerationSources sources({
    required CreditLiabilityAccount account,
    required Bill bill,
    required DateTime now,
    required BillPeriod currentPeriod,
    required Iterable<Bill> bills,
    required Iterable<InstallmentContract> contracts,
  });
}

class ConsumptionBillSource {
  const ConsumptionBillSource({
    required this.window,
    required this.repaymentDate,
    required this.billingState,
    required this.legacyWindow,
  });

  final ConsumptionWindow window;
  final DateTime repaymentDate;
  final BillItemBillingState billingState;
  final BillWindow legacyWindow;
}

typedef InstallmentBillSource = ({
  InstallmentContract contract,
  InstallmentSchedule schedule,
});

class BillGenerationSources {
  const BillGenerationSources({this.consumption, required this.installments});

  final ConsumptionBillSource? consumption;
  final List<InstallmentBillSource> installments;
}

class CreditAccountBillGenerationStrategy implements BillGenerationStrategy {
  const CreditAccountBillGenerationStrategy();

  @override
  BillPeriod currentPeriod(
    CreditLiabilityAccount account,
    DateTime now,
    Iterable<Bill> bills,
  ) {
    final today = _dateOnly(now);
    final nominal = account.creditPeriodForDate(today);
    final nominalBill = bills
        .where((bill) => bill.period == nominal)
        .firstOrNull;
    final nominalItem = _consumption(nominalBill);
    final nominalStart = nominalItem?.startInclusive;
    final nominalEnd = nominalItem?.endInclusive;
    if (nominalStart != null &&
        nominalEnd != null &&
        !today.isBefore(nominalStart) &&
        !today.isAfter(nominalEnd)) {
      return nominal;
    }
    final coveringPeriods = <BillPeriod>[];
    for (final bill in bills) {
      final item = _consumption(bill);
      final start = item?.startInclusive;
      final end = item?.endInclusive;
      if (bill.period.compareTo(BillPeriod.fromDate(today).next()) <= 0 &&
          start != null &&
          end != null &&
          !today.isBefore(start) &&
          !today.isAfter(end)) {
        coveringPeriods.add(bill.period);
      }
    }
    // A retained current window remains authoritative when cycle parameters
    // change, even if its end no longer matches the account's billing day.
    coveringPeriods.sort();
    return coveringPeriods.lastOrNull ?? nominal;
  }

  @override
  BillGenerationSources sources({
    required CreditLiabilityAccount account,
    required Bill bill,
    required DateTime now,
    required BillPeriod currentPeriod,
    required Iterable<Bill> bills,
    required Iterable<InstallmentContract> contracts,
  }) {
    final existing = _consumption(bill);
    final window = _window(account, bill, existing, bills);
    final repaymentDate =
        existing != null && bill.period.compareTo(currentPeriod) <= 0
        ? existing.repaymentDate
        : account.repaymentDateForCreditPeriod(bill.period);
    final billingState =
        existing?.billingState == BillItemBillingState.billed ||
            _dateOnly(now).isAfter(window.endInclusive)
        ? BillItemBillingState.billed
        : BillItemBillingState.open;
    final billingDate = account.billingDayToNext
        ? window.endInclusive.add(const Duration(days: 1))
        : window.endInclusive;
    final startDate = account.billingDayToNext
        ? window.startInclusive
        : window.startInclusive.subtract(const Duration(days: 1));
    return BillGenerationSources(
      consumption: ConsumptionBillSource(
        window: window,
        repaymentDate: repaymentDate,
        billingState: billingState,
        legacyWindow: BillWindow(
          period: bill.period,
          startDate: startDate,
          billingDate: billingDate,
          repaymentDate: repaymentDate,
        ),
      ),
      installments: _installmentsForPeriod(contracts, bill.period),
    );
  }

  ConsumptionWindow _window(
    CreditLiabilityAccount account,
    Bill bill,
    BillItem? existing,
    Iterable<Bill> bills,
  ) {
    final start = existing?.startInclusive;
    final end = existing?.endInclusive;
    if (start != null && end != null) {
      return ConsumptionWindow(startInclusive: start, endInclusive: end);
    }
    final fallback = account.consumptionWindowForPeriod(bill.period);
    final previous = bills
        .where((other) => other.period == bill.period.previous())
        .firstOrNull;
    final next = bills
        .where((other) => other.period == bill.period.next())
        .firstOrNull;
    final previousEnd = _consumption(previous)?.endInclusive;
    final nextStart = _consumption(next)?.startInclusive;
    final calculatedStart =
        previousEnd?.add(const Duration(days: 1)) ?? fallback.startInclusive;
    final calculatedEnd =
        nextStart?.subtract(const Duration(days: 1)) ?? fallback.endInclusive;
    if (calculatedStart.isAfter(calculatedEnd)) return fallback;
    return ConsumptionWindow(
      startInclusive: calculatedStart,
      endInclusive: calculatedEnd,
    );
  }
}

class LoanAccountBillGenerationStrategy implements BillGenerationStrategy {
  const LoanAccountBillGenerationStrategy();

  @override
  BillPeriod currentPeriod(
    CreditLiabilityAccount account,
    DateTime now,
    Iterable<Bill> bills,
  ) => BillPeriod.fromDate(now);

  @override
  BillGenerationSources sources({
    required CreditLiabilityAccount account,
    required Bill bill,
    required DateTime now,
    required BillPeriod currentPeriod,
    required Iterable<Bill> bills,
    required Iterable<InstallmentContract> contracts,
  }) => BillGenerationSources(
    installments: _installmentsForPeriod(contracts, bill.period),
  );
}

bool hasBillObligation(InstallmentSchedule schedule) =>
    schedule.status != InstallmentScheduleStatus.skipped &&
    (schedule.expectedPrincipal.minorUnits != 0 ||
        schedule.expectedInterest.minorUnits != 0 ||
        schedule.expectedFee.minorUnits != 0);

List<InstallmentBillSource> _installmentsForPeriod(
  Iterable<InstallmentContract> contracts,
  BillPeriod period,
) => [
  for (final contract in contracts)
    for (final schedule in contract.schedules)
      if (hasBillObligation(schedule) &&
          BillPeriod.fromDate(schedule.expectedRepaymentDate) == period)
        (contract: contract, schedule: schedule),
];

BillItem? _consumption(Bill? bill) => bill?.items
    .where((item) => item.itemType == BillItemType.consumption)
    .firstOrNull;

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
