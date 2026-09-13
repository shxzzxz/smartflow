import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../shared/presentation/reference_rate_presentation.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_operations_view_model.dart';

class InstallmentOperationsPage extends ConsumerWidget {
  const InstallmentOperationsPage({required this.contractId, super.key});
  final String contractId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(installmentOperationsViewModelProvider(contractId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '利率与利息调整'),
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
        AppFormSection(
          title: '重定价配置历史',
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: state.busy
                    ? null
                    : () => _edit(
                        context,
                        ref,
                        contract,
                        _OperationKind.configuration,
                      ),
                icon: const Icon(Icons.add),
                label: const Text('新增配置'),
              ),
            ),
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
                  '首次重定价 ${formatDateLabel(configuration.rule.firstResetDate)}，首次生效 ${formatDateLabel(configuration.rule.firstEffectiveDate)}',
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        AppFormSection(
          title: '重定价记录',
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: state.busy
                    ? null
                    : () => _edit(
                        context,
                        ref,
                        contract,
                        _OperationKind.repricing,
                      ),
                icon: const Icon(Icons.add),
                label: const Text('新增重定价'),
              ),
            ),
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
                  icon: const Icon(Icons.delete_outline),
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
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        AppFormSection(
          title: '利息调整',
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: state.busy
                    ? null
                    : () => _edit(
                        context,
                        ref,
                        contract,
                        _OperationKind.adjustment,
                      ),
                icon: const Icon(Icons.add),
                label: const Text('新增利息调整'),
              ),
            ),
            const Text('0% 免息，100% 保持原利息，120% 增加 20%。区间包含开始日，不包含结束日。'),
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
                  icon: const Icon(Icons.delete_outline),
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
          ],
        ),
      ],
    );
  }

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
  var _type = ReferenceRateType.lprFiveYearPlus;
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
    _type = config?.rule.referenceRateType ?? ReferenceRateType.lprFiveYearPlus;
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
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.kind != _OperationKind.adjustment) ...[
                AppDropdownFormField<String>(
                  labelText: '所属阶段',
                  value: _stageId,
                  items: [
                    for (final stage in widget.contract.stageTerms.stages)
                      if (stage.terms is AmortizingStage)
                        DropdownMenuItem(
                          value: stage.id,
                          child: Text(_stageLabel(widget.contract, stage.id)),
                        ),
                  ],
                  enabled: !_submitting,
                  onChanged: (value) {
                    if (value != null) setState(() => _selectStage(value));
                  },
                ),
                const SizedBox(height: AppSpacing.space12),
                const Text('重定价仅影响所选阶段。'),
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
                AppDropdownFormField<ReferenceRateType>(
                  labelText: '参考利率类型',
                  value: _type,
                  items: [
                    for (final type in ReferenceRateType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(referenceRateTypeLabel(type)),
                      ),
                  ],
                  enabled: !_submitting,
                  onChanged: (type) {
                    if (type != null) setState(() => _type = type);
                  },
                ),
                const SizedBox(height: AppSpacing.space12),
                if (widget.kind == _OperationKind.configuration) ...[
                  AppDropdownFormField<int>(
                    labelText: '重定价周期',
                    value: _cycle,
                    items: [
                      for (final months in [3, 6, 12])
                        DropdownMenuItem(
                          value: months,
                          child: Text('$months 个月'),
                        ),
                    ],
                    enabled: !_submitting,
                    onChanged: (months) {
                      if (months != null) setState(() => _cycle = months);
                    },
                  ),
                  const SizedBox(height: AppSpacing.space12),
                ],
                AppTextFormField(
                  controller: _number,
                  labelText: '加减基点（BP）',
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
              ],
              if (widget.kind == _OperationKind.repricing)
                const Text('引用所选类型中严格早于重定价日的最近参考利率，加上基点确定执行利率。'),
              if (widget.kind == _OperationKind.adjustment) ...[
                _dateField('开始日期（包含）', _start, (date) => _start = date),
                _dateField('结束日期（不含）', _end, (date) => _end = date),
                AppTextFormField(
                  controller: _number,
                  labelText: '利息比例（%）',
                  validator: _validatePercent,
                  enabled: !_submitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.space12),
                const Text('区间不能重叠。按月、按年计息时，需要选择完整计息单位。'),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.space12),
                  child: Text(
                    _error!,
                    style: TextStyle(
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

  Widget _dateField(
    String label,
    DateTime value,
    ValueChanged<DateTime> changed,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(formatDateLabel(value)),
    trailing: const Icon(Icons.calendar_today_outlined),
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
