import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/money_formatter.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/widget/business/finance/finance_labels.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

import 'account_lookup.dart';
import 'business_scene/business_activity_item_presentation.dart';
import 'business_scene/business_scene_presentation.dart';
import 'business_scene/business_scene_list_presentation.dart';
import 'business_scene/transaction_adjustment_presentation.dart';
import 'transaction_badge_presentation.dart';
import '../../../widget/business/transaction/transaction_avatar_kind.dart';
import 'transaction_category_identity.dart';

export 'transaction_badge_presentation.dart';
export 'business_scene/transaction_adjustment_presentation.dart';

const _noAccountLabel = '无账户';

sealed class TransactionListAmountSource {
  const TransactionListAmountSource();
}

final class TransactionGroupAmountSource extends TransactionListAmountSource {
  const TransactionGroupAmountSource();
}

/// A contribution from income/expense entries only, independent of purpose.
final class TransactionCashflowImpactAmountSource
    extends TransactionListAmountSource {
  const TransactionCashflowImpactAmountSource(this.accountIds);
  final Set<String> accountIds;
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
    this.closingBalance,
    this.closingBalanceLabel = '余额',
    this.warning,
  });

  final DateTime date;
  final List<TransactionRowPresentation> rows;
  final int incomeMinor;
  final int expenseMinor;
  final Money? closingBalance;
  final String closingBalanceLabel;
  final String? warning;

  TransactionDayGroup copyWith({
    DateTime? date,
    List<TransactionRowPresentation>? rows,
    int? incomeMinor,
    int? expenseMinor,
    Money? closingBalance,
    String? closingBalanceLabel,
    String? warning,
  }) {
    return TransactionDayGroup(
      date: date ?? this.date,
      rows: rows ?? this.rows,
      incomeMinor: incomeMinor ?? this.incomeMinor,
      expenseMinor: expenseMinor ?? this.expenseMinor,
      closingBalance: closingBalance ?? this.closingBalance,
      closingBalanceLabel: closingBalanceLabel ?? this.closingBalanceLabel,
      warning: warning ?? this.warning,
    );
  }
}

class FinancialFeedRowPresentation {
  const FinancialFeedRowPresentation({
    required this.transactionId,
    required this.iconKey,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.amountTone,
    required this.accountFlow,
    required this.badges,
    required this.canQuickEdit,
    this.businessPurpose = BusinessPurpose.dailyExpense,
    this.hasMultipleCategories = false,
    this.preferCategoryArtwork = false,
    this.originalAmountText,
    this.selectable = false,
    this.selected = false,
    this.selectionEnabled = true,
    this.dimmed = false,
    this.canOpenTransaction = true,
    this.supportingText,
    this.avatarKind,
  });

  final String transactionId;
  final BusinessPurpose businessPurpose;
  final bool hasMultipleCategories;
  final bool preferCategoryArtwork;
  final String? iconKey;
  final String title;
  final String subtitle;
  final AdaptiveMoneyTextPresentation amount;
  final String? originalAmountText;
  final FinanceTone amountTone;
  final TransactionAccountFlowPresentation accountFlow;
  final List<TransactionBadgePresentation> badges;
  final bool canQuickEdit;
  final TransactionAvatarKind? avatarKind;
  final bool selectable;
  final bool selected;
  final bool selectionEnabled;
  final bool canOpenTransaction;
  final String? supportingText;

  /// 行不会参与导入/展示时置灰，保持可交互。
  final bool dimmed;

  bool get hasBadges => badges.isNotEmpty;

  FinancialFeedRowPresentation copyWith({
    AdaptiveMoneyTextPresentation? amount,
    String? title,
    List<TransactionBadgePresentation>? badges,
    String? supportingText,
    bool? selectable,
    bool? selected,
    bool? selectionEnabled,
    bool? dimmed,
    bool? preferCategoryArtwork,
    String? iconKey,
    bool? hasMultipleCategories,
    TransactionAvatarKind? avatarKind,
  }) {
    return FinancialFeedRowPresentation(
      transactionId: transactionId,
      businessPurpose: businessPurpose,
      hasMultipleCategories:
          hasMultipleCategories ?? this.hasMultipleCategories,
      preferCategoryArtwork:
          preferCategoryArtwork ?? this.preferCategoryArtwork,
      iconKey: iconKey ?? this.iconKey,
      title: title ?? this.title,
      subtitle: subtitle,
      amount: amount ?? this.amount,
      originalAmountText: originalAmountText,
      amountTone: amountTone,
      accountFlow: accountFlow,
      badges: badges ?? this.badges,
      canQuickEdit: canQuickEdit,
      avatarKind: avatarKind ?? this.avatarKind,
      selectable: selectable ?? this.selectable,
      selected: selected ?? this.selected,
      selectionEnabled: selectionEnabled ?? this.selectionEnabled,
      dimmed: dimmed ?? this.dimmed,
      canOpenTransaction: canOpenTransaction,
      supportingText: supportingText ?? this.supportingText,
    );
  }
}

typedef TransactionRowPresentation = FinancialFeedRowPresentation;

class AdaptiveMoneyTextPresentation {
  const AdaptiveMoneyTextPresentation({
    required this.preciseText,
    required this.compactText,
  });

  final String preciseText;
  final String compactText;
}

class TransactionAccountFlowPresentation {
  const TransactionAccountFlowPresentation({
    this.out,
    this.in_,
    this.outEndpoints = const [],
    this.inEndpoints = const [],
    this.separator = '->',
    this.fallbackLabel = _noAccountLabel,
  });

  final AccountEndpointPresentation? out;
  final AccountEndpointPresentation? in_;
  final List<AccountEndpointPresentation> outEndpoints;
  final List<AccountEndpointPresentation> inEndpoints;
  final String separator;
  final String fallbackLabel;

  List<AccountEndpointPresentation> get effectiveOutEndpoints =>
      outEndpoints.isNotEmpty
      ? outEndpoints
      : out == null
      ? const []
      : [out!];

  List<AccountEndpointPresentation> get effectiveInEndpoints =>
      inEndpoints.isNotEmpty
      ? inEndpoints
      : in_ == null
      ? const []
      : [in_!];

  AccountEndpointPresentation get singleEndpoint =>
      out ?? in_ ?? AccountEndpointPresentation(label: fallbackLabel);
}

class AccountEndpointPresentation {
  const AccountEndpointPresentation({required this.label, this.iconKey});

  final String label;
  final String? iconKey;
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
  required TransactionListAmountSource amountSource,
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

List<TransactionDayGroup> groupTransactionFeedEntriesByDay({
  required List<TransactionFeedEntry> entries,
  required AccountLookup accountLookup,
  List<DailyCashflowSummary> dailySummaries = const [],
  required TransactionListAmountSource amountSource,
}) {
  final groups = <DateTime, List<TransactionRowPresentation>>{};
  for (final entry in entries) {
    final transaction = entry.transaction;
    final date = normalizeDate(transaction.occurredAt);
    groups
        .putIfAbsent(date, () => [])
        .add(
          buildTransactionRowPresentation(
            item: transaction,
            businessItem: entry.businessItem,
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

List<TransactionDayGroup> groupBusinessActivitiesByDay({
  required List<BusinessActivityReadModel> items,
  required AccountLookup accountLookup,
  List<DailyCashflowSummary> dailySummaries = const [],
  TransactionListDisplayMode displayMode = TransactionListDisplayMode.standard,
}) {
  final groups = <DateTime, List<FinancialFeedRowPresentation>>{};
  for (final item in items) {
    final date = normalizeDate(item.activityAt);
    groups
        .putIfAbsent(date, () => [])
        .add(
          buildBusinessActivityRowPresentation(
            item: item,
            accountLookup: accountLookup,
            displayMode: displayMode,
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

TransactionDayGroup businessActivityGroupForDate({
  required DateTime date,
  required List<BusinessActivityReadModel> items,
  required List<DailyCashflowSummary> dailySummaries,
  required AccountLookup accountLookup,
  TransactionListDisplayMode displayMode = TransactionListDisplayMode.standard,
}) {
  final normalized = normalizeDate(date);
  final dayItems = [
    for (final item in items)
      if (isSameDate(item.activityAt, normalized)) item,
  ];
  final summary = _dailySummariesByDate(dailySummaries)[normalized];
  return TransactionDayGroup(
    date: normalized,
    rows: [
      for (final item in dayItems)
        buildBusinessActivityRowPresentation(
          item: item,
          accountLookup: accountLookup,
          displayMode: displayMode,
        ),
    ],
    incomeMinor: summary?.income.minorUnits ?? 0,
    expenseMinor: summary?.expense.minorUnits ?? 0,
  );
}

TransactionRowPresentation buildTransactionRowPresentation({
  required TransactionReadModel item,
  required AccountLookup accountLookup,
  BusinessActivityItem? businessItem,
  required TransactionListAmountSource amountSource,
}) {
  final cashflowDelta = amountSource is TransactionCashflowImpactAmountSource
      ? Money(
          minorUnits: amountSource.accountIds.fold<int>(0, (sum, id) {
            final type = accountLookup.find(id)?.type;
            final change =
                item.impactsByAccountId[id]?.netChange.minorUnits ?? 0;
            return sum +
                (type == AccountType.income
                    ? change
                    : type == AccountType.expense
                    ? -change
                    : 0);
          }),
        )
      : null;
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

  String formatPrimaryAmount(MoneyFormatStyle style) {
    if (cashflowDelta != null) {
      return formatAccountDelta(cashflowDelta, style: style);
    }
    if (accountDelta != null) {
      return formatAccountDelta(accountDelta, style: style);
    }
    return formatTransactionAmount(
      item,
      amount: transactionAmount,
      style: style,
    );
  }

  final transactionProjection = businessItem?.projectionFor(item.id);
  final itemCategoryIds = switch (transactionProjection) {
    AmortizationTransactionProjection(:final localCategoryAllocations) =>
      localCategoryAllocations.map((allocation) => allocation.accountId),
    _ => const <String>[],
  };
  final isActivityEntry = businessItem?.isOrigin ?? false;
  final isNonEntry =
      isKnownBusinessActivityItem(businessItem) && !isActivityEntry;
  final itemCategory =
      !isNonEntry && item.categoryLines.isEmpty && itemCategoryIds.isNotEmpty
      ? resolveTransactionCategoryIdentity(
          transactionAccountIds: const {},
          supplementalAccountIds: itemCategoryIds,
          accountLookup: accountLookup,
        )
      : null;
  final hasMultipleCategories =
      !isNonEntry &&
      (_businessCategoryAccountIds(item).length > 1 ||
          itemCategory?.hasMultiple == true);
  final itemTitle = isNonEntry
      ? nonEntryBusinessActivityItemTitle(businessItem, item)
      : null;
  final avatarKind = isNonEntry
      ? businessActivityItemAvatarKind(
          businessItem,
          projection: transactionProjection,
        )
      : null;

  return TransactionRowPresentation(
    transactionId: item.id,
    businessPurpose: item.businessPurpose,
    hasMultipleCategories: hasMultipleCategories,
    iconKey: isNonEntry
        ? null
        : itemCategory?.iconKey ?? resolveCategoryIconKey(item, accountLookup),
    title: isNonEntry
        ? itemTitle ?? transactionPrimaryLabel(item, accountLookup)
        : itemCategory?.hasMultiple == true
        ? '多类别'
        : itemCategory?.name ?? transactionPrimaryLabel(item, accountLookup),
    subtitle: formatTime(item.occurredAt),
    amount: AdaptiveMoneyTextPresentation(
      preciseText: formatPrimaryAmount(MoneyFormatStyle.plain),
      compactText: formatPrimaryAmount(MoneyFormatStyle.compact),
    ),
    originalAmountText: comparison == null
        ? null
        : formatTransactionAmount(
            item,
            amount: comparison.original,
            style: MoneyFormatStyle.compact,
          ),
    amountTone: cashflowDelta != null
        ? (cashflowDelta.minorUnits < 0
              ? FinanceTone.expense
              : FinanceTone.income)
        : accountDelta == null
        ? amountTone(item.businessPurpose)
        : FinanceTone.neutral,
    accountFlow: resolveAccountFlow(item, accountLookup),
    badges: buildTransactionBadges(item),
    canQuickEdit: canQuickEditTransaction(item),
    avatarKind: avatarKind,
    supportingText: businessActivityEntrySupportingText(businessItem, item),
    preferCategoryArtwork: !isNonEntry && itemCategory != null,
  );
}

FinancialFeedRowPresentation buildBusinessActivityRowPresentation({
  required BusinessActivityReadModel item,
  required AccountLookup accountLookup,
  TransactionListDisplayMode displayMode = TransactionListDisplayMode.standard,
}) {
  final transaction = item.displayTransaction;
  final content = presentBusinessSceneRowContent(item);
  final modeBadges = displayMode == TransactionListDisplayMode.compact
      ? content.compactBadges
      : content.standardBadges;
  if (transaction == null) {
    return _buildTransactionlessBusinessActivityRow(
      item: item,
      content: content,
      modeBadges: modeBadges,
      accountLookup: accountLookup,
      displayMode: displayMode,
    );
  }

  final base = buildTransactionRowPresentation(
    item: transaction,
    accountLookup: accountLookup,
    amountSource: const TransactionGroupAmountSource(),
  );
  final categoryIdentity = content.categoryAccountIds.isEmpty
      ? null
      : resolveTransactionCategoryIdentity(
          transactionAccountIds: _businessCategoryAccountIds(transaction),
          supplementalAccountIds: content.categoryAccountIds,
          accountLookup: accountLookup,
        );
  final badges = <TransactionBadgePresentation>[...modeBadges, ...base.badges];
  return base.copyWith(
    title: categoryIdentity?.hasMultiple == true
        ? '多类别'
        : categoryIdentity?.name ?? content.titleOverride ?? base.title,
    iconKey: categoryIdentity?.iconKey,
    hasMultipleCategories: categoryIdentity?.hasMultiple,
    badges: badges,
    supportingText: displayMode == TransactionListDisplayMode.compact
        ? null
        : content.standardSummary,
    preferCategoryArtwork: content.preferCategoryArtwork,
  );
}

FinancialFeedRowPresentation _buildTransactionlessBusinessActivityRow({
  required BusinessActivityReadModel item,
  required BusinessActivityRowContent content,
  required List<TransactionBadgePresentation> modeBadges,
  required AccountLookup accountLookup,
  required TransactionListDisplayMode displayMode,
}) {
  final categoryIdentity = content.categoryAccountIds.isEmpty
      ? null
      : resolveTransactionCategoryIdentity(
          transactionAccountIds: const {},
          supplementalAccountIds: content.categoryAccountIds,
          accountLookup: accountLookup,
        );
  final amount = formatMoney(Money.zero(), style: MoneyFormatStyle.plain);
  final compactAmount = formatMoney(
    Money.zero(),
    style: MoneyFormatStyle.compact,
  );
  return TransactionRowPresentation(
    transactionId:
        'business-activity:${item.activityKey.type}:${item.activityKey.id}',
    title: categoryIdentity?.hasMultiple == true
        ? '多类别'
        : categoryIdentity?.name ??
              content.titleOverride ??
              businessActivityTitle(item.summary),
    subtitle: formatTime(item.activityAt),
    iconKey: categoryIdentity?.iconKey,
    amount: AdaptiveMoneyTextPresentation(
      preciseText: amount,
      compactText: compactAmount,
    ),
    amountTone: FinanceTone.neutral,
    accountFlow: const TransactionAccountFlowPresentation(),
    badges: modeBadges,
    canQuickEdit: false,
    canOpenTransaction: false,
    hasMultipleCategories: categoryIdentity?.hasMultiple ?? false,
    preferCategoryArtwork: content.preferCategoryArtwork,
    supportingText: displayMode == TransactionListDisplayMode.compact
        ? null
        : content.standardSummary,
  );
}

String businessActivityTitle(BusinessActivitySummary summary) {
  return switch (summary) {
    LedgerBusinessActivitySummary() => '账务活动',
    AdvanceBusinessActivitySummary() => '垫付',
    InstallmentBusinessActivitySummary(:final installmentType) =>
      switch (installmentType) {
        InstallmentType.purchase => '消费分期',
        InstallmentType.disbursement => '放款分期',
        InstallmentType.billConversion => '账单分期',
      },
    RepaymentBusinessActivitySummary(:final repaymentType) =>
      switch (repaymentType) {
        RepaymentType.bill => '账单还款',
        RepaymentType.installment => '分期还款',
        RepaymentType.prepayment => '提前还款',
        RepaymentType.unattributed => '未归属还款',
      },
    AmortizationBusinessActivitySummary(:final kind) => switch (kind) {
      AmortizationKind.prepaidExpense => '预付摊销',
      AmortizationKind.deferredIncome => '预收摊销',
    },
  };
}

String? _flowAccountId(
  TransactionReadModel item, {
  required EntryDirection direction,
}) {
  final role = switch ((item.businessPurpose, direction)) {
    (BusinessPurpose.lending, EntryDirection.debit) ||
    (BusinessPurpose.receivableCollection, EntryDirection.credit) ||
    (
      BusinessPurpose.badDebt,
      EntryDirection.credit,
    ) => TransactionRole.receivable,
    (BusinessPurpose.borrowing, EntryDirection.credit) ||
    (BusinessPurpose.debtRepayment, EntryDirection.debit) ||
    (
      BusinessPurpose.debtRelief,
      EntryDirection.debit,
    ) => TransactionRole.liability,
    (_, EntryDirection.debit) => TransactionRole.settlementIn,
    (_, EntryDirection.credit) => TransactionRole.settlementOut,
  };
  final accountId = item.accountOf(role);
  if (accountId != null) return accountId;
  return switch (item.businessPurpose) {
    BusinessPurpose.openingBalance => item.accountOf(
      TransactionRole.openingBalance,
    ),
    BusinessPurpose.balanceAdjustment => item.accountOf(
      TransactionRole.balanceAdjustment,
    ),
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

  List<AccountEndpointPresentation> endpointsOf(TransactionRole role) {
    return [
      for (final line in item.linesOf(role))
        if (line.accountId != null) endpointOf(line.accountId)!,
    ];
  }

  final outEndpoints = endpointsOf(TransactionRole.settlementOut);
  final inEndpoints = endpointsOf(TransactionRole.settlementIn);
  final out =
      outEndpoints.firstOrNull ??
      endpointOf(_flowAccountId(item, direction: EntryDirection.credit));
  final in_ =
      inEndpoints.firstOrNull ??
      endpointOf(_flowAccountId(item, direction: EntryDirection.debit));
  final advanceReceivable = endpointOf(
    item.accountOf(TransactionRole.receivable),
  );
  final fallbackText = transactionAccountLabel(item, accountLookup);
  final fallbackLabel = fallbackText.isEmpty ? _noAccountLabel : fallbackText;

  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense => TransactionAccountFlowPresentation(
      out: out,
      outEndpoints: outEndpoints,
      fallbackLabel: fallbackLabel,
    ),
    BusinessPurpose.advance => TransactionAccountFlowPresentation(
      out: out,
      in_: advanceReceivable,
      outEndpoints: outEndpoints,
      separator: '|',
      fallbackLabel: fallbackLabel,
    ),
    BusinessPurpose.dailyIncome => TransactionAccountFlowPresentation(
      in_: in_,
      inEndpoints: inEndpoints,
      fallbackLabel: fallbackLabel,
    ),
    _ => TransactionAccountFlowPresentation(
      out: out,
      in_: in_,
      outEndpoints: outEndpoints,
      inEndpoints: inEndpoints,
      fallbackLabel: fallbackLabel,
    ),
  };
}

List<TransactionBadgePresentation> buildTransactionBadges(
  TransactionReadModel item,
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

  return badges;
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
  final categoryIds = _businessCategoryAccountIds(item).toList();
  final category = categoryIds.length == 1
      ? accountLookup.find(categoryIds.single)
      : null;
  if (_isAmortizationTransaction(item)) {
    return category?.iconKey;
  }
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.advance => category?.iconKey,
    _ => null,
  };
}

String transactionPrimaryLabel(
  TransactionReadModel item,
  AccountLookup accountLookup,
) {
  final categoryIds = _businessCategoryAccountIds(item).toList();
  final category = categoryIds.length == 1
      ? accountLookup.find(categoryIds.single)
      : null;
  if (_isAmortizationTransaction(item)) {
    if (categoryIds.length > 1) return '多类别';
    return _cleanText(category?.name) ?? '摊销';
  }
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.dailyIncome =>
      categoryIds.length > 1
          ? '多类别'
          : _cleanText(category?.name) ??
                transactionPurposeLabel(item.businessPurpose),
    BusinessPurpose.advance =>
      categoryIds.length > 1 ? '多类别' : _cleanText(category?.name) ?? '支出',
    _ => transactionPurposeLabel(item.businessPurpose),
  };
}

String transactionAccountLabel(
  TransactionReadModel item,
  AccountLookup accountLookup,
) {
  String? nameOf(EntryDirection direction) {
    final accountId = _flowAccountId(item, direction: direction);
    return _cleanText(
      accountId == null ? null : accountLookup.find(accountId)?.name,
    );
  }

  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense || BusinessPurpose.advance =>
      item.linesOf(TransactionRole.settlementOut).length > 1
          ? '多账户'
          : nameOf(EntryDirection.credit) ?? '',
    BusinessPurpose.dailyIncome =>
      item.linesOf(TransactionRole.settlementIn).length > 1
          ? '多账户'
          : nameOf(EntryDirection.debit) ?? '',
    BusinessPurpose.transfer =>
      item.linesOf(TransactionRole.settlementOut).length > 1 ||
              item.linesOf(TransactionRole.settlementIn).length > 1
          ? '多账户'
          : _flowAccountLabel(item, accountLookup),
    _ => _flowAccountLabel(item, accountLookup),
  };
}

String _flowAccountLabel(
  TransactionReadModel item,
  AccountLookup accountLookup,
) {
  String? nameOf(EntryDirection direction) {
    final accountId = _flowAccountId(item, direction: direction);
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
    BusinessPurpose.advanceCollection => FinanceTone.income,
    BusinessPurpose.transfer ||
    BusinessPurpose.advance ||
    BusinessPurpose.debtRepayment ||
    BusinessPurpose.borrowing ||
    BusinessPurpose.lending ||
    BusinessPurpose.receivableCollection ||
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment ||
    BusinessPurpose.advanceSettlement => FinanceTone.neutral,
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
    BusinessPurpose.advanceCollection ||
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
  if (_isAmortizationTransaction(item)) return false;
  return switch (item.businessPurpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.advance ||
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
    BusinessPurpose.advanceCollection ||
    BusinessPurpose.advanceSettlement => false,
  };
}

Set<String> _businessCategoryAccountIds(TransactionReadModel item) {
  return {for (final line in item.categoryLines) ?line.accountId};
}

bool _isAmortizationTransaction(TransactionReadModel item) =>
    item.ownership?.ownerType == orchestrationAmortizationOwnerType;

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
