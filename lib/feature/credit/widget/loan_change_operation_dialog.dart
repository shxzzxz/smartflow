import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_select.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../shared/presentation/reference_rate_presentation.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/loan_calculator_presentation.dart';
import '../presentation/loan_change_presentation.dart';
import '../view_model/loan_change_state.dart';
import '../view_model/loan_change_view_model.dart';

class LoanChangeOperationDialog extends StatefulWidget {
  const LoanChangeOperationDialog({
    required this.state,
    required this.notifier,
    required this.kind,
    this.initial,
    super.key,
  });
  final LoanChangeState state;
  final LoanChangeViewModel notifier;
  final LoanChangeOperationKind kind;
  final LoanChangeOperation? initial;

  @override
  State<LoanChangeOperationDialog> createState() =>
      _LoanChangeOperationDialogState();
}

class _LoanChangeOperationDialogState extends State<LoanChangeOperationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _referenceRate = TextEditingController();
  final _spread = TextEditingController(text: '0');
  late DateTime _start, _end;
  String? _stageId;
  var _type = InterestRateType.lprFiveYearPlus;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final configuration = widget.state.configuration!;
    _start = configuration.borrowingDate;
    _end = configuration.calculation.periods.first.date;
    if (widget.kind == LoanChangeOperationKind.repricing &&
        widget.state.repricingStages.isNotEmpty) {
      _selectStage(widget.state.repricingStages.first.id);
    }
    if (widget.kind == LoanChangeOperationKind.interestAdjustment) {
      _number.text = '100';
    }
    switch (widget.initial) {
      case LoanPrepaymentOperation(:final reduction):
        _start = reduction.date;
        _number.text = reduction.principal.format();
      case LoanRepricingOperation(:final stageId, :final change):
        if (widget.state.repricingStages.any((stage) => stage.id == stageId)) {
          _stageId = stageId;
        }
        _start = change.resetDate;
        _end = change.effectiveDate;
        _type = change.referenceRate.type;
        _referenceRate.text = formatLoanChangePercent(
          change.referenceRate.ratePpm,
        );
        _spread.text = '${change.spreadBp}';
      case LoanInterestAdjustmentOperation(:final adjustment):
        _start = adjustment.start;
        _end = adjustment.end;
        _number.text = formatLoanChangePercent(adjustment.ratioPpm);
      case null:
        break;
    }
  }

  void _selectStage(String id) {
    _stageId = id;
    final configuration = widget.state.configuration!;
    final range = configuration.terms.contractTerms().repaymentRange(
      id,
      configuration.borrowingDate,
    );
    _start = range.start;
    _end = range.start;
    final stage = widget.state.repricingStages.firstWhere(
      (stage) => stage.id == id,
    );
    _type = stage.rateType.isFloating
        ? stage.rateType
        : InterestRateType.lprFiveYearPlus;
  }

  @override
  void dispose() {
    _number.dispose();
    _referenceRate.dispose();
    _spread.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final title =
        '${widget.initial == null ? '添加' : '编辑'}${loanChangeOperationLabel(kind)}';
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
              if (kind == LoanChangeOperationKind.prepayment) ...[
                _dateField('提前还款日', _start, (date) => _start = date),
                _field(
                  '提前还本金',
                  AppTextFormField(
                    key: const ValueKey('operation-principal'),
                    controller: _number,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [moneyInputFormatter],
                    validator: validatePositiveMoneyText,
                  ),
                ),
              ],
              if (kind == LoanChangeOperationKind.repricing) ...[
                if (_stageId == null)
                  const Text('暂无支持重定价的还款阶段，请先修改贷款配置。')
                else
                  _selectField<String>(
                    label: '所属阶段',
                    value: _stageId!,
                    options: [
                      for (final stage in widget.state.repricingStages)
                        AppSelectOption(
                          value: stage.id,
                          label:
                              '阶段 ${widget.state.configuration!.terms.stages.indexWhere((value) => value.id == stage.id) + 1} · ${loanRepaymentMethodLabel(stage.method)}',
                        ),
                    ],
                    onChanged: _selectStage,
                  ),
                _dateField('重定价日', _start, (date) => _start = date),
                _dateField('重定价生效日', _end, (date) => _end = date),
                _selectField<InterestRateType>(
                  label: '参考利率类型',
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
                _field(
                  '试算参考年利率（%）',
                  AppTextFormField(
                    key: const ValueKey('operation-reference-rate'),
                    controller: _referenceRate,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (text) =>
                        validateLoanChangePercent(text, label: '试算参考利率'),
                  ),
                ),
                _field(
                  '加减基点（BP）',
                  AppTextFormField(
                    key: const ValueKey('operation-spread'),
                    controller: _spread,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    validator: (text) =>
                        int.tryParse(text?.trim() ?? '') == null
                        ? '请输入整数基点，可为负数'
                        : null,
                  ),
                ),
                Text(
                  '填写本次假设的参考利率，加减基点后确定执行年利率。',
                  style: context.appTextStyles.formSupporting,
                ),
              ],
              if (kind == LoanChangeOperationKind.interestAdjustment) ...[
                _dateField('开始日期', _start, (date) => _start = date),
                _dateField('结束日期', _end, (date) => _end = date),
                _field(
                  '利息比例（%）',
                  AppTextFormField(
                    key: const ValueKey('operation-interest-percent'),
                    controller: _number,
                    enabled: !_submitting,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: validateLoanChangePercent,
                  ),
                ),
                Text(
                  '不含开始日、包含结束日。0% 免息，50% 减半，100% 不变，120% 增加 20%。',
                  style: context.appTextStyles.formSupporting,
                ),
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
          onPressed:
              _submitting ||
                  (kind == LoanChangeOperationKind.repricing &&
                      _stageId == null)
              ? null
              : _submit,
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

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final notifier = widget.notifier;
    final outcome = await switch (widget.kind) {
      LoanChangeOperationKind.prepayment => notifier.savePrepayment(
        id: widget.initial?.id,
        date: _start,
        principalText: _number.text,
      ),
      LoanChangeOperationKind.repricing => notifier.saveRepricing(
        id: widget.initial?.id,
        stageId: _stageId!,
        resetDate: _start,
        effectiveDate: _end,
        referenceRateType: _type,
        referenceRateText: _referenceRate.text,
        spreadBpText: _spread.text,
      ),
      LoanChangeOperationKind.interestAdjustment =>
        notifier.saveInterestAdjustment(
          id: widget.initial?.id,
          start: _start,
          end: _end,
          percentText: _number.text,
        ),
    };
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
