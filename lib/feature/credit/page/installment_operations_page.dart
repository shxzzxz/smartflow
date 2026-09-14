import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_select.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../shared/presentation/reference_rate_presentation.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_operations_view_model.dart';

class InstallmentRepricingPage extends _InstallmentOperationsPage {
  const InstallmentRepricingPage({required super.contractId, super.key})
    : super(interestAdjustments: false);
}

class InstallmentInterestAdjustmentsPage extends _InstallmentOperationsPage {
  const InstallmentInterestAdjustmentsPage({
    required super.contractId,
    super.key,
  }) : super(interestAdjustments: true);
}

class _InstallmentOperationsPage extends ConsumerWidget {
  const _InstallmentOperationsPage({
    required this.contractId,
    required this.interestAdjustments,
    super.key,
  });
  final String contractId;
  final bool interestAdjustments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(installmentOperationsViewModelProvider(contractId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: interestAdjustments ? '利息调整' : '重定价'),
            Expanded(
              child: switch (value) {
                AsyncData(:final value) =>
                  value.contract == null
                      ? const Center(child: Text('合同不存在'))
                      : _body(context, ref, value),
                AsyncError() => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(
                      installmentOperationsViewModelProvider(contractId),
                    ),
                    child: const Text('加载失败，点击重试'),
                  ),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    InstallmentOperationsState state,
  ) {
    final contract = state.contract!;
    final notifier = ref.read(
      installmentOperationsViewModelProvider(contractId).notifier,
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space16),
      children: [
        if (contract.stageTerms.isCustom) ...[
          const Text('自定义合同的还款计划由你手动维护，以下记录不会自动修改计划。'),
          const SizedBox(height: AppSpacing.space12),
        ],
        if (!interestAdjustments) ...[
          AppFormSection(
            title: '重定价配置',
            children: [
              if (contract.repricingConfigurations.isEmpty)
                const Text('尚未设置重定价配置'),
              for (final configuration in contract.repricingConfigurations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${_stageLabel(contract, configuration.stageId)} · ${formatDateLabel(configuration.effectiveFrom)} 起生效',
                  ),
                  subtitle: Text(
                    '${referenceRateTypeLabel(configuration.rule.referenceRateType)} · ${configuration.rule.spreadBp} BP · 每 ${configuration.rule.cycleMonths} 个月\n'
                    '首次重定价日 ${formatDateLabel(configuration.rule.firstResetDate)}，首次生效 ${formatDateLabel(configuration.rule.firstEffectiveDate)}',
                  ),
                  trailing: IconButton(
                    tooltip: '删除重定价配置',
                    icon: const Icon(RemixIcons.delete_bin_line),
                    onPressed: state.busy
                        ? null
                        : () => _delete(
                            context,
                            '删除重定价配置',
                            '删除后不再按此配置自动生成重定价。已生成的重定价记录和还款计划会保留。',
                            () =>
                                notifier.deleteConfiguration(configuration.id),
                          ),
                  ),
                ),
              const SizedBox(height: AppSpacing.space12),
              _addButton(
                label: '新增配置',
                onPressed: state.busy
                    ? null
                    : () => _edit(
                        context,
                        ref,
                        contract,
                        _OperationKind.configuration,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space12),
          AppFormSection(
            title: '重定价记录',
            children: [
              if (contract.repricings.isEmpty) const Text('暂无重定价记录'),
              for (final record in contract.repricings)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${_stageLabel(contract, record.stageId)} · ${formatDateLabel(record.change.effectiveDate)} 起 · 年利率 ${_percent(record.change.rate.ppm)}%',
                  ),
                  subtitle: Text(
                    '重定价日 ${formatDateLabel(record.change.resetDate)}\n${referenceRateTypeLabel(record.change.referenceRate.type)} ${_percent(record.change.referenceRate.ratePpm)}% · ${record.change.spreadBp} BP',
                  ),
                  trailing: IconButton(
                    tooltip: '删除重定价',
                    icon: const Icon(RemixIcons.delete_bin_line),
                    onPressed: state.busy
                        ? null
                        : () => _delete(
                            context,
                            '删除重定价',
                            '删除后按剩余重定价记录重新计算计划。',
                            () => notifier.deleteRepricing(record.id),
                          ),
                  ),
                ),
              const SizedBox(height: AppSpacing.space12),
              _addButton(
                label: '新增重定价',
                onPressed: state.busy
                    ? null
                    : () => _edit(
                        context,
                        ref,
                        contract,
                        _OperationKind.repricing,
                      ),
              ),
            ],
          ),
        ],
        if (interestAdjustments)
          AppFormSection(
            title: '利息调整记录',
            children: [
              if (contract.interestAdjustments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.space12),
                  child: Text('暂无利息调整'),
                ),
              for (final record in contract.interestAdjustments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${formatDateLabel(record.adjustment.start)} — ${formatDateLabel(record.adjustment.end)}',
                  ),
                  subtitle: Text(
                    '利息比例 ${_percent(record.adjustment.ratioPpm)}% · 点击修改',
                  ),
                  onTap: state.busy
                      ? null
                      : () => _edit(
                          context,
                          ref,
                          contract,
                          _OperationKind.adjustment,
                          adjustment: record,
                        ),
                  trailing: IconButton(
                    tooltip: '删除利息调整',
                    icon: const Icon(RemixIcons.delete_bin_line),
                    onPressed: state.busy
                        ? null
                        : () => _delete(
                            context,
                            '删除利息调整',
                            '删除后按剩余有效记录重新计算计划。',
                            () => notifier.deleteAdjustment(record.id),
                          ),
                  ),
                ),
              const SizedBox(height: AppSpacing.space12),
              _addButton(
                label: '新增利息调整',
                onPressed: state.busy
                    ? null
                    : () => _edit(
                        context,
                        ref,
                        contract,
                        _OperationKind.adjustment,
                      ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _addButton({
    required String label,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(RemixIcons.add_line),
      label: Text(label),
    ),
  );

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    InstallmentContractReadModel contract,
    _OperationKind kind, {
    InstallmentInterestAdjustmentReadModel? adjustment,
  }) => showDialog<void>(
    context: context,
    builder: (_) => _OperationDialog(
      contract: contract,
      kind: kind,
      adjustment: adjustment,
      submit: (input) => ref
          .read(installmentOperationsViewModelProvider(contractId).notifier)
          .submit(input),
    ),
  );

  Future<void> _delete(
    BuildContext context,
    String title,
    String message,
    Future<UiActionOutcome<void>> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final outcome = await action();
    if (context.mounted && outcome is UiActionFailure<void>) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(outcome.error.message)));
    }
  }
}

enum _OperationKind { configuration, repricing, adjustment }

class _OperationDialog extends StatefulWidget {
  const _OperationDialog({
    required this.contract,
    required this.kind,
    required this.submit,
    this.adjustment,
  });
  final InstallmentContractReadModel contract;
  final _OperationKind kind;
  final InstallmentInterestAdjustmentReadModel? adjustment;
  final Future<UiActionOutcome<void>> Function(InstallmentOperationInput)
  submit;

  @override
  State<_OperationDialog> createState() => _OperationDialogState();
}

class _OperationDialogState extends State<_OperationDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _start, _reset, _end;
  late final TextEditingController _number;
  late String _stageId;
  var _type = InterestRateType.lprFiveYearPlus;
  var _cycle = 12;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final contract = widget.contract;
    _stageId = contract.stageTerms.stages
        .firstWhere((stage) => stage.terms is AmortizingStage)
        .id;
    _start = widget.adjustment?.adjustment.start ?? contract.borrowingDate;
    _end = widget.adjustment?.adjustment.end ?? contract.firstRepaymentDate;
    _reset = contract.borrowingDate;
    final number = widget.kind == _OperationKind.adjustment
        ? _percent(widget.adjustment?.adjustment.ratioPpm ?? 1000000)
        : '0';
    _number = TextEditingController(text: number);
    if (widget.kind != _OperationKind.adjustment) _selectStage(_stageId);
  }

  void _selectStage(String stageId) {
    _stageId = stageId;
    final contract = widget.contract;
    final range = contract.stageTerms.repaymentRange(
      stageId,
      contract.borrowingDate,
    );
    final config = contract.repricingConfigurations
        .where((value) => value.stageId == stageId)
        .lastOrNull;
    final now = referenceDate(DateTime.now());
    _start =
        config != null && !now.isBefore(range.start) && now.isBefore(range.end)
        ? now
        : range.start;
    _reset = _start;
    _end = _start;
    _type = config?.rule.referenceRateType ?? InterestRateType.lprFiveYearPlus;
    _cycle = config?.rule.cycleMonths ?? 12;
    _number.text = '${config?.rule.spreadBp ?? 0}';
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      _OperationKind.configuration => '新增重定价配置',
      _OperationKind.repricing => '新增重定价记录',
      _OperationKind.adjustment =>
        widget.adjustment == null ? '新增利息调整' : '修改利息调整',
    };
    return AlertDialog(
      title: Text(title),
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space16,
        vertical: AppSpacing.space24,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.kind != _OperationKind.adjustment) ...[
                _selectField<String>(
                  label: '所属阶段',
                  value: _stageId,
                  options: [
                    for (final stage in widget.contract.stageTerms.stages)
                      if (stage.terms is AmortizingStage)
                        AppSelectOption(
                          value: stage.id,
                          label: _stageLabel(widget.contract, stage.id),
                        ),
                  ],
                  onChanged: _selectStage,
                ),
              ],
              if (widget.kind == _OperationKind.configuration) ...[
                _dateField('配置生效日', _start, (date) => _start = date),
                _dateField('首次重定价日', _reset, (date) => _reset = date),
                _dateField('首次生效日', _end, (date) => _end = date),
              ],
              if (widget.kind == _OperationKind.repricing) ...[
                _dateField('重定价日', _reset, (date) => _reset = date),
                _dateField('重定价生效日', _end, (date) => _end = date),
              ],
              if (widget.kind != _OperationKind.adjustment) ...[
                _selectField<InterestRateType>(
                  label: '利率类型',
                  value: _type,
                  options: [
                    for (final type in InterestRateType.referenceTypes)
                      AppSelectOption(
                        value: type,
                        label: referenceRateTypeLabel(type),
                      ),
                  ],
                  onChanged: (type) => _type = type,
                ),
                if (widget.kind == _OperationKind.configuration) ...[
                  _selectField<int>(
                    label: '重定价周期',
                    value: _cycle,
                    options: [
                      for (final months in [3, 6, 12])
                        AppSelectOption(value: months, label: '$months 个月'),
                    ],
                    onChanged: (months) => _cycle = months,
                  ),
                ],
                _field(
                  '加减基点（BP）',
                  AppTextFormField(
                    controller: _number,
                    validator: (value) =>
                        int.tryParse(value?.trim() ?? '') == null
                        ? '请输入整数基点，可为负数'
                        : null,
                    hintText: '例如 -30',
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                  ),
                ),
              ],
              if (widget.kind == _OperationKind.repricing)
                _supporting('引用重定价日前的最近参考利率，加减基点后确定执行利率。'),
              if (widget.kind == _OperationKind.adjustment) ...[
                _dateField('开始日期', _start, (date) => _start = date),
                _dateField('结束日期', _end, (date) => _end = date),
                _field(
                  '利息比例（%）',
                  AppTextFormField(
                    controller: _number,
                    validator: _validatePercent,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                _supporting('0% 免息，100% 保持原利息，120% 增加 20%。'),
                const SizedBox(height: AppSpacing.space8),
                _supporting('不包含开始日，包含结束日。区间不能重叠；按月、按年计息时需覆盖完整计息单位。'),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space12),
                  child: Text(
                    _error!,
                    style: context.appTextStyles.formSupporting.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '保存中…' : '保存'),
        ),
      ],
    );
  }

  Widget _field(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.space16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: context.appTextStyles.formLabel),
        const SizedBox(height: AppSpacing.space8),
        child,
      ],
    ),
  );

  Widget _supporting(String text) =>
      Text(text, style: context.appTextStyles.formSupporting);

  Widget _selectionValue(String value, IconData icon) => InputDecorator(
    decoration: appFormInputDecoration(context).copyWith(enabled: !_submitting),
    child: Row(
      children: [
        Expanded(child: Text(value, style: context.appTextStyles.formValue)),
        const SizedBox(width: AppSpacing.space8),
        Icon(
          icon,
          size: AppSpacing.space20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    ),
  );

  Widget _selectField<T>({
    required String label,
    required T value,
    required List<AppSelectOption<T>> options,
    required ValueChanged<T> onChanged,
  }) => _field(
    label,
    ExcludeFocus(
      excluding: _submitting,
      child: IgnorePointer(
        ignoring: _submitting,
        child: AppSelectMenu<T>(
          tooltip: label,
          value: value,
          options: options,
          onChanged: (value) => setState(() => onChanged(value)),
          triggerBuilder: (context, selected) =>
              _selectionValue(selected.label, RemixIcons.arrow_down_s_line),
        ),
      ),
    ),
  );

  Widget _dateField(
    String label,
    DateTime value,
    ValueChanged<DateTime> changed,
  ) => _field(
    label,
    InkWell(
      onTap: _submitting
          ? null
          : () async {
              final date = await showAppDatePicker(
                context: context,
                initialDate: value,
                title: label,
              );
              if (date != null && mounted) setState(() => changed(date));
            },
      child: _selectionValue(formatDateLabel(value), RemixIcons.calendar_line),
    ),
  );

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final InstallmentOperationInput input = switch (widget.kind) {
      _OperationKind.configuration => RepricingConfigurationInput(
        stageId: _stageId,
        effectiveFrom: _start,
        firstResetDate: _reset,
        firstEffectiveDate: _end,
        referenceRateType: _type,
        cycleMonths: _cycle,
        spreadBp: _number.text,
      ),
      _OperationKind.repricing => RepricingRecordInput(
        stageId: _stageId,
        resetDate: _reset,
        effectiveDate: _end,
        referenceRateType: _type,
        spreadBp: _number.text,
      ),
      _OperationKind.adjustment => InterestAdjustmentInput(
        id: widget.adjustment?.id,
        start: _start,
        end: _end,
        percent: _number.text,
      ),
    };
    final outcome = await widget.submit(input);
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess<void>():
        Navigator.of(context).pop();
      case UiActionFailure<void>(:final error):
        setState(() {
          _submitting = false;
          _error = error.message;
        });
    }
  }
}

String? _validatePercent(String? value) {
  final percent = Decimal.tryParse(value?.trim() ?? '');
  if (percent == null || percent < Decimal.zero) return '请输入非负利息比例';
  final scaled = percent * Decimal.fromInt(10000);
  return scaled == scaled.round() ? null : '利息比例最多保留四位小数';
}

String _percent(int ppm) =>
    (Decimal.fromInt(ppm) * Decimal.parse('0.0001')).toString();

String _stageLabel(InstallmentContractReadModel contract, String stageId) =>
    '阶段 ${contract.stageTerms.stages.indexWhere((stage) => stage.id == stageId) + 1}';
