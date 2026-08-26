import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/money_formatter.dart';
import 'package:smartflow/widget/business/finance/finance_labels.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

import 'account_lookup.dart';

const _noAccountLabel = '无账户';

sealed class TransactionListAmountSource {
  const TransactionListAmountSource();
}

final class TransactionGroupAmountSource extends TransactionListAmountSource {
  const TransactionGroupAmountSource();
}

final class TransactionAccountImpactAmountSource
    extends TransactionListAmountSource {
  const TransactionAccountImpactAmountSource(this.accountId);

  final String accountId;
}

final class TransactionCategoryImpactAmountSource
    extends TransactionListAmountSource {
  const TransactionCategoryImpactAmountSource(this.accountIds);

  final Set<String> accountIds;
}

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

  TransactionDayGroup copyWith({
    DateTime? date,
    List<TransactionRowPresentation>? rows,
    int? incomeMinor,
    int? expenseMinor,
  }) {
    return TransactionDayGroup(
      date: date ?? this.date,
      rows: rows ?? this.rows,
      incomeMinor: incomeMinor ?? this.incomeMinor,
      expenseMinor: expenseMinor ?? this.expenseMinor,
    );
  }
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
    this.selectable = false,
    this.selected = false,
    this.dimmed = false,
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
  final bool selectable;
  final bool selected;

  /// 行不会参与导入/展示时置灰，保持可交互。
  final bool dimmed;

  bool get hasBadges => badges.isNotEmpty;

  TransactionRowPresentation copyWith({
    bool? selectable,
    bool? selected,
    bool? dimmed,
  }) {
    return TransactionRowPresentation(
      transactionId: transactionId,
      iconKey: iconKey,
      title: title,
      subtitle: subtitle,
      amountText: amountText,
      compactAmountText: compactAmountText,
      originalAmountText: originalAmountText,
      originalCompactAmountText: originalCompactAmountText,
      amountTone: amountTone,
      accountFlow: accountFlow,
      badges: badges,
      canQuickEdit: canQuickEdit,
      selectable: selectable ?? this.selectable,
      selected: selected ?? this.selected,
      dimmed: dimmed ?? this.dimmed,
    );
  }
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

enum TransactionAdjustmentKind {
  transferFee,
  refund,
  reimbursementReceived,
  receivableCollectionPrincipal,
  receivableCollectionInterest,
  repaymentInterest,
  repaymentFee,
  repaymentDiscount,
  reimbursementGapIncome,
  reimbursementGapExpense,
}

class TransactionAdjustment {
  const TransactionAdjustment({required this.kind, required this.amount});

  final TransactionAdjustmentKind kind;
  final Money amount;
}

class CashflowSummaryPresentation {
  const CashflowSummaryPresentation({required this.metrics});

  final List<CashflowSummaryMetricPresentation> metrics;
}

enum CashflowSummaryMetricKind { income, expense, budget }

class CashflowSummaryMetricPresentation {
  const CashflowSummaryMetricPresentation({
    required this.label,
    required this.amount,
    required this.caption,
    required this.tone,
    this.kind,
  });

  final String label;
  final Money amount;
  final String caption;
  final FinanceTone tone;
  final CashflowSummaryMetricKind? kind;
}

List<TransactionDayGroup> groupTransactionsByDay({
  required List<TransactionReadModel> items,
  required AccountLookup accountLookup,
  List<DailyCashflowSummary> dailySummaries = const [],
  TransactionListAmountSource amountSource =
      const TransactionGroupAmountSource(),
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
            amountSource: amountSource,
          ),
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
  required List<TransactionReadModel> transactions,
  required List<DailyCashflowSummary> dailySummaries,
  required AccountLookup accountLookup,
  TransactionListAmountSource amountSource =
      const TransactionGroupAmountSource(),
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
          amountSource: amountSource,
        ),
    ],
    incomeMinor: summary?.income.minorUnits ?? 0,
    expenseMinor: summary?.expense.minorUnits ?? 0,
  );
}

TransactionRowPresentation buildTransactionRowPresentation({
  required TransactionReadModel item,
  required AccountLookup accountLookup,
  TransactionListAmountSource amountSource =
      const TransactionGroupAmountSource(),
}) {
  final accountDelta = switch (amountSource) {
    TransactionAccountImpactAmountSource(:final accountId) =>
      item.impactsByAccountId[accountId]?.netChange ?? Money.zero(),
    _ => null,
  };
  final categoryAmount = switch (amountSource) {
    TransactionCategoryImpactAmountSource(:final accountIds) => Money(
      minorUnits: accountIds.fold(
        0,
        (sum, id) =>
            sum + (item.impactsByAccountId[id]?.netChange.minorUnits ?? 0),
      ),
    ),
    _ => null,
  };
  final comparison = amountSource is TransactionGroupAmountSource
      ? transactionAmountComparison(item)
      : null;
  final transactionAmount = categoryAmount ?? comparison?.actual;
  return TransactionRowPresentation(
    transactionId: item.id,
    iconKey: resolveCategoryIconKey(item, accountLookup),
    title: transactionPrimaryLabel(item, accountLookup),
    subtitle: formatTime(item.occurredAt),
    amountText: accountDelta == null
        ? formatTransactionAmount(
            item,
            amount: transactionAmount,
            style: MoneyFormatStyle.plain,
          )
        : formatAccountDelta(accountDelta, style: MoneyFormatStyle.plain),
    compactAmountText: accountDelta == null
        ? formatTransactionAmount(
            item,
            amount: transactionAmount,
            style: MoneyFormatStyle.compact,
          )
        : formatAccountDelta(accountDelta, style: MoneyFormatStyle.compact),
    originalAmountText: comparison == null
        ? null
        : formatTransactionAmount(
            item,
            amount: comparison.original,
            style: MoneyFormatStyle.plain,
          ),
    originalCompactAmountText: comparison == null
        ? null
        : formatTransactionAmount(
            item,
            amount: comparison.original,
            style: MoneyFormatStyle.compact,
          ),
    amountTone: accountDelta == null
        ? amountTone(item.businessPurpose)
        : FinanceTone.neutral,
    accountFlow: resolveAccountFlow(item, accountLookup),
    badges: buildTransactionBadges(item),
    canQuickEdit: canQuickEditTransaction(item),
  );
}

String? _flowAccountId(
  TransactionReadModel item, {
  required EntryDirection direction,
}) {
  final role = direction == EntryDirection.debit
      ? TransactionRole.settlementIn
      : TransactionRole.settlementOut;
  final accountId = item.accountOf(role);
  if (accountId != null) return accountId;
  return switch (item.businessPurpose) {
    BusinessPurpose.openingBalance => item.accountOf(TransactionRole.openingBalance),
    BusinessPurpose.balanceAdjustment => item.accountOf(TransactionRole.balanceAdjustment),
    _ => null,
  };
}

TransactionAccountFlowPresentation resolveAccountFlow(
  TransactionReadModel item,
  AccountLookup accountLookup,
) {
  AccountEndpointPresentation? endpointOf(String? accountId) {
    if (accountId == null) return null;
    final account = accountLookup.find(accountId);
    return AccountEndpointPresentation(
      label: account?.name ?? '—',
      iconKey: account?.iconKey,
    );
  }

  final out = endpointOf(
    _flowAccountId(
      item,
      direction: EntryDirection.credit,
    ),
  );
  final in_ = endpointOf(
    _flowAccountId(
      item,
      direction: EntryDirection.debit,
    ),
  );
  final reimbursementReceivable = endpointOf(item.accountOf(TransactionRole.receivable));
  final fallbackText = transactionAccountLabel(item, accountLookup);
  final fallbackLabel = fallbackText.isEmpty ? _noAccountLabel : fallbackText;

  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense => TransactionAccountFlowPresentation(
      out: out,
      fallbackLabel: fallbackLabel,
    ),
    BusinessPurpose.reimbursementAdvance => TransactionAccountFlowPresentation(
      out: out,
      in_: reimbursementReceivable,
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
  TransactionReadModel item,
) {
  final badges = <TransactionBadgePresentation>[
    for (final adjustment in transactionAdjustments(item))
      if (adjustment.kind !=
          TransactionAdjustmentKind.receivableCollectionPrincipal)
        _adjustmentBadge(adjustment),
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

TransactionBadgePresentation _adjustmentBadge(
  TransactionAdjustment adjustment,
) {
  final presentation = _adjustmentPresentation(adjustment.kind);
  return TransactionBadgePresentation(
    label: '${presentation.label} ${formatCompactMoney(adjustment.amount)}',
    tone: presentation.tone,
  );
}

({String label, FinanceTone tone}) _adjustmentPresentation(
  TransactionAdjustmentKind kind,
) {
  return switch (kind) {
    TransactionAdjustmentKind.transferFee => (
      label: '费',
      tone: FinanceTone.expense,
    ),
    TransactionAdjustmentKind.refund => (label: '退', tone: FinanceTone.income),
    TransactionAdjustmentKind.reimbursementReceived => (
      label: '报',
      tone: FinanceTone.info,
    ),
    TransactionAdjustmentKind.receivableCollectionPrincipal => (
      label: '本金',
      tone: FinanceTone.info,
    ),
    TransactionAdjustmentKind.receivableCollectionInterest => (
      label: '利息',
      tone: FinanceTone.income,
    ),
    TransactionAdjustmentKind.repaymentInterest => (
      label: '利',
      tone: FinanceTone.expense,
    ),
    TransactionAdjustmentKind.repaymentFee => (
      label: '费',
      tone: FinanceTone.expense,
    ),
    TransactionAdjustmentKind.repaymentDiscount => (
      label: '优',
      tone: FinanceTone.income,
    ),
    TransactionAdjustmentKind.reimbursementGapIncome => (
      label: '差收',
      tone: FinanceTone.income,
    ),
    TransactionAdjustmentKind.reimbursementGapExpense => (
      label: '差支',
      tone: FinanceTone.expense,
    ),
  };
}

CashflowSummaryPresentation buildMonthlySummaryPresentation(
  CashflowComparison comparison, {
  BudgetProgress? totalBudget,
  required CashflowPeriodMetric metric,
}) {
  final summary = comparison.current;
  return CashflowSummaryPresentation(
    metrics: [
      CashflowSummaryMetricPresentation(
        label: '本月收入',
        amount: summary.income,
        caption: formatPeriodChangeCaption(comparison.incomeChange, metric),
        tone: FinanceTone.income,
        kind: CashflowSummaryMetricKind.income,
      ),
      CashflowSummaryMetricPresentation(
        label: '本月支出',
        amount: summary.expense,
        caption: formatPeriodChangeCaption(comparison.expenseChange, metric),
        tone: FinanceTone.expense,
        kind: CashflowSummaryMetricKind.expense,
      ),
      CashflowSummaryMetricPresentation(
        label: '剩余预算',
        amount: totalBudget?.remaining ?? Money.zero(),
        caption: totalBudget == null
            ? '未设置'
            : '${formatPercent(totalBudget.usedRatio)}/'
                  '${formatRoundedMajor(totalBudget.budget.minorUnits)}',
        tone: FinanceTone.primary,
        kind: CashflowSummaryMetricKind.budget,
      ),
    ],
  );
}

String? resolveCategoryIconKey(
  TransactionReadModel item,
  AccountLookup accountLookup,
) {
  final categoryLines = item.categoryLines.toList();
  final category = categoryLines.length == 1
      ? accountLookup.find(categoryLines.single.accountId!)
      : null;
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.reimbursementAdvance => category?.iconKey,
    BusinessPurpose.transfer => 'transfer',
    BusinessPurpose.debtRepayment => 'loan',
    BusinessPurpose.borrowing => 'hand-coin-line',
    BusinessPurpose.lending => 'logout-box-r-line',
    BusinessPurpose.receivableCollection => 'login-box-r-line',
    BusinessPurpose.badDebt => 'close-circle-line',
    BusinessPurpose.debtRelief => 'hand-coin-line',
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment => 'wallet-line',
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose => null,
  };
}

String transactionPrimaryLabel(
  TransactionReadModel item,
  AccountLookup accountLookup,
) {
  final categoryLines = item.categoryLines.toList();
  final category = categoryLines.length == 1
      ? accountLookup.find(categoryLines.single.accountId!)
      : null;
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.dailyIncome =>
      categoryLines.length > 1 ? '多类别' : _cleanText(category?.name) ?? transactionPurposeLabel(item.businessPurpose),
    BusinessPurpose.reimbursementAdvance => categoryLines.length > 1 ? '多类别' : _cleanText(category?.name) ?? '支出',
    _ => transactionPurposeLabel(item.businessPurpose),
  };
}

String transactionAccountLabel(
  TransactionReadModel item,
  AccountLookup accountLookup,
) {
  String? nameOf(EntryDirection direction) {
    final accountId = _flowAccountId(
      item,
      direction: direction,
    );
    return _cleanText(
      accountId == null ? null : accountLookup.find(accountId)?.name,
    );
  }

  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.reimbursementAdvance => nameOf(EntryDirection.credit) ?? '',
    BusinessPurpose.dailyIncome => nameOf(EntryDirection.debit) ?? '',
    _ => _flowAccountLabel(item, accountLookup),
  };
}

String _flowAccountLabel(
  TransactionReadModel item,
  AccountLookup accountLookup,
) {
  String? nameOf(EntryDirection direction) {
    final accountId = _flowAccountId(
      item,
      direction: direction,
    );
    return _cleanText(
      accountId == null ? null : accountLookup.find(accountId)?.name,
    );
  }

  final out = nameOf(EntryDirection.credit);
  final in_ = nameOf(EntryDirection.debit);
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
    BusinessPurpose.lending ||
    BusinessPurpose.receivableCollection ||
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment ||
    BusinessPurpose.reimbursementClose => FinanceTone.neutral,
    BusinessPurpose.badDebt => FinanceTone.expense,
    BusinessPurpose.debtRelief => FinanceTone.income,
  };
}

String formatTransactionAmount(
  TransactionReadModel item, {
  Money? amount,
  MoneyFormatStyle style = MoneyFormatStyle.plain,
}) {
  final prefix = switch (item.businessPurpose) {
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.debtRelief => '+',
    BusinessPurpose.dailyExpense || BusinessPurpose.badDebt => '-',
    _ => '',
  };
  final formatted = formatMoney(
    (amount ?? item.primaryAmount).abs(),
    style: style,
  );
  return '$prefix$formatted';
}

({Money original, Money actual})? transactionAmountComparison(
  TransactionReadModel item,
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
Money? accountImpactNetChange({
  required TransactionReadModel item,
  required String accountId,
}) {
  return item.impactsByAccountId[accountId]?.netChange;
}

String formatAccountDelta(
  Money delta, {
  MoneyFormatStyle style = MoneyFormatStyle.plain,
}) {
  final sign = delta.minorUnits >= 0 ? '+' : '-';
  final amount = formatMoney(delta.abs(), style: style);
  return '$sign$amount';
}

bool canQuickEditTransaction(TransactionReadModel item) {
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.reimbursementAdvance ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.transfer ||
    BusinessPurpose.borrowing => true,
    BusinessPurpose.lending ||
    BusinessPurpose.receivableCollection ||
    BusinessPurpose.badDebt ||
    BusinessPurpose.debtRelief => false,
    BusinessPurpose.debtRepayment ||
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment ||
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose => false,
  };
}

Money? adjustmentAmount(
  TransactionReadModel item,
  TransactionAdjustmentKind kind,
) {
  for (final adjustment in transactionAdjustments(item)) {
    if (adjustment.kind == kind) return adjustment.amount;
  }
  return null;
}

List<TransactionAdjustment> transactionAdjustments(TransactionReadModel item) {
  if (item.parentTransactionId != null) return const [];
  final result = <TransactionAdjustment>[];
  void add(TransactionAdjustmentKind kind, Money amount) {
    if (amount.minorUnits > 0) result.add(TransactionAdjustment(kind: kind, amount: amount));
  }
  switch (item.businessPurpose) {
    case BusinessPurpose.transfer:
      add(TransactionAdjustmentKind.transferFee, item.amountOf(TransactionRole.fee));
    case BusinessPurpose.dailyExpense:
      add(TransactionAdjustmentKind.refund, item.refundedTotal);
    case BusinessPurpose.reimbursementAdvance:
      add(TransactionAdjustmentKind.refund, item.refundedTotal);
      add(TransactionAdjustmentKind.reimbursementReceived, item.reimbursementReceivedTotal);
      for (final child in item.children) {
        add(TransactionAdjustmentKind.reimbursementGapIncome, child.amountOf(TransactionRole.reimbursementGapIncome));
        add(TransactionAdjustmentKind.reimbursementGapExpense, child.amountOf(TransactionRole.reimbursementGapExpense));
      }
    case BusinessPurpose.debtRepayment:
      add(TransactionAdjustmentKind.repaymentInterest, item.amountOf(TransactionRole.interest));
      add(TransactionAdjustmentKind.repaymentFee, item.amountOf(TransactionRole.fee));
      add(TransactionAdjustmentKind.repaymentDiscount, item.amountOf(TransactionRole.discount));
    case BusinessPurpose.receivableCollection:
      add(TransactionAdjustmentKind.receivableCollectionPrincipal, item.amountOf(TransactionRole.receivable));
      add(TransactionAdjustmentKind.receivableCollectionInterest, item.amountOf(TransactionRole.interest));
    default:
      break;
  }
  return List.unmodifiable(result);
}

String formatCompactMoney(Money money) {
  return formatMoney(money.abs(), style: MoneyFormatStyle.compact);
}

/// 按用户选择的展示口径格式化收入/支出的同期比较文案。
String formatPeriodChangeCaption(
  PeriodChange change,
  CashflowPeriodMetric metric,
) {
  return switch (metric) {
    CashflowPeriodMetric.periodDelta =>
      change.isFlat
          ? '与上月同期持平'
          : '较上月同期 ${formatSignedCompactAmount(change.delta.minorUnits)}',
    CashflowPeriodMetric.periodRatio =>
      '较上月同期 ${formatSignedOptionalPercent(change.ratio)}',
    CashflowPeriodMetric.previousMonthRatio =>
      '已达上月 ${formatOptionalPercent(change.fullPeriodRatio)}',
  };
}

String formatSignedCompactAmount(int minorUnits) {
  final formatted = formatMoney(
    Money(minorUnits: minorUnits),
    style: MoneyFormatStyle.compact,
  );
  return minorUnits > 0 ? '+$formatted' : formatted;
}

String formatSignedOptionalPercent(double? ratio) {
  if (ratio == null) {
    return '--%';
  }
  final percent = (ratio * 100).round();
  final sign = percent > 0 ? '+' : '';
  return '$sign$percent%';
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
