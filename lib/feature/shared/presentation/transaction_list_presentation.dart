import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/money_formatter.dart';
import 'package:smartflow/widget/business/finance/finance_labels.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

const _noAccountLabel = '无账户';

class TransactionDayGroup {
  const TransactionDayGroup({
    required this.date,
    required this.rows,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime date;
  final List<TransactionRowPresentation> rows;
  final int incomeMinor;
  final int expenseMinor;
}

class TransactionRowPresentation {
  const TransactionRowPresentation({
    required this.transactionId,
    required this.iconKey,
    required this.title,
    required this.subtitle,
    required this.amountText,
    required this.amountTone,
    required this.accountFlow,
    required this.badges,
    required this.canQuickEdit,
    this.compactAmountText,
    this.originalAmountText,
    this.originalCompactAmountText,
  });

  final String transactionId;
  final String? iconKey;
  final String title;
  final String subtitle;
  final String amountText;
  final String? compactAmountText;
  final String? originalAmountText;
  final String? originalCompactAmountText;
  final FinanceTone amountTone;
  final TransactionAccountFlowPresentation accountFlow;
  final List<TransactionBadgePresentation> badges;
  final bool canQuickEdit;

  bool get hasBadges => badges.isNotEmpty;
}

class TransactionAccountFlowPresentation {
  const TransactionAccountFlowPresentation({
    this.out,
    this.in_,
    this.separator = '->',
    this.fallbackLabel = _noAccountLabel,
  });

  final AccountEndpointPresentation? out;
  final AccountEndpointPresentation? in_;
  final String separator;
  final String fallbackLabel;

  AccountEndpointPresentation get singleEndpoint =>
      out ?? in_ ?? AccountEndpointPresentation(label: fallbackLabel);
}

class AccountEndpointPresentation {
  const AccountEndpointPresentation({required this.label, this.iconKey});

  final String label;
  final String? iconKey;
}

class TransactionBadgePresentation {
  const TransactionBadgePresentation({required this.label, required this.tone});

  final String label;
  final FinanceTone tone;
}

class CashflowSummaryPresentation {
  const CashflowSummaryPresentation({required this.metrics});

  final List<CashflowSummaryMetricPresentation> metrics;
}

class CashflowSummaryMetricPresentation {
  const CashflowSummaryMetricPresentation({
    required this.label,
    required this.amount,
    required this.caption,
    required this.tone,
  });

  final String label;
  final Money amount;
  final String caption;
  final FinanceTone tone;
}

List<TransactionDayGroup> groupTransactionsByDay({
  required List<TransactionListReadModel> items,
  List<DailyCashflowSummary> dailySummaries = const [],
  Account? viewAccount,
}) {
  final groups = <DateTime, List<TransactionRowPresentation>>{};
  for (final item in items) {
    final date = normalizeDate(item.occurredAt);
    groups
        .putIfAbsent(date, () => [])
        .add(
          buildTransactionRowPresentation(item: item, viewAccount: viewAccount),
        );
  }

  final totalsByDate = _dailySummariesByDate(dailySummaries);
  final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final date in dates)
      TransactionDayGroup(
        date: date,
        rows: groups[date] ?? const [],
        incomeMinor: totalsByDate[date]?.income.minorUnits ?? 0,
        expenseMinor: totalsByDate[date]?.expense.minorUnits ?? 0,
      ),
  ];
}

TransactionDayGroup transactionGroupForDate({
  required DateTime date,
  required List<TransactionListReadModel> transactions,
  required List<DailyCashflowSummary> dailySummaries,
  Account? viewAccount,
}) {
  final normalized = normalizeDate(date);
  final items = [
    for (final item in transactions)
      if (isSameDate(item.occurredAt, normalized)) item,
  ];
  final summary = _dailySummariesByDate(dailySummaries)[normalized];
  return TransactionDayGroup(
    date: normalized,
    rows: [
      for (final item in items)
        buildTransactionRowPresentation(item: item, viewAccount: viewAccount),
    ],
    incomeMinor: summary?.income.minorUnits ?? 0,
    expenseMinor: summary?.expense.minorUnits ?? 0,
  );
}

TransactionRowPresentation buildTransactionRowPresentation({
  required TransactionListReadModel item,
  Account? viewAccount,
}) {
  final balanceDelta =
      viewAccount == null
          ? null
          : settlementBalanceDelta(item: item, viewAccount: viewAccount);
  final comparison =
      balanceDelta == null ? transactionAmountComparison(item) : null;
  return TransactionRowPresentation(
    transactionId: item.id,
    iconKey: resolveCategoryIconKey(item),
    title: transactionPrimaryLabel(item),
    subtitle: formatTime(item.occurredAt),
    amountText:
        balanceDelta == null
            ? formatTransactionAmount(
              item,
              amount: comparison?.actual,
              style: MoneyFormatStyle.plain,
            )
            : formatAccountDelta(balanceDelta, style: MoneyFormatStyle.plain),
    compactAmountText:
        balanceDelta == null
            ? formatTransactionAmount(
              item,
              amount: comparison?.actual,
              style: MoneyFormatStyle.compact,
            )
            : formatAccountDelta(balanceDelta, style: MoneyFormatStyle.compact),
    originalAmountText:
        comparison == null
            ? null
            : formatTransactionAmount(
              item,
              amount: comparison.original,
              style: MoneyFormatStyle.plain,
            ),
    originalCompactAmountText:
        comparison == null
            ? null
            : formatTransactionAmount(
              item,
              amount: comparison.original,
              style: MoneyFormatStyle.compact,
            ),
    amountTone:
        balanceDelta == null
            ? amountTone(item.businessPurpose)
            : FinanceTone.neutral,
    accountFlow: resolveAccountFlow(item),
    badges: buildTransactionBadges(item),
    canQuickEdit: canQuickEditTransaction(item),
  );
}

TransactionSettlementEntryRef? firstSettlementEntry(
  TransactionListReadModel item, {
  required EntryDirection direction,
}) {
  for (final entry in item.settlementEntries) {
    if (entry.direction == direction) return entry;
  }
  return null;
}

TransactionAccountFlowPresentation resolveAccountFlow(
  TransactionListReadModel item,
) {
  AccountEndpointPresentation? endpointOf(TransactionSettlementEntryRef? ref) {
    if (ref == null) return null;
    return AccountEndpointPresentation(
      label: ref.accountName,
      iconKey: ref.accountIconKey,
    );
  }

  final out = endpointOf(
    firstSettlementEntry(item, direction: EntryDirection.credit),
  );
  final in_ = endpointOf(
    firstSettlementEntry(item, direction: EntryDirection.debit),
  );
  final fallbackText = transactionAccountLabel(item);
  final fallbackLabel = fallbackText.isEmpty ? _noAccountLabel : fallbackText;

  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense => TransactionAccountFlowPresentation(
      out: out,
      fallbackLabel: fallbackLabel,
    ),
    BusinessPurpose.reimbursementAdvance => TransactionAccountFlowPresentation(
      out: in_,
      in_: out,
      separator: '|',
      fallbackLabel: fallbackLabel,
    ),
    BusinessPurpose.dailyIncome => TransactionAccountFlowPresentation(
      in_: in_,
      fallbackLabel: fallbackLabel,
    ),
    _ => TransactionAccountFlowPresentation(
      out: out,
      in_: in_,
      fallbackLabel: fallbackLabel,
    ),
  };
}

/// 调整摘要的展示顺序与语义色固定由 kind 决定，金额恒为正。
List<TransactionBadgePresentation> buildTransactionBadges(
  TransactionListReadModel item,
) {
  final badges = <TransactionBadgePresentation>[
    for (final adjustment in item.adjustments)
      TransactionBadgePresentation(
        label:
            '${_adjustmentLabel(adjustment.kind)} '
            '${formatCompactMoney(adjustment.amount)}',
        tone: _adjustmentTone(adjustment.kind),
      ),
  ];

  if (item.isExcludedFromStats) {
    badges.add(
      const TransactionBadgePresentation(
        label: '不计统计',
        tone: FinanceTone.equity,
      ),
    );
  }
  if (item.isExcludedFromBudget) {
    badges.add(
      const TransactionBadgePresentation(
        label: '不计预算',
        tone: FinanceTone.equity,
      ),
    );
  }

  return badges;
}

String _adjustmentLabel(TransactionAdjustmentKind kind) {
  return switch (kind) {
    TransactionAdjustmentKind.refund => '退',
    TransactionAdjustmentKind.reimbursementReceived => '报',
    TransactionAdjustmentKind.repaymentInterest => '利',
    TransactionAdjustmentKind.repaymentFee => '费',
    TransactionAdjustmentKind.repaymentDiscount => '优',
    TransactionAdjustmentKind.reimbursementGapIncome => '差收',
    TransactionAdjustmentKind.reimbursementGapExpense => '差支',
  };
}

FinanceTone _adjustmentTone(TransactionAdjustmentKind kind) {
  return switch (kind) {
    TransactionAdjustmentKind.refund ||
    TransactionAdjustmentKind.repaymentDiscount ||
    TransactionAdjustmentKind.reimbursementGapIncome => FinanceTone.income,
    TransactionAdjustmentKind.reimbursementReceived => FinanceTone.info,
    TransactionAdjustmentKind.repaymentInterest ||
    TransactionAdjustmentKind.repaymentFee ||
    TransactionAdjustmentKind.reimbursementGapExpense => FinanceTone.expense,
  };
}

CashflowSummaryPresentation buildMonthlySummaryPresentation(
  CashflowComparison comparison, {
  int monthlyBudgetMinor = 1000000,
}) {
  final summary = comparison.current;
  final expenseMinor = summary.expense.minorUnits;
  return CashflowSummaryPresentation(
    metrics: [
      CashflowSummaryMetricPresentation(
        label: '本月收入',
        amount: summary.income,
        caption: formatPeriodChangeMetrics(comparison.incomeChange),
        tone: FinanceTone.income,
      ),
      CashflowSummaryMetricPresentation(
        label: '本月支出',
        amount: summary.expense,
        caption: formatPeriodChangeMetrics(comparison.expenseChange),
        tone: FinanceTone.expense,
      ),
      CashflowSummaryMetricPresentation(
        label: '本月预算',
        amount: Money(minorUnits: monthlyBudgetMinor),
        caption:
            '${formatPercent(expenseMinor / monthlyBudgetMinor)}/'
            '${formatRoundedMajor(monthlyBudgetMinor)}',
        tone: FinanceTone.primary,
      ),
    ],
  );
}

String? resolveCategoryIconKey(TransactionListReadModel item) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.reimbursementAdvance => item.category?.iconKey,
    BusinessPurpose.transfer => 'transfer',
    BusinessPurpose.debtRepayment => 'loan',
    BusinessPurpose.borrowing => 'hand-coin-line',
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment => 'wallet-line',
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose => null,
  };
}

String transactionPrimaryLabel(TransactionListReadModel item) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.dailyIncome =>
      _cleanText(item.category?.name) ??
          transactionPurposeLabel(item.businessPurpose),
    BusinessPurpose.reimbursementAdvance =>
      _cleanText(item.category?.name) ?? '支出',
    _ => transactionPurposeLabel(item.businessPurpose),
  };
}

String transactionAccountLabel(TransactionListReadModel item) {
  String? nameOf(EntryDirection direction) =>
      _cleanText(firstSettlementEntry(item, direction: direction)?.accountName);

  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.reimbursementAdvance => nameOf(EntryDirection.credit) ?? '',
    BusinessPurpose.dailyIncome => nameOf(EntryDirection.debit) ?? '',
    _ => _flowAccountLabel(item),
  };
}

String _flowAccountLabel(TransactionListReadModel item) {
  final out = _cleanText(
    firstSettlementEntry(item, direction: EntryDirection.credit)?.accountName,
  );
  final in_ = _cleanText(
    firstSettlementEntry(item, direction: EntryDirection.debit)?.accountName,
  );
  if (out != null && in_ != null) {
    return '$out -> $in_';
  }
  return out ?? in_ ?? '';
}

FinanceTone amountTone(BusinessPurpose purpose) {
  return switch (purpose) {
    BusinessPurpose.dailyIncome => FinanceTone.income,
    BusinessPurpose.dailyExpense => FinanceTone.expense,
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt => FinanceTone.income,
    BusinessPurpose.transfer ||
    BusinessPurpose.reimbursementAdvance ||
    BusinessPurpose.debtRepayment ||
    BusinessPurpose.borrowing ||
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment ||
    BusinessPurpose.reimbursementClose => FinanceTone.neutral,
  };
}

String formatTransactionAmount(
  TransactionListReadModel item, {
  Money? amount,
  MoneyFormatStyle style = MoneyFormatStyle.plain,
}) {
  final prefix = switch (item.businessPurpose) {
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt => '+',
    BusinessPurpose.dailyExpense => '-',
    _ => '',
  };
  final formatted = formatMoney(
    (amount ?? item.primaryAmount).abs(),
    style: style,
  );
  return '$prefix$formatted';
}

({Money original, Money actual})? transactionAmountComparison(
  TransactionListReadModel item,
) {
  final refunded = adjustmentAmount(item, TransactionAdjustmentKind.refund);
  if (refunded != null) {
    final actualMinor = item.primaryAmount.minorUnits - refunded.minorUnits;
    if (actualMinor >= 0) {
      return (
        original: item.primaryAmount,
        actual: Money(minorUnits: actualMinor),
      );
    }
  }

  final discount = adjustmentAmount(
    item,
    TransactionAdjustmentKind.repaymentDiscount,
  );
  if (discount != null) {
    return (
      original: Money(
        minorUnits: item.primaryAmount.minorUnits + discount.minorUnits,
      ),
      actual: item.primaryAmount,
    );
  }
  return null;
}

/// 从当前账户视角计算该交易带来的余额变动（±delta）。
/// 与 `balance_expressions.dart` 的 SQL 公式一致：asset 借增贷减，liability 贷增借减。
Money? settlementBalanceDelta({
  required TransactionListReadModel item,
  required Account viewAccount,
}) {
  var deltaMinor = 0;
  var matched = false;
  for (final entry in item.settlementEntries) {
    if (entry.accountId != viewAccount.id) continue;
    matched = true;
    final increasesOnDebit = viewAccount.type == AccountType.asset;
    final isPositive =
        increasesOnDebit == (entry.direction == EntryDirection.debit);
    deltaMinor +=
        isPositive ? entry.amount.minorUnits : -entry.amount.minorUnits;
  }
  if (!matched) return null;
  return Money(minorUnits: deltaMinor);
}

String formatAccountDelta(
  Money delta, {
  MoneyFormatStyle style = MoneyFormatStyle.plain,
}) {
  final sign = delta.minorUnits >= 0 ? '+' : '-';
  final amount = formatMoney(delta.abs(), style: style);
  return '$sign$amount';
}

bool canQuickEditTransaction(TransactionListReadModel item) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.reimbursementAdvance ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.transfer ||
    BusinessPurpose.borrowing => true,
    BusinessPurpose.debtRepayment ||
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment ||
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose => false,
  };
}

Money? adjustmentAmount(
  TransactionListReadModel item,
  TransactionAdjustmentKind kind,
) {
  for (final adjustment in item.adjustments) {
    if (adjustment.kind == kind) return adjustment.amount;
  }
  return null;
}

String formatCompactMoney(Money money) {
  return formatMoney(money.abs(), style: MoneyFormatStyle.compact);
}

String formatPeriodChangeMetrics(PeriodChange change) {
  return [
    formatSignedCompactAmount(change.delta.minorUnits),
    formatOptionalPercent(change.ratio),
    formatOptionalPercent(change.fullPeriodRatio),
  ].join('/');
}

String formatSignedCompactAmount(int minorUnits) {
  final formatted = formatMoney(
    Money(minorUnits: minorUnits),
    style: MoneyFormatStyle.compact,
  );
  return minorUnits > 0 ? '+$formatted' : formatted;
}

String formatOptionalPercent(double? ratio) {
  if (ratio == null) {
    return '--%';
  }
  return formatPercent(ratio);
}

String formatPercent(double ratio) {
  return '${(ratio * 100).round()}%';
}

String formatRoundedMajor(int minorUnits) {
  return (minorUnits.abs() / 100).round().toString();
}

String formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String weekdayLabel(DateTime value) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[value.weekday - 1];
}

DateTime normalizeDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

Map<DateTime, DailyCashflowSummary> _dailySummariesByDate(
  List<DailyCashflowSummary> summaries,
) {
  return {
    for (final summary in summaries) normalizeDate(summary.date): summary,
  };
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
