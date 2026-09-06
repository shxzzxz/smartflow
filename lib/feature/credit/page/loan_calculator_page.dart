import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/rounding_mode.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_status_badge.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/loan_calculator_presentation.dart';
import '../view_model/loan_calculator_view_model.dart';
import '../widget/installment_field_options.dart';

const _sectionPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.space16,
  vertical: AppSpacing.space8,
);

class LoanCalculatorPage extends ConsumerStatefulWidget {
  const LoanCalculatorPage({super.key});

  @override
  ConsumerState<LoanCalculatorPage> createState() => _LoanCalculatorPageState();
}

class _LoanCalculatorPageState extends ConsumerState<LoanCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _paidPeriodsController = TextEditingController();
  final _prepaymentPrincipalController = TextEditingController();
  final _stageControllers = <String, _StageControllers>{};

  @override
  void dispose() {
    _principalController.dispose();
    _paidPeriodsController.dispose();
    _prepaymentPrincipalController.dispose();
    for (final controllers in _stageControllers.values) {
      controllers.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loanCalculatorViewModelProvider);
    final notifier = ref.read(loanCalculatorViewModelProvider.notifier);
    _scheduleControllerPruning(state);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: '贷款计算器',
              actions: [
                AppHeaderIconButton(
                  icon: RemixIcons.magic_line,
                  tooltip: '产品预设',
                  onPressed: () => _showPresets(notifier),
                ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space12,
                    AppSpacing.space16,
                    AppSpacing.space24,
                  ),
                  children: [
                    _buildLoanSection(state, notifier),
                    const SizedBox(height: AppSpacing.space12),
                    _buildConventionSection(state, notifier),
                    for (var i = 0; i < state.stages.length; i++) ...[
                      const SizedBox(height: AppSpacing.space12),
                      _buildStageSection(
                        index: i,
                        draft: state.stages[i],
                        isLast: i == state.stages.length - 1,
                        removable: state.stages.length > 1,
                        notifier: notifier,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.space12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: notifier.addAmortizingStage,
                            icon: const Icon(RemixIcons.add_line),
                            label: const Text('添加还款阶段'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.space8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: notifier.addDefermentStage,
                            icon: const Icon(RemixIcons.time_line),
                            label: const Text('添加免还期'),
                          ),
                        ),
                      ],
                    ),
                    if (state.canSimulatePrepayment) ...[
                      const SizedBox(height: AppSpacing.space12),
                      _buildPrepaymentSection(state, notifier),
                    ],
                    const SizedBox(height: AppSpacing.space24),
                    AppSubmitButton(
                      label: '生成还款计划',
                      onPressed: () => _calculate(state, notifier),
                    ),
                    if (state.result != null) ...[
                      const SizedBox(height: AppSpacing.space16),
                      _ResultSection(result: state.result!),
                    ],
                    if (state.simulation != null) ...[
                      const SizedBox(height: AppSpacing.space16),
                      _SimulationSection(simulation: state.simulation!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanSection(
    LoanCalculatorState state,
    LoanCalculatorViewModel notifier,
  ) {
    return AppFormSection(
      title: '贷款',
      padding: _sectionPadding,
      children: [
        MoneyPlainFormRow(
          label: '本金',
          controller: _principalController,
          hintText: '请输入借款本金',
          validator: validatePositiveMoneyText,
        ),
        DateTimePlainFormRow(
          label: '借款日期',
          dateTime: state.borrowingDate,
          value: formatDateLabel(state.borrowingDate),
          onTap: (onSelected) =>
              _pickDate(state.borrowingDate, '选择借款日期', onSelected),
          onChanged: (value) {
            if (value != null) notifier.setBorrowingDate(value);
          },
        ),
      ],
    );
  }

  Widget _buildConventionSection(
    LoanCalculatorState state,
    LoanCalculatorViewModel notifier,
  ) {
    return AppFormSection(
      title: '计算约定',
      padding: _sectionPadding,
      children: [
        AppPlainSelectMenuFormRow<DayCountConvention>(
          label: '标准天数',
          value: state.dayCount,
          options: dayCountConventionOptions,
          onChanged: notifier.setDayCount,
        ),
        AppPlainSelectMenuFormRow<RoundingMode>(
          label: '舍入方式',
          value: state.rounding,
          options: roundingModeOptions,
          onChanged: notifier.setRounding,
        ),
      ],
    );
  }

  Widget _buildStageSection({
    required int index,
    required LoanCalculatorStageDraft draft,
    required bool isLast,
    required bool removable,
    required LoanCalculatorViewModel notifier,
  }) {
    final controllers = _controllersFor(draft);
    final removeButton = removable
        ? TextButton.icon(
            onPressed: () => notifier.removeStage(draft.id),
            icon: const Icon(RemixIcons.delete_bin_line),
            label: const Text('删除阶段'),
          )
        : null;
    switch (draft.kind) {
      case LoanCalculatorStageKind.deferment:
        return AppFormSection(
          title: '阶段 ${index + 1} · 免还期',
          trailing: removeButton,
          padding: _sectionPadding,
          children: [
            DateTimePlainFormRow(
              label: '免还至',
              dateTime: draft.untilDate,
              value: formatDateLabel(draft.untilDate),
              onTap: (onSelected) =>
                  _pickDate(draft.untilDate, '选择免还期截止日', onSelected),
              onChanged: (value) {
                if (value != null) notifier.setStageUntilDate(draft.id, value);
              },
            ),
          ],
        );
      case LoanCalculatorStageKind.amortizing:
        final isFlatFee = draft.method == InstallmentRepaymentMethod.flatFee;
        final isEqualInstallment =
            draft.method == InstallmentRepaymentMethod.equalInstallment;
        return AppFormSection(
          title: '阶段 ${index + 1} · 还款阶段',
          trailing: removeButton,
          padding: _sectionPadding,
          children: [
            AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>(
              label: '还款方式',
              value: draft.method,
              options: loanCalculatorRepaymentMethodOptions,
              onChanged: (value) => notifier.setStageMethod(draft.id, value),
            ),
            if (!isFlatFee)
              AppPlainIntegerFormRow(
                label: '期数',
                controller: controllers.periods,
                hintText: '本阶段期数',
                validator: _validatePositiveInt,
              ),
            if (!isFlatFee)
              AppPlainIntegerFormRow(
                label: '各期间隔',
                controller: controllers.intervalMonths,
                hintText: '每期间隔月数：1 月供，3 季供，12 年供',
                validator: _validatePositiveInt,
              ),
            DateTimePlainFormRow(
              label: '首期还款日',
              dateTime: draft.firstRepaymentDate,
              value: formatDateLabel(draft.firstRepaymentDate),
              onTap: (onSelected) =>
                  _pickDate(draft.firstRepaymentDate, '选择首期还款日', onSelected),
              onChanged: (value) {
                if (value != null) {
                  notifier.setStageFirstRepaymentDate(draft.id, value);
                }
              },
            ),
            if (!isFlatFee)
              DateTimePlainFormRow(
                label: '末期还款日',
                dateTime: draft.lastRepaymentDate,
                value: draft.lastRepaymentDate == null
                    ? '按期数与各期间隔自动生成'
                    : formatDateLabel(draft.lastRepaymentDate!),
                onTap: (onSelected) => _pickDate(
                  draft.lastRepaymentDate ?? draft.firstRepaymentDate,
                  '选择末期还款日',
                  onSelected,
                ),
                onChanged: (value) =>
                    notifier.setStageLastRepaymentDate(draft.id, value),
              ),
            if (!isFlatFee)
              ValueWithUnitPlainFormRow<InterestRatePeriod>(
                label: '利率',
                controller: controllers.rate,
                hintText: '留空即免息',
                suffixText: '%',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                unit: draft.ratePeriod,
                unitOptions: interestRatePeriodOptions,
                onUnitChanged: (value) =>
                    notifier.setStageRatePeriod(draft.id, value),
              ),
            if (!isFlatFee)
              AppPlainSelectMenuFormRow<InterestAccrualMethod>(
                label: '计息方式',
                value: draft.accrual,
                options: interestAccrualMethodOptions,
                onChanged: (value) => notifier.setStageAccrual(draft.id, value),
              ),
            if (isEqualInstallment)
              AppPlainSelectMenuFormRow<EqualInstallmentAmountMode>(
                label: '固定额算法',
                value: draft.installmentAmountMode,
                options: equalInstallmentAmountModeOptions,
                onChanged: (value) =>
                    notifier.setStageInstallmentAmountMode(draft.id, value),
              ),
            if (isEqualInstallment &&
                draft.installmentAmountMode == EqualInstallmentAmountMode.fixed)
              MoneyPlainFormRow(
                label: '固定还款额',
                controller: controllers.fixedAmount,
                hintText: '产品披露的每期还款额',
                validator: validatePositiveMoneyText,
              ),
            MoneyPlainFormRow(
              label: '期末本金',
              controller: controllers.endPrincipal,
              hintText: _endPrincipalHint(draft.method, isLast: isLast),
              validator: validateOptionalNonNegativeMoneyText,
            ),
            if (isFlatFee)
              MoneyPlainFormRow(
                label: '手续费',
                controller: controllers.fee,
                hintText: '首期还款日一次收取（可选）',
                validator: validateOptionalNonNegativeMoneyText,
              ),
          ],
        );
    }
  }

  Widget _buildPrepaymentSection(
    LoanCalculatorState state,
    LoanCalculatorViewModel notifier,
  ) {
    return AppFormSection(
      title: '提前还款试算',
      padding: _sectionPadding,
      children: [
        AppPlainSwitchRow(
          label: '试算提前还款',
          description: '以提前还款日期为锚点重算其后的待还期次，锚点之前的期次不变',
          value: state.simulatePrepayment,
          onChanged: notifier.setSimulatePrepayment,
        ),
        if (state.simulatePrepayment) ...[
          AppPlainIntegerFormRow(
            label: '已还期数',
            controller: _paidPeriodsController,
            hintText: '已按原计划还清的期数，留空为 0',
            validator: _validateNonNegativeInt,
          ),
          DateTimePlainFormRow(
            label: '提前还款日',
            dateTime: state.prepaymentDate,
            value: formatDateLabel(state.prepaymentDate),
            onTap: (onSelected) =>
                _pickDate(state.prepaymentDate, '选择提前还款日期', onSelected),
            onChanged: (value) {
              if (value != null) notifier.setPrepaymentDate(value);
            },
          ),
          MoneyPlainFormRow(
            label: '提前还款本金',
            controller: _prepaymentPrincipalController,
            hintText: '本次提前归还的本金',
            validator: validatePositiveMoneyText,
          ),
        ],
      ],
    );
  }

  Future<void> _calculate(
    LoanCalculatorState state,
    LoanCalculatorViewModel notifier,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await notifier.calculate(
      LoanCalculatorFormTexts(
        principal: _principalController.text,
        stages: {
          for (final draft in state.stages)
            if (draft.kind == LoanCalculatorStageKind.amortizing)
              draft.id: _controllersFor(draft).texts(),
        },
        paidPeriods: _paidPeriodsController.text,
        prepaymentPrincipal: _prepaymentPrincipalController.text,
      ),
    );
    if (!mounted) return;
    if (outcome case UiActionFailure<void>(:final error)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showPresets(LoanCalculatorViewModel notifier) async {
    final preset = await showModalBottomSheet<LoanCalculatorPreset>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: Text(
                '产品预设',
                style: sheetContext.appTextStyles.subsectionTitle,
              ),
            ),
            for (final preset in LoanCalculatorPreset.values)
              ListTile(
                title: Text(_presetTitle(preset)),
                subtitle: Text(_presetDescription(preset)),
                onTap: () => Navigator.of(sheetContext).pop(preset),
              ),
          ],
        ),
      ),
    );
    if (preset == null || !mounted) return;
    notifier.applyPreset(preset, principalText: _principalController.text);
  }

  Future<void> _pickDate(
    DateTime initialDate,
    String title,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate,
      title: title,
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
  }

  _StageControllers _controllersFor(LoanCalculatorStageDraft draft) {
    return _stageControllers.putIfAbsent(
      draft.id,
      () => _StageControllers.fromDraft(draft),
    );
  }

  /// 被移除阶段的控件在下一帧释放，避免释放仍挂在当前帧输入框上的控制器。
  void _scheduleControllerPruning(LoanCalculatorState state) {
    final liveIds = {for (final stage in state.stages) stage.id};
    if (_stageControllers.keys.every(liveIds.contains)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stale = _stageControllers.keys.where((id) => !liveIds.contains(id));
      for (final id in stale.toList()) {
        _stageControllers.remove(id)?.dispose();
      }
    });
  }
}

class _StageControllers {
  _StageControllers.fromDraft(LoanCalculatorStageDraft draft)
    : periods = TextEditingController(text: draft.periodsText),
      intervalMonths = TextEditingController(text: draft.intervalMonthsText),
      rate = TextEditingController(text: draft.rateText),
      endPrincipal = TextEditingController(text: draft.endPrincipalText),
      fee = TextEditingController(text: draft.feeText),
      fixedAmount = TextEditingController(text: draft.fixedAmountText);

  final TextEditingController periods;
  final TextEditingController intervalMonths;
  final TextEditingController rate;
  final TextEditingController endPrincipal;
  final TextEditingController fee;
  final TextEditingController fixedAmount;

  LoanCalculatorStageTexts texts() {
    return LoanCalculatorStageTexts(
      periods: periods.text,
      intervalMonths: intervalMonths.text,
      rate: rate.text,
      endPrincipal: endPrincipal.text,
      fee: fee.text,
      fixedAmount: fixedAmount.text,
    );
  }

  void dispose() {
    periods.dispose();
    intervalMonths.dispose();
    rate.dispose();
    endPrincipal.dispose();
    fee.dispose();
    fixedAmount.dispose();
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.result});

  final LoanCalculation result;

  @override
  Widget build(BuildContext context) {
    final metrics = result.metrics;
    final stageStartPeriodNos = {
      for (final stage in result.stages) stage.firstPeriodNo: stage,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDetailSummaryCard(
          title: '还款计划',
          headerTrailing: AppStatusBadge(
            label: '${result.periods.length} 期',
            color: Theme.of(context).colorScheme.primary,
          ),
          mainItems: [
            AppDetailSummaryCardItem(
              label: '总还款',
              value: result.totalRepayment.format(),
            ),
            AppDetailSummaryCardItem(
              label: '总利息',
              value: result.totalInterest.format(),
            ),
            AppDetailSummaryCardItem(
              label: '总手续费',
              value: result.totalFee.format(),
            ),
          ],
          supportingItems: [
            if (metrics.isAvailable) ...[
              AppDetailSummaryCardItem(
                label: '月 IRR',
                value: formatRatePercent(metrics.monthlyIrr, fractionDigits: 4),
              ),
              AppDetailSummaryCardItem(
                label: 'APR',
                value: formatRatePercent(metrics.nominalApr),
              ),
              AppDetailSummaryCardItem(
                label: 'EAR',
                value: formatRatePercent(metrics.effectiveApr),
              ),
            ] else
              AppDetailSummaryCardItem(
                label: '指标不可用',
                value: contractMetricsUnavailableLabel(
                  metrics.unavailableReason!,
                ),
                span: 2,
              ),
            for (final stage in result.stages)
              if (stage.installmentAmount != null) ...[
                AppDetailSummaryCardItem(
                  label: '第 ${stage.firstPeriodNo}–${stage.lastPeriodNo} 期固定额',
                  value: stage.installmentAmount!.format(),
                ),
                AppDetailSummaryCardItem(
                  label: '末期与固定额差额',
                  value: formatSignedMoney(stage.lastPeriodDifference!),
                ),
              ],
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        Text('逐期明细', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        AppSurface(
          child: Column(
            children: [
              for (final period in result.periods) ...[
                if (result.stages.length > 1 &&
                    stageStartPeriodNos.containsKey(period.periodNo))
                  _StageDivider(
                    label:
                        '阶段 ${stageStartPeriodNos[period.periodNo]!.index + 1}',
                  ),
                _PeriodRow(period: period),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SimulationSection extends StatelessWidget {
  const _SimulationSection({required this.simulation});

  final LoanPrepaymentSimulation simulation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final firstRecalculated = simulation.firstRecalculatedPeriodNo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDetailSummaryCard(
          title: '提前还款试算',
          mainItems: [
            AppDetailSummaryCardItem(
              label: '节省利息',
              value: simulation.interestSaved.format(),
              valueColor: colors.tertiary,
            ),
            AppDetailSummaryCardItem(
              label: '试算后总利息',
              value: simulation.totalInterest.format(),
            ),
            AppDetailSummaryCardItem(
              label: '提前还款本金',
              value: simulation.prepaymentPrincipal.format(),
            ),
          ],
          supportingItems: [
            AppDetailSummaryCardItem(
              label: '重算范围',
              value: firstRecalculated == null
                  ? '剩余本金已结清，无待还尾部'
                  : '第 $firstRecalculated 期起',
              span: 2,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space12),
        Text('试算后计划', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        AppSurface(
          child: Column(
            children: [
              for (final period in simulation.periods)
                _PeriodRow(
                  period: period,
                  recalculated:
                      firstRecalculated != null &&
                      period.periodNo >= firstRecalculated,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StageDivider extends StatelessWidget {
  const _StageDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space12,
        AppSpacing.space10,
        AppSpacing.space12,
        AppSpacing.space2,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: context.appTextStyles.listSupporting.copyWith(
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.space8),
          Expanded(
            child: Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, this.recalculated = false});

  final LoanCalculationPeriod period;
  final bool recalculated;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text('第${period.periodNo}期', style: styles.formLabel),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.space6,
                  runSpacing: AppSpacing.space4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(formatDateLabel(period.date), style: styles.formLabel),
                    if (recalculated)
                      AppStatusBadge(label: '重算', color: colors.primary),
                  ],
                ),
                Text(
                  loanPeriodBreakdownText(period),
                  style: styles.listSupporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(period.total.format(), style: styles.formLabel),
              Text(
                '剩余 ${period.remainingPrincipal.format()}',
                style: styles.listSupporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _endPrincipalHint(
  InstallmentRepaymentMethod method, {
  required bool isLast,
}) {
  if (isLast) return '留空为 0；填写则末期额外归还该余额';
  if (method == InstallmentRepaymentMethod.interestFirst) {
    return '留空即等于期初本金';
  }
  return '本阶段结束时的剩余本金';
}

String _presetTitle(LoanCalculatorPreset preset) {
  return switch (preset) {
    LoanCalculatorPreset.equalInstallment => '等额本息',
    LoanCalculatorPreset.studentLoan => '国家助学贷款',
    LoanCalculatorPreset.interestFirstThenEqualInstallment => '先息后本转等额本息',
    LoanCalculatorPreset.balloon => '气球贷',
    LoanCalculatorPreset.flatFee => '一次性手续费',
  };
}

String _presetDescription(LoanCalculatorPreset preset) {
  return switch (preset) {
    LoanCalculatorPreset.equalInstallment => '单阶段，固定名义期利率',
    LoanCalculatorPreset.studentLoan => '免还期到毕业；先息后本年付；等额本金年付归零',
    LoanCalculatorPreset.interestFirstThenEqualInstallment =>
      '先息后本 12 期后转等额本息 24 期',
    LoanCalculatorPreset.balloon => '等额本息，末期额外归还期末本金',
    LoanCalculatorPreset.flatFee => '首期还款日一次偿还本金与手续费',
  };
}

String? _validatePositiveInt(String? value) {
  final number = int.tryParse((value ?? '').trim());
  if (number == null || number <= 0) return '必须为正整数';
  return null;
}

String? _validateNonNegativeInt(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return null;
  final number = int.tryParse(trimmed);
  if (number == null || number < 0) return '必须为非负整数';
  return null;
}
