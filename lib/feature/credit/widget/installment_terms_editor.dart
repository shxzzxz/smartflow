import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/time/date_label.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/installment_stage_rule.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../view_model/installment_terms_draft.dart';
import 'installment_field_options.dart';

enum InstallmentTermsEditorMode { calculator, contract, product }

/// 同一草稿承载产品规则和本笔条款，页面拥有预览、重算及保存行为。
class InstallmentTermsEditor extends StatelessWidget {
  const InstallmentTermsEditor({
    required this.value,
    required this.onChanged,
    this.mode = InstallmentTermsEditorMode.contract,
    this.borrowingDate,
    this.planAction,
    this.beforePlanAction,
    this.rulesEditable = true,
    this.usesBillingCycle = false,
    super.key,
  });
  final InstallmentTermsDraft value;
  final ValueChanged<InstallmentTermsDraft> onChanged;
  final InstallmentTermsEditorMode mode;
  final DateTime? borrowingDate;
  final AppSubmitButton? planAction;
  final Widget? beforePlanAction;
  bool get productMode => mode == InstallmentTermsEditorMode.product;
  final bool rulesEditable;

  /// 信用账户放款分期只有一个还款阶段，日期及间隔由账户账期确定。
  final bool usesBillingCycle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppFormSection(
        title: '计算约定',
        padding: _sectionPadding,
        children: [
          AppPlainSelectMenuFormRow(
            label: '标准天数',
            value: value.dayCount,
            options: dayCountConventionOptions,
            enabled: rulesEditable,
            onChanged: (v) => onChanged(value.copyWith(dayCount: v)),
          ),
          AppPlainSelectMenuFormRow(
            label: '舍入方式',
            value: value.rounding,
            options: roundingModeOptions,
            enabled: rulesEditable,
            onChanged: (v) => onChanged(value.copyWith(rounding: v)),
          ),
        ],
      ),
      for (var i = 0; i < value.stages.length; i++) ...[
        const SizedBox(height: AppSpacing.space12),
        _stage(context, value.stages[i], i),
      ],
      if (rulesEditable && !usesBillingCycle) ...[
        const SizedBox(height: AppSpacing.space12),
        LayoutBuilder(
          builder: (context, constraints) {
            final buttons = [
              OutlinedButton.icon(
                onPressed: () => onChanged(
                  value.add(
                    false,
                    borrowingDate: productMode ? null : borrowingDate,
                  ),
                ),
                icon: const Icon(RemixIcons.add_line),
                label: const Text('添加还款阶段'),
              ),
              OutlinedButton.icon(
                onPressed: () => onChanged(
                  value.add(
                    true,
                    borrowingDate: productMode ? null : borrowingDate,
                  ),
                ),
                icon: const Icon(RemixIcons.time_line),
                label: const Text('添加免还期'),
              ),
            ];
            if (constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buttons[0],
                  const SizedBox(height: AppSpacing.space8),
                  buttons[1],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: buttons[0]),
                const SizedBox(width: AppSpacing.space8),
                Expanded(child: buttons[1]),
              ],
            );
          },
        ),
      ],
      if (beforePlanAction case final child?) ...[
        const SizedBox(height: AppSpacing.space12),
        child,
      ],
      if (planAction case final action?) ...[
        const SizedBox(height: AppSpacing.space24),
        action,
      ],
    ],
  );

  Widget _stage(BuildContext context, InstallmentStageDraft s, int index) {
    void update(InstallmentStageDraft next) => onChanged(value.replace(next));
    final flat = s.method == InstallmentRepaymentMethod.flatFee;
    final custom = s.method == InstallmentRepaymentMethod.custom;
    return AppFormSection(
      key: ValueKey(s.id),
      padding: _sectionPadding,
      title: '阶段 ${index + 1} · ${s.deferment ? '免还期' : '还款阶段'}',
      trailing: rulesEditable && !usesBillingCycle
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '上移阶段',
                  onPressed: index == 0
                      ? null
                      : () => onChanged(value.move(index, index - 1)),
                  icon: const Icon(RemixIcons.arrow_up_line),
                ),
                IconButton(
                  tooltip: '下移阶段',
                  onPressed: index == value.stages.length - 1
                      ? null
                      : () => onChanged(value.move(index, index + 1)),
                  icon: const Icon(RemixIcons.arrow_down_line),
                ),
                IconButton(
                  tooltip: '删除阶段',
                  onPressed: value.stages.length <= 1
                      ? null
                      : () => onChanged(value.remove(s.id)),
                  icon: const Icon(RemixIcons.delete_bin_line),
                ),
              ],
            )
          : null,
      children: s.deferment
          ? [
              if (productMode)
                const Text('免还期间不生成还款期次；结束日期在每笔贷款中填写。')
              else
                _date(
                  context,
                  '免还至',
                  s.untilDate,
                  (d) => update(s.copyWith(untilDate: d)),
                ),
            ]
          : [
              AppPlainSelectMenuFormRow(
                label: '还款方式',
                value: s.method,
                options: mode == InstallmentTermsEditorMode.calculator
                    ? loanCalculatorRepaymentMethodOptions
                    : installmentRepaymentMethodOptions,
                enabled: rulesEditable,
                onChanged: (v) => update(s.changeMethod(v)),
              ),
              if (!productMode && !flat)
                _input(s, StageInput.periods, '期数', update, hint: '本阶段期数'),
              if (!flat)
                _input(
                  s,
                  StageInput.interval,
                  '各期间隔',
                  update,
                  enabled: rulesEditable && !usesBillingCycle,
                  hint: '每期间隔月数：1 月供，3 季供，12 年供',
                ),
              if (!productMode && usesBillingCycle)
                const AppPlainValueRow(label: '还款日期', value: '按账户账期生成'),
              if (!productMode && !usesBillingCycle)
                _date(
                  context,
                  flat ? '还款日' : '首期还款日',
                  s.firstDate,
                  (d) => update(s.copyWith(firstDate: d)),
                ),
              if (!productMode && !flat && !usesBillingCycle) ...[
                _date(
                  context,
                  '末期还款日',
                  s.lastDate,
                  (d) => update(s.copyWith(lastDate: d)),
                  placeholder: '按期数与间隔生成',
                ),
                if (s.lastDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => update(s.copyWith(lastDate: null)),
                      child: const Text('恢复自动末期日期'),
                    ),
                  ),
              ],
              if (!flat && !custom && productMode)
                AppPlainSelectMenuFormRow(
                  label: '利率单位',
                  value: s.ratePeriod,
                  options: interestRatePeriodOptions,
                  enabled: rulesEditable,
                  onChanged: (v) => update(s.copyWith(ratePeriod: v)),
                ),
              if (!flat && !custom && !productMode)
                _DraftInput(
                  key: ValueKey('${s.id}:rate'),
                  value: s.text(StageInput.rate),
                  label: '利率',
                  hint: '留空即免息',
                  enabled: true,
                  money: false,
                  ratePeriod: s.ratePeriod,
                  unitEnabled: rulesEditable,
                  onRatePeriodChanged: (v) => update(s.copyWith(ratePeriod: v)),
                  onChanged: (text) =>
                      update(s.setInput(StageInput.rate, text)),
                  validator: _validateRate,
                ),
              if (!flat && !custom)
                AppPlainSelectMenuFormRow(
                  label: '计息方式',
                  value: s.accrual,
                  options: interestAccrualMethodOptions,
                  enabled: rulesEditable,
                  onChanged: (v) => update(s.copyWith(accrual: v)),
                ),
              if (s.method == InstallmentRepaymentMethod.equalInstallment) ...[
                AppPlainSelectMenuFormRow(
                  label: '固定额算法',
                  value: s.algorithm,
                  enabled: rulesEditable,
                  options: installmentAmountAlgorithmOptions,
                  onChanged: (v) => update(s.changeAlgorithm(v)),
                ),
                if (!productMode &&
                    s.algorithm == InstallmentAmountAlgorithm.fixed)
                  _input(
                    s,
                    StageInput.fixedAmount,
                    '固定还款额',
                    update,
                    money: true,
                  ),
              ],
              if (!productMode) ...[
                _input(
                  s,
                  StageInput.endPrincipal,
                  '期末本金',
                  update,
                  money: true,
                  hint: index == value.stages.length - 1
                      ? '留空归零；填余额表示末期额外归还'
                      : s.method == InstallmentRepaymentMethod.interestFirst
                      ? '留空承接全部本金'
                      : '请填写留给下一阶段的本金',
                ),
                _input(
                  s,
                  StageInput.fee,
                  '手续费',
                  update,
                  money: true,
                  hint: flat ? '还款日一次收取（可选）' : '本阶段手续费合计，留空为 0',
                ),
              ],
            ],
    );
  }

  Widget _input(
    InstallmentStageDraft s,
    StageInput field,
    String label,
    ValueChanged<InstallmentStageDraft> update, {
    bool enabled = true,
    bool money = false,
    String? hint,
  }) => _DraftInput(
    key: ValueKey('${s.id}:${field.name}'),
    value: s.text(field),
    label: label,
    hint: hint,
    enabled: enabled,
    money: money,
    validator: field == StageInput.periods || field == StageInput.interval
        ? _validatePositiveInt
        : field == StageInput.fixedAmount
        ? validatePositiveMoneyText
        : validateOptionalNonNegativeMoneyText,
    onChanged: (text) => update(s.setInput(field, text)),
  );

  Widget _date(
    BuildContext context,
    String label,
    DateTime? date,
    ValueChanged<DateTime> onChanged, {
    String placeholder = '请选择日期',
  }) => AppPlainSelectFormRow<DateTime>(
    label: label,
    value: date,
    validator: (value) =>
        value == null && label != '末期还款日' ? '请选择$label' : null,
    placeholder: placeholder,
    valueText: date == null ? null : formatDateLabel(date),
    onTap: (selected) async {
      final picked = await showAppDatePicker(
        context: context,
        initialDate: date ?? DateTime.now(),
        title: label,
      );
      if (context.mounted && picked != null) selected(picked);
    },
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

class _DraftInput extends StatefulWidget {
  const _DraftInput({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.enabled,
    required this.money,
    this.hint,
    this.validator,
    this.ratePeriod,
    this.onRatePeriodChanged,
    this.unitEnabled = true,
    super.key,
  });
  final String value, label;
  final String? hint;
  final bool enabled, money;
  final FormFieldValidator<String>? validator;
  final InterestRatePeriod? ratePeriod;
  final ValueChanged<InterestRatePeriod>? onRatePeriodChanged;
  final bool unitEnabled;
  final ValueChanged<String> onChanged;
  @override
  State<_DraftInput> createState() => _DraftInputState();
}

class _DraftInputState extends State<_DraftInput> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _DraftInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncTextControllerText(controller, widget.value);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.ratePeriod != null
      ? ValueWithUnitPlainFormRow<InterestRatePeriod>(
          label: widget.label,
          controller: controller,
          hintText: widget.hint,
          suffixText: '%',
          unit: widget.ratePeriod!,
          unitOptions: interestRatePeriodOptions,
          unitEnabled: widget.unitEnabled,
          onUnitChanged: widget.onRatePeriodChanged!,
          onChanged: widget.onChanged,
          validator: widget.validator,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        )
      : widget.money
      ? MoneyPlainFormRow(
          label: widget.label,
          controller: controller,
          hintText: widget.hint,
          onChanged: widget.onChanged,
          validator: widget.validator,
        )
      : AppPlainIntegerFormRow(
          label: widget.label,
          controller: controller,
          hintText: widget.hint ?? '',
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          validator: widget.validator,
        );
}

const _sectionPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.space16,
  vertical: AppSpacing.space8,
);

String? _validatePositiveInt(String? value) {
  final n = int.tryParse((value ?? '').trim());
  return n == null || n <= 0 ? '必须为正整数' : null;
}

String? _validateRate(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final rate = Decimal.tryParse(text);
  return rate == null || rate < Decimal.zero ? '请输入有效的非负利率' : null;
}
