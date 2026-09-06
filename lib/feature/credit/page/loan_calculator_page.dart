import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_detail_summary_card.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/installment_schedule_presentation.dart';
import '../view_model/loan_calculator_view_model.dart';
import '../widget/installment_plan_summary_card.dart';
import '../widget/installment_schedule_view.dart';
import '../widget/installment_terms_editor.dart';
import '../widget/loan_basic_info_fields.dart';

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

  @override
  void dispose() {
    _principalController.dispose();
    _paidPeriodsController.dispose();
    _prepaymentPrincipalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loanCalculatorViewModelProvider);
    final notifier = ref.read(loanCalculatorViewModelProvider.notifier);

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
                    InstallmentTermsEditor(
                      mode: InstallmentTermsEditorMode.calculator,
                      value: state.terms,
                      onChanged: notifier.setTerms,
                      borrowingDate: state.borrowingDate,
                      beforePlanAction: state.canSimulatePrepayment
                          ? _buildPrepaymentSection(state, notifier)
                          : null,
                      planAction: AppSubmitButton(
                        label: '生成还款计划',
                        onPressed: () => _calculate(state, notifier),
                      ),
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
  ) => AppFormSection(
    title: '贷款',
    padding: _sectionPadding,
    children: [
      LoanBasicInfoFields(
        principalController: _principalController,
        borrowingDate: state.borrowingDate,
        onBorrowingDateChanged: notifier.setBorrowingDate,
        onPrincipalChanged: (_) => notifier.invalidateResult(),
      ),
    ],
  );

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
            onChanged: (_) => notifier.invalidateResult(),
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
            onChanged: (_) => notifier.invalidateResult(),
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
      principalText: _principalController.text,
      paidPeriodsText: _paidPeriodsController.text,
      prepaymentPrincipalText: _prepaymentPrincipalController.text,
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
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.result});

  final LoanCalculation result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstallmentPlanSummaryCard(
          metrics: result.metrics,
          principal: result.totalPrincipal,
          periodCount: result.periods.length,
          stages: result.stages,
        ),
        const SizedBox(height: AppSpacing.space12),
        Text('逐期明细', style: context.appTextStyles.dateSectionTitle),
        const SizedBox(height: AppSpacing.space6),
        InstallmentScheduleView(
          items: calculationScheduleItems(
            result.periods,
            stages: result.stages,
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
        InstallmentScheduleView(
          items: calculationScheduleItems(
            simulation.periods,
            firstRecalculatedPeriodNo: firstRecalculated,
          ),
        ),
      ],
    );
  }
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

String? _validateNonNegativeInt(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) return null;
  final number = int.tryParse(trimmed);
  if (number == null || number < 0) return '必须为非负整数';
  return null;
}
