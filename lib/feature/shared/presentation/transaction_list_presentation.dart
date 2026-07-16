import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/widget/business/finance/finance_labels.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

import 'account_lookup.dart';

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
  });

  final String transactionId;
  final String? iconKey;
  final String title;
  final String subtitle;
  final String amountText;
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

class MonthlySummaryPresentation {
  const MonthlySummaryPresentation({required this.metrics});

  final List<MonthlySummaryMetricPresentation> metrics;
}

class MonthlySummaryMetricPresentation {
  const MonthlySummaryMetricPresentation({
    required this.label,
    required this.amountText,
    required this.caption,
    required this.tone,
  });

  final String label;
  final String amountText;
  final String caption;
  final FinanceTone tone;
}

List<TransactionDayGroup> groupTransactionsByDay({
  required List<TransactionListReadModel> items,
  required AccountLookup accountLookup,
  List<DailyCashflowSummary> dailySummaries = const [],
  String? viewAccountId,
}) {
  final groups = <DateTime, List<TransactionRowPresentation>>{};
  for (final item in items) {
    final date = normalizeDate(item.occurredAt);
    groups
        .putIfAbsent(date, () => [])
        .add(
          buildTransactionRowPresentation(
            item: item,
            accountLookup: accountLookup,
            viewAccountId: viewAccountId,
          ),
        );
  }

  final totalsByDate = _dailySummariesByDate(dailySummaries);
  final dates =
      {...groups.keys, ...totalsByDate.keys}.toList()
        ..sort((a, b) => b.compareTo(a));
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
  required AccountLookup accountLookup,
  required List<DailyCashflowSummary> dailySummaries,
  String? viewAccountId,
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
        buildTransactionRowPresentation(
          item: item,
          accountLookup: accountLookup,
          viewAccountId: viewAccountId,
        ),
    ],
    incomeMinor: summary?.income.minorUnits ?? 0,
    expenseMinor: summary?.expense.minorUnits ?? 0,
  );
}

TransactionRowPresentation buildTransactionRowPresentation({
  required TransactionListReadModel item,
  required AccountLookup accountLookup,
  String? viewAccountId,
}) {
  final balanceDelta =
      viewAccountId == null
          ? null
          : accountLookup.balanceDeltaForAccount(
            accountId: viewAccountId,
            entries: item.entries,
          );
  final note = item.note?.trim();
  final hasNote = note != null && note.isNotEmpty;

  return TransactionRowPresentation(
    transactionId: item.id,
    iconKey: resolveCategoryIconKey(item, accountLookup),
    title: transactionPrimaryLabel(item, accountLookup),
    subtitle:
        hasNote
            ? '${formatTime(item.occurredAt)}  $note'
            : formatTime(item.occurredAt),
    amountText:
        balanceDelta == null
            ? formatTransactionAmount(item)
            : formatAccountDelta(balanceDelta),
    amountTone:
        balanceDelta == null
            ? amountTone(item.businessPurpose)
            : FinanceTone.neutral,
    accountFlow: resolveAccountFlow(item, accountLookup),
    badges: buildTransactionBadges(item),
    canQuickEdit: canQuickEditTransaction(item),
  );
}

TransactionAccountFlowPresentation resolveAccountFlow(
  TransactionListReadModel item,
  AccountLookup accountLookup,
) {
  AccountEndpointPresentation? endpointOf(Account? account) {
    if (account == null) return null;
    return AccountEndpointPresentation(
      label: account.name,
      iconKey: account.iconKey,
    );
  }

  final out = endpointOf(flowOutAccount(item, accountLookup));
  final in_ = endpointOf(flowInAccount(item, accountLookup));
  final fallbackText = transactionAccountLabel(item, accountLookup);
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

List<TransactionBadgePresentation> buildTransactionBadges(
  TransactionListReadModel item,
) {
  final badges = <TransactionBadgePresentation>[];

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
  if (item.refundedTotal != null) {
    badges.add(
      TransactionBadgePresentation(
        label: '退 ${formatCompactMoney(item.refundedTotal!)}',
        tone: FinanceTone.income,
      ),
    );
  }
  if (item.reimbursementReceivedTotal != null) {
    badges.add(
      TransactionBadgePresentation(
        label: '报 ${formatCompactMoney(item.reimbursementReceivedTotal!)}',
        tone: FinanceTone.info,
      ),
    );
  }

  void addDetailBadge(
    TransactionDetailType type,
    String label,
    FinanceTone tone,
  ) {
    final amount = detailAmount(item, type);
    if (amount == null) return;
    badges.add(
      TransactionBadgePresentation(
        label: '$label ${formatCompactMoney(amount)}',
        tone: tone,
      ),
    );
  }

  addDetailBadge(
    TransactionDetailType.repaymentInterest,
    '利',
    FinanceTone.expense,
  );
  addDetailBadge(TransactionDetailType.repaymentFee, '费', FinanceTone.expense);
  addDetailBadge(
    TransactionDetailType.repaymentDiscount,
    '优',
    FinanceTone.income,
  );

  if (item.reimbursementGapIncome != null) {
    badges.add(
      TransactionBadgePresentation(
        label: '差收 ${formatCompactMoney(item.reimbursementGapIncome!)}',
        tone: FinanceTone.income,
      ),
    );
  }
  if (item.reimbursementGapExpense != null) {
    badges.add(
      TransactionBadgePresentation(
        label: '差支 ${formatCompactMoney(item.reimbursementGapExpense!)}',
        tone: FinanceTone.expense,
      ),
    );
  }

  return badges;
}

MonthlySummaryPresentation buildMonthlySummaryPresentation(
  CashflowComparison comparison, {
  int monthlyBudgetMinor = 1000000,
}) {
  final summary = comparison.current;
  final incomeMinor = summary.income.minorUnits;
  final expenseMinor = summary.expense.minorUnits;
  return MonthlySummaryPresentation(
    metrics: [
      MonthlySummaryMetricPresentation(
        label: '本月收入',
        amountText: formatMonthlyAmount(incomeMinor, showSign: true),
        caption: formatPeriodChangeMetrics(comparison.incomeChange),
        tone: FinanceTone.income,
      ),
      MonthlySummaryMetricPresentation(
        label: '本月支出',
        amountText: formatMonthlyAmount(expenseMinor, showSign: false),
        caption: formatPeriodChangeMetrics(comparison.expenseChange),
        tone: FinanceTone.expense,
      ),
      MonthlySummaryMetricPresentation(
        label: '本月预算',
        amountText: formatMonthlyAmount(monthlyBudgetMinor, showSign: false),
        caption:
            '${formatPercent(expenseMinor / monthlyBudgetMinor)}/'
            '${formatRoundedMajor(monthlyBudgetMinor)}',
        tone: FinanceTone.primary,
      ),
    ],
  );
}

Account? categoryAccount(
  TransactionListReadModel item,
  AccountLookup accountLookup,
) {
  Account? byType(AccountType accountType) {
    final entry = accountLookup.firstEntryByType(
      item.entries,
      accountType: accountType,
    );
    return entry == null ? null : accountLookup.accountOf(entry);
  }

  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.refund => byType(AccountType.expense),
    BusinessPurpose.dailyIncome => byType(AccountType.income),
    BusinessPurpose.reimbursementAdvance =>
      item.reimbursementExpenseAccountId == null
          ? null
          : accountLookup.find(item.reimbursementExpenseAccountId!),
    _ => null,
  };
}

Account? flowOutAccount(
  TransactionListReadModel item,
  AccountLookup accountLookup,
) {
  final entry = accountLookup.firstSettlementEntry(
    item.entries,
    direction: EntryDirection.credit,
  );
  return entry == null ? null : accountLookup.accountOf(entry);
}

Account? flowInAccount(
  TransactionListReadModel item,
  AccountLookup accountLookup,
) {
  final entry = accountLookup.firstSettlementEntry(
    item.entries,
    direction: EntryDirection.debit,
  );
  return entry == null ? null : accountLookup.accountOf(entry);
}

String? resolveCategoryIconKey(
  TransactionListReadModel item,
  AccountLookup accountLookup,
) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose
        .reimbursementAdvance => categoryAccount(item, accountLookup)?.iconKey,
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

String transactionPrimaryLabel(
  TransactionListReadModel item,
  AccountLookup accountLookup,
) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.dailyIncome =>
      _cleanText(categoryAccount(item, accountLookup)?.name) ??
          transactionPurposeLabel(item.businessPurpose),
    BusinessPurpose.reimbursementAdvance =>
      _cleanText(categoryAccount(item, accountLookup)?.name) ?? '支出',
    _ => transactionPurposeLabel(item.businessPurpose),
  };
}

String transactionAccountLabel(
  TransactionListReadModel item,
  AccountLookup accountLookup,
) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.reimbursementAdvance =>
      _cleanText(flowOutAccount(item, accountLookup)?.name) ?? '',
    BusinessPurpose.dailyIncome =>
      _cleanText(flowInAccount(item, accountLookup)?.name) ?? '',
    _ => _flowAccountLabel(item, accountLookup),
  };
}

String _flowAccountLabel(
  TransactionListReadModel item,
  AccountLookup accountLookup,
) {
  final out = _cleanText(flowOutAccount(item, accountLookup)?.name);
  final in_ = _cleanText(flowInAccount(item, accountLookup)?.name);
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

String formatTransactionAmount(TransactionListReadModel item) {
  final prefix = switch (item.businessPurpose) {
    BusinessPurpose.dailyIncome => '+',
    BusinessPurpose.dailyExpense => '-',
    _ => '',
  };
  return '$prefix${formatMinorAmount(item.primaryAmount.minorUnits)}';
}

String formatAccountDelta(Money delta) {
  final sign = delta.minorUnits >= 0 ? '+' : '-';
  return '$sign${formatMinorAmount(delta.minorUnits)}';
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

Money? detailAmount(TransactionListReadModel item, TransactionDetailType type) {
  for (final line in item.details) {
    if (line.type == type && line.amount.minorUnits > 0) {
      return line.amount;
    }
  }
  return null;
}

String formatMinorAmount(int minorUnits) {
  return Money(minorUnits: minorUnits.abs()).format();
}

String formatMonthlyAmount(int minorUnits, {required bool showSign}) {
  final formatted = Money(minorUnits: minorUnits.abs()).format();
  if (!showSign) return formatted;
  return minorUnits >= 0 ? formatted : '-$formatted';
}

String formatCompactMoney(Money money) {
  final formatted = Money(minorUnits: money.minorUnits.abs()).format();
  final compact = formatted.replaceFirst(RegExp(r'\.?0+$'), '');
  return compact.isEmpty ? '0' : compact;
}

String formatPeriodChangeMetrics(PeriodChange change) {
  return [
    formatSignedCompactAmount(change.delta.minorUnits),
    formatOptionalPercent(change.ratio),
    formatOptionalPercent(change.fullPeriodRatio),
  ].join('/');
}

String formatSignedCompactAmount(int minorUnits) {
  final sign = minorUnits >= 0 ? '+' : '-';
  return '$sign${formatRoundedMajor(minorUnits)}';
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
