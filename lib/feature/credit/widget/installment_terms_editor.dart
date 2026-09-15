import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/motion.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../domain/credit/valobj/installment_enums.dart';
import '../../../domain/credit/valobj/installment_stage_rule.dart';
import '../../../domain/credit/valobj/floating_rate.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../../domain/credit/valobj/tail_difference_policy.dart';
import '../../../design_system/widget/app_select.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../view_model/installment_terms_draft.dart';
import '../../shared/presentation/reference_rate_presentation.dart';
import 'installment_field_options.dart';
import 'installment_stage_card.dart';
import '../presentation/installment_stage_presentation.dart';

enum InstallmentTermsEditorMode { calculator, contract, product }

/// 同一草稿承载产品规则和本笔条款，页面拥有预览、重算及保存行为。
class InstallmentTermsEditor extends StatefulWidget {
  const InstallmentTermsEditor({
    required this.value,
    required this.onChanged,
    this.mode = InstallmentTermsEditorMode.contract,
    this.borrowingDate,
    this.planAction,
    this.beforePlanAction,
    this.rulesEditable = true,
    this.showAdvanced = true,
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

  /// 在基础字段之外展示计算约定和高级策略，不修改草稿或隐藏基础信息。
  final bool showAdvanced;

  @override
  State<InstallmentTermsEditor> createState() => _InstallmentTermsEditorState();
}

class _InstallmentTermsEditorState extends State<InstallmentTermsEditor> {
  final _expanded = <String>{};
  final _stageKeys = <String, GlobalKey>{};
  final _invalidFields = <String, BuildContext>{};
  bool _validationScheduled = false;

  InstallmentTermsDraft get value => widget.value;
  ValueChanged<InstallmentTermsDraft> get onChanged => widget.onChanged;
  InstallmentTermsEditorMode get mode => widget.mode;
  bool get productMode => widget.productMode;
  bool get rulesEditable => widget.rulesEditable;
  DateTime? get borrowingDate => widget.borrowingDate;

  @override
  void initState() {
    super.initState();
    if (value.stages.isNotEmpty) _expanded.add(value.stages.first.id);
  }

  @override
  void didUpdateWidget(covariant InstallmentTermsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = value.stages.map((s) => s.id).toSet();
    final oldIds = oldWidget.value.stages.map((s) => s.id).toSet();
    _expanded.retainAll(ids);
    _stageKeys.removeWhere((id, _) => !ids.contains(id));
    _invalidFields.removeWhere((id, _) => !ids.contains(id));
    if (ids.intersection(oldIds).isEmpty) {
      if (value.stages.isNotEmpty) _expanded.add(value.stages.first.id);
    } else {
      _expanded.addAll(ids.difference(oldIds));
    }
  }

  void _addStage(bool deferment) {
    final next = value.add(
      deferment,
      borrowingDate: productMode ? null : borrowingDate,
    );
    onChanged(next);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _stageKeys[next.stages.last.id]?.currentContext;
      if (target != null) _scrollTo(target);
    });
  }

  void _onInvalid(String id, BuildContext field) {
    _invalidFields[id] = field;
    if (_validationScheduled) return;
    _validationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validationScheduled = false;
      if (!mounted) return;
      final invalid = [
        for (final stage in value.stages)
          if (_invalidFields[stage.id] case final field?) (stage.id, field),
      ];
      _invalidFields.clear();
      if (invalid.isEmpty) return;
      setState(() => _expanded.addAll(invalid.map((entry) => entry.$1)));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && invalid.first.$2.mounted) _scrollTo(invalid.first.$2);
      });
    });
  }

  void _scrollTo(BuildContext target) {
    Scrollable.ensureVisible(
      target,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.durationFast,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showAdvanced) ...[
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
        const SizedBox(height: AppSpacing.space16),
      ],
      Text('还款阶段', style: context.appTextStyles.groupTitle),
      const SizedBox(height: AppSpacing.space8),
      for (var i = 0; i < value.stages.length; i++)
        _TimelineEntry(
          key: ValueKey(value.stages[i].id),
          first: i == 0,
          last: i == value.stages.length - 1 && !rulesEditable,
          active: _expanded.contains(value.stages[i].id),
          child: _stage(context, value.stages[i], i),
        ),
      if (rulesEditable) ...[
        _TimelineEntry(
          last: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final buttons = [
                OutlinedButton.icon(
                  onPressed: () => _addStage(false),
                  icon: const Icon(RemixIcons.add_line),
                  label: const Text('添加还款阶段'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addStage(true),
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
        ),
      ],
      if (widget.beforePlanAction case final child?) ...[
        const SizedBox(height: AppSpacing.space12),
        child,
      ],
      if (widget.planAction case final action?) ...[
        const SizedBox(height: AppSpacing.space24),
        action,
      ],
    ],
  );

  Widget _stage(BuildContext context, InstallmentStageDraft s, int index) {
    void update(InstallmentStageDraft next) => onChanged(value.replace(next));
    final flat = s.method == InstallmentRepaymentMethod.flatFee;
    final custom = s.method == InstallmentRepaymentMethod.custom;
    return InstallmentStageCard(
      key: _stageKeys.putIfAbsent(s.id, GlobalKey.new),
      number: index + 1,
      title: s.deferment ? '免还期' : '还款阶段',
      summary: presentInstallmentStageSummary(
        stage: s,
        index: index,
        stages: value.stages,
        productMode: productMode,
        borrowingDate: borrowingDate,
      ).lines,
      expanded: _expanded.contains(s.id),
      onToggle: () => setState(() {
        if (!_expanded.remove(s.id)) _expanded.add(s.id);
      }),
      onInvalid: (field) => _onInvalid(s.id, field),
      actions: [
        if (rulesEditable) ...[
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
      ],
      children: [
        AppPlainFormSection(
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
                      '间隔月数',
                      update,
                      enabled: rulesEditable,
                      hint: '每期间隔月数：1 月供，3 季供，12 年供',
                    ),
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
                  if (!flat && !custom && productMode)
                    AppPlainSelectMenuFormRow<InterestRateType>(
                      label: '利率类型',
                      value: s.rateType,
                      enabled: rulesEditable,
                      options: [
                        for (final type in InterestRateType.values)
                          AppSelectOption(
                            value: type,
                            label: referenceRateTypeLabel(type),
                          ),
                      ],
                      onChanged: (v) =>
                          update(s.changeRateType(v, productMode: productMode)),
                    ),
                  if (!flat && !custom && productMode) ...[
                    AppPlainSelectMenuFormRow(
                      label: '利率单位',
                      value: s.ratePeriod,
                      options: interestRatePeriodOptions,
                      enabled: rulesEditable && !s.floating,
                      onChanged: (v) => update(s.copyWith(ratePeriod: v)),
                    ),
                    if (s.floating) _repricingCycle(s, update),
                  ],
                  if (!flat && !custom && !productMode)
                    _DraftInput(
                      key: ValueKey('${s.id}:rate'),
                      value: s.text(StageInput.rate),
                      label: '初始利率',
                      hint: '填写合同约定利率，留空即免息',
                      enabled: true,
                      money: false,
                      ratePeriod: s.ratePeriod,
                      unitEnabled: rulesEditable,
                      onRatePeriodChanged: (v) =>
                          update(s.copyWith(ratePeriod: v)),
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
                  if (s.method ==
                      InstallmentRepaymentMethod.equalInstallment) ...[
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
        ),
        if (widget.showAdvanced && !s.deferment) ...[
          if (s.method == InstallmentRepaymentMethod.equalInstallment) ...[
            AppPlainSelectMenuFormRow(
              label: '固定额算法',
              value: s.algorithm,
              enabled: rulesEditable,
              options: productMode && s.floating
                  ? installmentAmountAlgorithmOptions
                        .where(
                          (o) => o.value != InstallmentAmountAlgorithm.fixed,
                        )
                        .toList()
                  : installmentAmountAlgorithmOptions,
              onChanged: (v) => update(s.changeAlgorithm(v)),
            ),
            if (s.algorithm != InstallmentAmountAlgorithm.fixed)
              AppPlainSelectMenuFormRow<InPeriodRepricingPolicy>(
                label: '期中重定价',
                value: s.inPeriodRepricingPolicy,
                enabled: rulesEditable,
                options: const [
                  AppSelectOption(
                    value: InPeriodRepricingPolicy.preservePrincipal,
                    label: '保留当期本金',
                  ),
                  AppSelectOption(
                    value: InPeriodRepricingPolicy.dynamicPeriodRate,
                    label: '动态期利率重算',
                  ),
                ],
                onChanged: (v) =>
                    update(s.copyWith(inPeriodRepricingPolicy: v)),
              ),
          ],
          AppPlainSelectMenuFormRow<TailDifferencePolicy>(
            label: '尾差处理',
            value: s.tailDifference,
            enabled: rulesEditable,
            options: const [
              AppSelectOption(
                value: TailDifferencePolicy.lastPeriod,
                label: '计入阶段末期',
              ),
            ],
            onChanged: (v) => update(s.copyWith(tailDifference: v)),
          ),
        ],
      ],
    );
  }

  Widget _repricingCycle(
    InstallmentStageDraft s,
    ValueChanged<InstallmentStageDraft> update,
  ) => AppPlainSelectMenuFormRow<int>(
    label: '重定价周期',
    value: s.repricingCycleMonths,
    enabled: rulesEditable,
    options: const [
      AppSelectOption(value: 3, label: '3 个月'),
      AppSelectOption(value: 6, label: '6 个月'),
      AppSelectOption(value: 12, label: '12 个月'),
    ],
    onChanged: (v) => update(s.copyWith(repricingCycleMonths: v)),
  );

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

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.child,
    this.first = false,
    this.last = false,
    this.active = false,
    super.key,
  });

  final Widget child;
  final bool first, last, active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        if (!first || !last)
          Positioned(
            left: AppSpacing.space4,
            top: first ? AppSpacing.space24 : 0,
            bottom: last ? null : 0,
            height: last ? AppSpacing.space24 : null,
            width: AppComponentTokens.outlineWidth,
            child: ColoredBox(color: colors.outlineVariant),
          ),
        Positioned(
          left: 0,
          top: AppSpacing.space20,
          child: Container(
            width: AppSpacing.space8,
            height: AppSpacing.space8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? colors.primary : colors.outlineVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.space20,
            bottom: AppSpacing.space12,
          ),
          child: child,
        ),
      ],
    );
  }
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
