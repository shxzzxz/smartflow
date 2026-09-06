import 'package:flutter/material.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_select.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/installment_stage_rule.dart';
import '../../../widget/business/finance/money_input.dart';
import '../view_model/installment_terms_draft.dart';
import 'installment_field_options.dart';

/// 产品只展示稳定规则；合同额外展示本笔参数，规则由开关解锁。
class InstallmentTermsEditor extends StatelessWidget {
  const InstallmentTermsEditor({
    required this.value,
    required this.onChanged,
    this.productMode = false,
    this.rulesEditable = true,
    super.key,
  });
  final InstallmentTermsDraft value;
  final ValueChanged<InstallmentTermsDraft> onChanged;
  final bool productMode;
  final bool rulesEditable;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppFormSection(
        title: '计算约定',
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
      if (rulesEditable)
        Wrap(
          spacing: AppSpacing.space8,
          children: [
            TextButton.icon(
              onPressed: () => onChanged(value.add(false)),
              icon: const Icon(Icons.add),
              label: const Text('添加还款阶段'),
            ),
            TextButton.icon(
              onPressed: () => onChanged(value.add(true)),
              icon: const Icon(Icons.add),
              label: const Text('添加免还阶段'),
            ),
          ],
        ),
    ],
  );

  Widget _stage(BuildContext context, InstallmentStageDraft s, int index) {
    void update(InstallmentStageDraft next) => onChanged(value.replace(next));
    final flat = s.method == InstallmentRepaymentMethod.flatFee;
    return AppFormSection(
      key: ValueKey(s.id),
      title: '阶段 ${index + 1} · ${s.deferment ? '免还期' : '还款阶段'}',
      trailing: rulesEditable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '上移阶段',
                  onPressed: index == 0
                      ? null
                      : () => onChanged(value.move(index, index - 1)),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: '下移阶段',
                  onPressed: index == value.stages.length - 1
                      ? null
                      : () => onChanged(value.move(index, index + 1)),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: '删除阶段',
                  onPressed: value.stages.length <= 1
                      ? null
                      : () => onChanged(value.remove(s.id)),
                  icon: const Icon(Icons.delete_outline),
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
                  '免还结束日',
                  s.untilDate,
                  (d) => update(s.copyWith(untilDate: d)),
                ),
            ]
          : [
              AppPlainSelectMenuFormRow(
                label: '还款方式',
                value: s.method,
                options: installmentRepaymentMethodOptions,
                enabled: rulesEditable,
                onChanged: (v) => update(
                  s.copyWith(
                    method: v,
                    inputs: {
                      ...s.inputs,
                      if (v == InstallmentRepaymentMethod.flatFee)
                        StageInput.rate: '',
                      if (v != InstallmentRepaymentMethod.equalInstallment)
                        StageInput.fixedAmount: '',
                    },
                  ),
                ),
              ),
              if (!flat)
                _input(
                  s,
                  StageInput.interval,
                  '各期间隔（月）',
                  update,
                  enabled: rulesEditable,
                  hint: '1 月供，3 季供，12 年供',
                ),
              if (!productMode && !flat)
                _input(s, StageInput.periods, '期数', update),
              if (!productMode)
                _date(
                  context,
                  flat ? '还款日' : '首期还款日',
                  s.firstDate,
                  (d) => update(s.copyWith(firstDate: d)),
                ),
              if (!productMode && !flat) ...[
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
              if (!flat)
                AppPlainSelectMenuFormRow(
                  label: '利率单位',
                  value: s.ratePeriod,
                  options: interestRatePeriodOptions,
                  enabled: rulesEditable,
                  onChanged: (v) => update(s.copyWith(ratePeriod: v)),
                ),
              if (!productMode && !flat)
                _input(s, StageInput.rate, '利率（%）', update, hint: '留空即免息'),
              if (!flat)
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
                  options: const [
                    AppSelectOption(
                      value: InstallmentAmountAlgorithm.nominalRate,
                      label: '固定名义期利率',
                    ),
                    AppSelectOption(
                      value: InstallmentAmountAlgorithm.actualRate,
                      label: '动态实际期利率',
                    ),
                    AppSelectOption(
                      value: InstallmentAmountAlgorithm.fixed,
                      label: '指定固定额',
                    ),
                  ],
                  onChanged: (v) => update(
                    s.copyWith(
                      algorithm: v,
                      inputs: {
                        ...s.inputs,
                        if (v != InstallmentAmountAlgorithm.fixed)
                          StageInput.fixedAmount: '',
                      },
                    ),
                  ),
                ),
                if (!productMode &&
                    s.algorithm == InstallmentAmountAlgorithm.fixed)
                  _input(
                    s,
                    StageInput.fixedAmount,
                    '指定固定额',
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
                  hint: '留空为 0',
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
    placeholder: placeholder,
    valueText: date == null ? null : formatDateLabel(date),
    onTap: (selected) async {
      final picked = await showAppDatePicker(
        context: context,
        initialDate: date ?? DateTime.now(),
        title: label,
      );
      if (picked != null) selected(picked);
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
    super.key,
  });
  final String value, label;
  final String? hint;
  final bool enabled, money;
  final ValueChanged<String> onChanged;
  @override
  State<_DraftInput> createState() => _DraftInputState();
}

class _DraftInputState extends State<_DraftInput> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _DraftInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) controller.text = widget.value;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.money
      ? MoneyPlainFormRow(
          label: widget.label,
          controller: controller,
          hintText: widget.hint,
          onChanged: widget.onChanged,
          validator: validateOptionalNonNegativeMoneyText,
        )
      : AppPlainTextFormRow(
          label: widget.label,
          controller: controller,
          hintText: widget.hint,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );
}
