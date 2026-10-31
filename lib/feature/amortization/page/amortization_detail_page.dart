import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_segmented_control.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../../widget/business/account/account_picker_sheet.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/finance/money_text.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
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
                    icon: RemixIcons.settings_3_line,
                    tooltip: '计划配置',
                    onPressed: () => _showReportingSheet(context, state),
                  ),
                  AppHeaderIconButton(
                    icon: RemixIcons.stop_circle_line,
                    tooltip: '终止摊销',
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
                          label: '总额',
                          value: MoneyText(
                            money: state.plan.total,
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
                          label: '确认分类',
                          value: Text(
                            accounts[state.plan.categoryAccountId]?.name ??
                                '未知分类',
                          ),
                        ),
                        _ValueRow(
                          label: '下一期',
                          value: Text(
                            state.plan.nextPendingEntry == null
                                ? _statusLabel(state.plan.status)
                                : _date(state.plan.nextPendingEntry!.dueAt),
                          ),
                        ),
                        _ValueRow(
                          label: '计划配置',
                          value: Text(
                            '${state.plan.defaultIsExcludedFromStats ? '不计收支' : '计入收支'}'
                            ' · '
                            '${state.plan.defaultIsExcludedFromBudget ? '不计预算' : '计入预算'}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    AppFormSection(
                      title: '摊销进度',
                      description: '计划交易可在详情中单独调整收支和预算配置。',
                      children: [
                        for (final entry in state.plan.entries)
                          _EntryRow(entry: entry),
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

  Future<void> _showReportingSheet(
    BuildContext context,
    AmortizationDetailState state,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ReportingSheet(planId: planId, state: state),
    );
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
  late final TextEditingController _refundController;
  late final TextEditingController _feeController;
  late final TextEditingController _noteController;
  late DateTime _terminatedAt;
  late String? _refundAccountId;
  late String? _categoryId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _refundController = TextEditingController(
      text: widget.state.plan.remainingAmount.format(),
    );
    _feeController = TextEditingController();
    _noteController = TextEditingController();
    _terminatedAt = DateTime.now();
    _refundAccountId = widget.state.settlementAccounts.firstOrNull?.id;
    _categoryId = widget.state.plan.categoryAccountId;
  }

  @override
  void dispose() {
    _refundController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              Text('终止摊销', style: context.appTextStyles.subsectionTitle),
              const SizedBox(height: AppSpacing.space16),
              MoneyPlainFormRow(
                label: '实际退款',
                controller: _refundController,
                hintText: '0.00',
                requiredIndicator: true,
                validator: validateNonNegativeMoneyText,
              ),
              MoneyPlainFormRow(
                label: '退款手续费',
                controller: _feeController,
                hintText: '0.00',
                validator: validateOptionalNonNegativeMoneyText,
              ),
              AccountPlainFormRow(
                label: '退款账户',
                account: findAccountById(
                  _refundAccountId,
                  widget.state.settlementAccounts,
                ),
                placeholder: '请选择退款账户',
                onTap: (onSelected) async {
                  final selected = await showAccountPickerSheet(
                    context: context,
                    accounts: widget.state.settlementAccounts,
                    selectedId: _refundAccountId,
                  );
                  if (selected == null) return;
                  onSelected(selected);
                  setState(() => _refundAccountId = selected);
                },
              ),
              DateTimePlainFormRow(
                label: '终止日期',
                dateTime: _terminatedAt,
                value: _date(_terminatedAt),
                onTap: (onSelected) async {
                  final selected = await showAppDatePicker(
                    context: context,
                    initialDate: _terminatedAt,
                  );
                  if (selected == null) return;
                  onSelected(selected);
                  setState(() => _terminatedAt = selected);
                },
                onChanged: (_) {},
                showChevron: true,
              ),
              NotePlainFormRow(controller: _noteController),
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
    final refundAccountId = _refundAccountId;
    if (refundAccountId == null) {
      _showMessage('请选择退款账户');
      return;
    }
    setState(() => _submitting = true);
    final outcome = await ref
        .read(amortizationDetailViewModelProvider(widget.planId).notifier)
        .terminate(
          terminatedAt: _terminatedAt,
          refundAccountId: refundAccountId,
          refundAmountText: _refundController.text,
          feeText: _feeController.text,
          categoryAccountId: _categoryId,
          noteText: _noteController.text,
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

class _ReportingSheet extends ConsumerStatefulWidget {
  const _ReportingSheet({required this.planId, required this.state});

  final String planId;
  final AmortizationDetailState state;

  @override
  ConsumerState<_ReportingSheet> createState() => _ReportingSheetState();
}

class _ReportingSheetState extends ConsumerState<_ReportingSheet> {
  late bool _excludeStats;
  late bool _excludeBudget;
  var _scope = AmortizationReportingScope.futureOnly;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _excludeStats = widget.state.plan.defaultIsExcludedFromStats;
    _excludeBudget = widget.state.plan.defaultIsExcludedFromBudget;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          0,
          AppSpacing.space16,
          AppSpacing.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('计划配置', style: context.appTextStyles.subsectionTitle),
            const SizedBox(height: AppSpacing.space12),
            AppFormSection(
              children: [
                AppPlainSwitchRow(
                  label: '默认不计收支',
                  value: _excludeStats,
                  onChanged: (value) => setState(() => _excludeStats = value),
                ),
                AppPlainSwitchRow(
                  label: '默认不计预算',
                  value: _excludeBudget,
                  onChanged: (value) => setState(() => _excludeBudget = value),
                ),
                AppPlainSegmentedFormRow<AmortizationReportingScope>(
                  label: '应用范围',
                  value: _scope,
                  segments: const [
                    AppSegment(
                      value: AmortizationReportingScope.futureOnly,
                      label: '仅未来',
                    ),
                    AppSegment(
                      value: AmortizationReportingScope.all,
                      label: '整组',
                    ),
                  ],
                  onChanged: (value) => setState(() => _scope = value),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space12),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存配置'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final outcome = await ref
        .read(amortizationDetailViewModelProvider(widget.planId).notifier)
        .updateDefaults(
          isExcludedFromStats: _excludeStats,
          isExcludedFromBudget: _excludeBudget,
          scope: _scope,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (outcome) {
      case UiActionSuccess():
        Navigator.of(context).pop();
      case UiActionFailure(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final AmortizationEntry entry;

  @override
  Widget build(BuildContext context) {
    final status = entry.isCanceled
        ? '已取消'
        : entry.isGenerated
        ? '已确认'
        : '待确认';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space8),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('${entry.sequenceNo}')),
          Expanded(child: Text(_date(entry.dueAt))),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: MoneyText(
                money: entry.amount,
                semantic: MoneySemantic.neutral,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space12),
          SizedBox(width: 52, child: Text(status, textAlign: TextAlign.end)),
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

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
