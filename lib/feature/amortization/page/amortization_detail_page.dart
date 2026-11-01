import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../../domain/ledger/entity/account.dart';
import '../../../domain/orchestration/entity/amortization_period.dart';
import '../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../../../widget/business/transaction/transaction_allocation_fields.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/amortization_detail_view_model.dart';

class AmortizationDetailPage extends ConsumerWidget {
  const AmortizationDetailPage({required this.planId, super.key});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(amortizationDetailViewModelProvider(planId));
    final accounts = ref.watch(accountsByIdProvider).value ?? const {};
    return switch (asyncState) {
      AsyncData(value: final state) when state != null => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              AppPageHeader(
                title: '摊销详情',
                actions: [
                  AppHeaderIconButton(
                    icon: RemixIcons.refund_2_line,
                    tooltip: '摊销退款',
                    onPressed:
                        state.plan.status == AmortizationStatus.terminated ||
                            state.plan.netAmount.minorUnits == 0
                        ? null
                        : () => _showRefundSheet(context, state),
                  ),
                  AppHeaderIconButton(
                    icon: RemixIcons.stop_circle_line,
                    tooltip: '摊销终止',
                    onPressed:
                        state.plan.status == AmortizationStatus.terminated
                        ? null
                        : () => _showTerminationSheet(context, state),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space12,
                    AppSpacing.space16,
                    AppSpacing.space24,
                  ),
                  children: [
                    AppFormSection(
                      title: _kindLabel(state.plan.kind),
                      children: [
                        _ValueRow(
                          label: '原摊销金额',
                          value: MoneyText(
                            money: state.plan.originalAmount,
                            semantic: MoneySemantic.neutral,
                          ),
                        ),
                        _ValueRow(
                          label: '累计退款',
                          value: MoneyText(
                            money: state.plan.refundedAmount,
                            semantic: MoneySemantic.income,
                          ),
                        ),
                        _ValueRow(
                          label: '净摊销金额',
                          value: MoneyText(
                            money: state.plan.netAmount,
                            semantic: MoneySemantic.neutral,
                          ),
                        ),
                        _ValueRow(
                          label: '当前剩余',
                          value: MoneyText(
                            money: state.plan.remainingAmount,
                            semantic: MoneySemantic.neutral,
                          ),
                        ),
                        _ValueRow(
                          label: '递延账户',
                          value: Text(
                            accounts[state.plan.deferralAccountId]?.name ??
                                '未知账户',
                          ),
                        ),
                        _ValueRow(
                          label: '当前分类',
                          value: Text(_categoryNames(state.plan, accounts)),
                        ),
                        _ValueRow(
                          label: '下一期',
                          value: Text(
                            state.plan.nextPendingPeriod == null
                                ? _statusLabel(state.plan.status)
                                : _date(state.plan.nextPendingPeriod!.dueAt),
                          ),
                        ),
                        if (state.plan.termination case final termination?)
                          _ValueRow(
                            label: '终止退还',
                            value: MoneyText(
                              money: termination.returnAmount,
                              semantic: MoneySemantic.income,
                            ),
                          ),
                      ],
                    ),
                    if (state.plan.refunds.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.space24),
                      AppFormSection(
                        title: '退款记录',
                        children: [
                          for (
                            var index = 0;
                            index < state.plan.refunds.length;
                            index++
                          )
                            _ValueRow(
                              label: '退款 ${index + 1}',
                              value: MoneyText(
                                money: state.plan.refunds[index].amount,
                                semantic: MoneySemantic.income,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.space24),
                    AppFormSection(
                      title: '摊销进度',
                      description: '每笔摊销交易可在交易详情中单独维护备注、对手方和统计配置。',
                      children: [
                        for (final period in state.plan.periods)
                          _PeriodRow(period: period),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      AsyncData(value: null) => const _StatusPage(message: '摊销计划不存在'),
      AsyncError() => const _StatusPage(message: '摊销计划加载失败'),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Future<void> _showRefundSheet(
    BuildContext context,
    AmortizationDetailState state,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RefundSheet(planId: planId, state: state),
    );
  }

  Future<void> _showTerminationSheet(
    BuildContext context,
    AmortizationDetailState state,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TerminationSheet(planId: planId, state: state),
    );
  }
}

class _RefundSheet extends ConsumerStatefulWidget {
  const _RefundSheet({required this.planId, required this.state});

  final String planId;
  final AmortizationDetailState state;

  @override
  ConsumerState<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends ConsumerState<_RefundSheet> {
  final _formKey = GlobalKey<FormState>();
  var _occurredAt = DateTime.now();
  var _categoryAllocations = <AccountAmountAllocation>[];
  late var _settlementAllocations = <AccountAmountAllocation>[
    if (widget.state.settlementAccounts.firstOrNull case final account?)
      AccountAmountAllocation(accountId: account.id, amount: Money.zero()),
  ];
  bool _submitting = false;

  List<TransactionAllocationOption> get _categoryOptions => [
    for (final allocation in widget.state.plan.currentCategoryAllocations)
      _categoryOption(allocation.accountId, widget.state.categoryAccounts),
  ];

  List<TransactionAllocationOption> get _settlementOptions =>
      transactionAllocationOptionsForAccounts(widget.state.settlementAccounts);

  @override
  Widget build(BuildContext context) {
    final categoryTotal = sumAllocations(_categoryAllocations);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space16,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('摊销退款', style: context.appTextStyles.subsectionTitle),
              const SizedBox(height: AppSpacing.space12),
              _dateRow(
                context,
                label: '退款日期',
                value: _occurredAt,
                onChanged: (value) => setState(() => _occurredAt = value),
              ),
              const SizedBox(height: AppSpacing.space12),
              TransactionAllocationAmountFields(
                title: '退款分类',
                allocations: _categoryAllocations,
                options: _categoryOptions,
                maximumByAccountId: transactionAllocationMaximums(
                  options: _categoryOptions,
                  availableAllocations:
                      widget.state.plan.currentCategoryAllocations,
                ),
                onChanged: (value) =>
                    setState(() => _categoryAllocations = value),
              ),
              const SizedBox(height: AppSpacing.space12),
              TransactionInlineAllocationColumn(
                title: '退款账户',
                allocations: _settlementAllocations,
                options: _settlementOptions,
                addLabel: '添加退款账户',
                expectedTotal: categoryTotal,
                onSelectOption: (context, selectedId, options) =>
                    selectTransactionAllocationAccount(
                      context,
                      accounts: widget.state.settlementAccounts,
                      selectedAccountId: selectedId,
                      options: options,
                    ),
                onChanged: (value) =>
                    setState(() => _settlementAllocations = value),
              ),
              const SizedBox(height: AppSpacing.space16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('确认退款'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    final categoryTotal = sumAllocations(_categoryAllocations);
    final settlementTotal = sumAllocations(_settlementAllocations);
    if (categoryTotal.minorUnits <= 0 || categoryTotal != settlementTotal) {
      _showMessage('退款分类与退款账户金额必须相等且大于零');
      return;
    }
    setState(() => _submitting = true);
    final outcome = await ref
        .read(amortizationDetailViewModelProvider(widget.planId).notifier)
        .refund(
          occurredAt: _occurredAt,
          categoryAllocations: _categoryAllocations,
          settlementAllocations: _settlementAllocations,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    _handleOutcome(outcome);
  }

  void _handleOutcome(UiActionOutcome<void> outcome) {
    switch (outcome) {
      case UiActionSuccess():
        Navigator.of(context).pop();
      case UiActionFailure(:final error):
        _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TerminationSheet extends ConsumerStatefulWidget {
  const _TerminationSheet({required this.planId, required this.state});

  final String planId;
  final AmortizationDetailState state;

  @override
  ConsumerState<_TerminationSheet> createState() => _TerminationSheetState();
}

class _TerminationSheetState extends ConsumerState<_TerminationSheet> {
  final _formKey = GlobalKey<FormState>();
  var _terminatedAt = DateTime.now();
  var _categoryReturnAllocations = <AccountAmountAllocation>[];
  var _settlementAllocations = <AccountAmountAllocation>[];
  bool _submitting = false;

  List<TransactionAllocationOption> get _categoryOptions => [
    for (final allocation in widget.state.plan.remainingCategoryAllocations)
      _categoryOption(allocation.accountId, widget.state.categoryAccounts),
  ];

  List<TransactionAllocationOption> get _settlementOptions =>
      transactionAllocationOptionsForAccounts(widget.state.settlementAccounts);

  @override
  Widget build(BuildContext context) {
    final total = sumAllocations(
      widget.state.plan.remainingCategoryAllocations,
    );
    final returned = sumAllocations(_categoryReturnAllocations);
    final recognized = total - returned;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space16,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('摊销终止', style: context.appTextStyles.subsectionTitle),
              const SizedBox(height: AppSpacing.space12),
              _dateRow(
                context,
                label: '终止日期',
                value: _terminatedAt,
                onChanged: (value) => setState(() => _terminatedAt = value),
              ),
              const SizedBox(height: AppSpacing.space12),
              TransactionAllocationAmountFields(
                title: '终止分类退还',
                allocations: _categoryReturnAllocations,
                options: _categoryOptions,
                maximumByAccountId: transactionAllocationMaximums(
                  options: _categoryOptions,
                  availableAllocations:
                      widget.state.plan.remainingCategoryAllocations,
                ),
                onChanged: (value) =>
                    setState(() => _categoryReturnAllocations = value),
              ),
              const SizedBox(height: AppSpacing.space12),
              TransactionInlineAllocationColumn(
                title: '终止账户退还',
                allocations: _settlementAllocations,
                options: _settlementOptions,
                addLabel: '添加退还账户',
                expectedTotal: returned,
                onSelectOption: (context, selectedId, options) =>
                    selectTransactionAllocationAccount(
                      context,
                      accounts: widget.state.settlementAccounts,
                      selectedAccountId: selectedId,
                      options: options,
                    ),
                onChanged: (value) =>
                    setState(() => _settlementAllocations = value),
              ),
              const SizedBox(height: AppSpacing.space12),
              _ValueRow(
                label: '终止确认',
                value: MoneyText(
                  money: recognized,
                  semantic: MoneySemantic.neutral,
                ),
              ),
              const SizedBox(height: AppSpacing.space16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('确认终止'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    final categoryTotal = sumAllocations(_categoryReturnAllocations);
    final settlementTotal = sumAllocations(_settlementAllocations);
    if (categoryTotal != settlementTotal) {
      _showMessage('终止分类退还与账户退还金额必须相等');
      return;
    }
    setState(() => _submitting = true);
    final outcome = await ref
        .read(amortizationDetailViewModelProvider(widget.planId).notifier)
        .terminate(
          terminatedAt: _terminatedAt,
          categoryReturnAllocations: _categoryReturnAllocations,
          settlementAllocations: _settlementAllocations,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (outcome) {
      case UiActionSuccess():
        Navigator.of(context).pop();
      case UiActionFailure(:final error):
        _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

TransactionAllocationOption _categoryOption(
  String accountId,
  List<Account> accounts,
) {
  final account = accounts.where((item) => item.id == accountId).firstOrNull;
  return TransactionAllocationOption(
    accountId: accountId,
    label: account?.name ?? accountId,
    iconKey: account?.iconKey,
  );
}

Widget _dateRow(
  BuildContext context, {
  required String label,
  required DateTime value,
  required ValueChanged<DateTime> onChanged,
}) {
  return DateTimePlainFormRow(
    label: label,
    dateTime: value,
    value: _date(value),
    onTap: (onSelected) async {
      final selected = await showAppDatePicker(
        context: context,
        initialDate: value,
      );
      if (selected == null) return;
      onSelected(selected);
      onChanged(selected);
    },
    onChanged: (_) {},
    showChevron: true,
  );
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period});

  final AmortizationPeriod period;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('${period.sequenceNo}')),
          Expanded(child: Text(_date(period.dueAt))),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: MoneyText(
                money: period.amount,
                semantic: MoneySemantic.neutral,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          SizedBox(
            width: 52,
            child: Text(_periodStatusLabel(period), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.appTextStyles.formLabel)),
          Flexible(
            child: DefaultTextStyle(
              style: context.appTextStyles.formValue,
              textAlign: TextAlign.end,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPage extends StatelessWidget {
  const _StatusPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '摊销详情'),
            Expanded(child: Center(child: Text(message))),
          ],
        ),
      ),
    );
  }
}

String _kindLabel(AmortizationKind kind) => switch (kind) {
  AmortizationKind.prepaidExpense => '预付费用摊销',
  AmortizationKind.deferredIncome => '预收收入摊销',
};

String _statusLabel(AmortizationStatus status) => switch (status) {
  AmortizationStatus.active => '进行中',
  AmortizationStatus.completed => '已完成',
  AmortizationStatus.terminated => '已终止',
};

String _periodStatusLabel(AmortizationPeriod period) {
  return switch (period.status) {
    AmortizationPeriodStatus.pending => '待确认',
    AmortizationPeriodStatus.posted => '已确认',
    AmortizationPeriodStatus.zero => '零金额',
    AmortizationPeriodStatus.canceled => '已取消',
  };
}

String _categoryNames(AmortizationPlan plan, Map<String, Account> accounts) {
  return plan.currentCategoryAllocations
      .map(
        (allocation) =>
            '${accounts[allocation.accountId]?.name ?? allocation.accountId} '
            '${formatMoney(allocation.amount, style: MoneyFormatStyle.plain)}',
      )
      .join('、');
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
