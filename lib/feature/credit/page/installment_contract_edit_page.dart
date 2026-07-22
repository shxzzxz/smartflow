import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../design_system/widget/app_surface.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../provider/installment_query_providers.dart';
import '../view_model/installment_contract_edit_state.dart';
import '../view_model/installment_contract_edit_view_model.dart';
import '../widget/installment_field_options.dart';

class InstallmentContractEditPage extends ConsumerStatefulWidget {
  const InstallmentContractEditPage({required this.contractId, super.key});

  final String contractId;

  @override
  ConsumerState<InstallmentContractEditPage> createState() =>
      _InstallmentContractEditPageState();
}

class _InstallmentContractEditPageState
    extends ConsumerState<InstallmentContractEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _periodsController = TextEditingController();
  final _rateController = TextEditingController();
  final _feeController = TextEditingController();
  final _overrideInstallmentController = TextEditingController();
  String? _syncedContractId;

  @override
  void dispose() {
    _periodsController.dispose();
    _rateController.dispose();
    _feeController.dispose();
    _overrideInstallmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editAsync = ref.watch(
      installmentContractEditViewModelProvider(widget.contractId),
    );
    final metricsAsync = ref.watch(
      installmentMetricsProvider(widget.contractId),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('编辑合同')),
      body: switch (editAsync) {
        AsyncData(value: InstallmentContractEditLoaded loaded) => _buildBody(
          loaded,
          metricsAsync,
        ),
        AsyncData(value: InstallmentContractEditNotFound()) => const Center(
          child: Text('合同不存在'),
        ),
        AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildBody(
    InstallmentContractEditLoaded loaded,
    AsyncValue<ContractMetrics> metricsAsync,
  ) {
    final contract = loaded.contract;
    _syncControllers(contract);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space12,
          AppSpacing.space12,
          AppSpacing.space12,
          AppSpacing.space24,
        ),
        children: [
          _MetricsSection(
            metricsAsync: metricsAsync,
            principal: contract.principal,
          ),
          const SizedBox(height: AppSpacing.space12),
          _ConfigSection(
            contract: contract,
            paidCount: loaded.paidCount,
            firstRepaymentDate: loaded.firstRepaymentDate,
            lastRepaymentDate: loaded.lastRepaymentDate,
            method: loaded.method,
            ratePeriod: loaded.ratePeriod,
            accrualMethod: loaded.accrualMethod,
            periodsController: _periodsController,
            rateController: _rateController,
            feeController: _feeController,
            overrideInstallmentController: _overrideInstallmentController,
            onPickFirstDate:
                loaded.paidCount > 0
                    ? null
                    : (onSelected) => _pickFirstDate(loaded, onSelected),
            onPickLastDate: (onSelected) => _pickLastDate(loaded, onSelected),
            onFirstDateChanged: (value) {
              if (value != null) {
                ref
                    .read(
                      installmentContractEditViewModelProvider(
                        widget.contractId,
                      ).notifier,
                    )
                    .setFirstRepaymentDate(value);
              }
            },
            onLastDateChanged: (value) {
              if (value != null) {
                ref
                    .read(
                      installmentContractEditViewModelProvider(
                        widget.contractId,
                      ).notifier,
                    )
                    .setLastRepaymentDate(value);
              }
            },
            onMethodChanged:
                (v) => ref
                    .read(
                      installmentContractEditViewModelProvider(
                        widget.contractId,
                      ).notifier,
                    )
                    .setMethod(v),
            onRatePeriodChanged:
                (v) => ref
                    .read(
                      installmentContractEditViewModelProvider(
                        widget.contractId,
                      ).notifier,
                    )
                    .setRatePeriod(v),
            onAccrualMethodChanged:
                loaded.paidCount > 0
                    ? null
                    : (v) => ref
                        .read(
                          installmentContractEditViewModelProvider(
                            widget.contractId,
                          ).notifier,
                        )
                        .setAccrualMethod(v),
            onRecalculate: _recalculate,
          ),
          const SizedBox(height: AppSpacing.space12),
          _ScheduleSection(
            draft: loaded.draft,
            manualPatched: loaded.manualPatchedPeriodNos,
            onApplyAmount: _applyAmount,
            onEditDate: _editScheduleDate,
          ),
          const SizedBox(height: AppSpacing.space20),
          AppSubmitButton(
            label: '保存',
            loading: loaded.submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  void _syncControllers(InstallmentContractReadModel contract) {
    if (_syncedContractId == contract.id) return;
    _syncedContractId = contract.id;
    _periodsController.text = installmentContractPeriodsText(contract);
    _rateController.text = installmentContractRateText(contract);
    _feeController.text = installmentContractFeeText(contract);
    _overrideInstallmentController.text = '';
  }

  Future<void> _pickFirstDate(
    InstallmentContractEditLoaded loaded,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: loaded.firstRepaymentDate,
      title: '选择首期还款日',
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
  }

  Future<void> _pickLastDate(
    InstallmentContractEditLoaded loaded,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: loaded.lastRepaymentDate,
      title: '选择末期还款日',
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
  }

  Future<void> _recalculate() async {
    final outcome = await ref
        .read(
          installmentContractEditViewModelProvider(widget.contractId).notifier,
        )
        .recalculate(
          totalPeriodsText: _periodsController.text,
          rateText: _rateController.text,
          feeText: _feeController.text,
          overrideInstallmentText: _overrideInstallmentController.text,
        );
    switch (outcome) {
      case UiActionFailure<void>(:final error):
        if (mounted) _showError(error.message);
      case UiActionSuccess<void>():
        break;
    }
  }

  void _applyAmount(
    InstallmentContractDraftRow row,
    InstallmentAmountField field,
    Money value,
  ) {
    ref
        .read(
          installmentContractEditViewModelProvider(widget.contractId).notifier,
        )
        .applyAmount(row, field, value);
  }

  Future<void> _editScheduleDate(InstallmentContractDraftRow row) async {
    if (row.status != InstallmentScheduleStatus.pending) return;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: row.date,
      title: '选择第 ${row.periodNo} 期还款日',
    );
    if (picked == null || !mounted) return;
    ref
        .read(
          installmentContractEditViewModelProvider(widget.contractId).notifier,
        )
        .editScheduleDate(row, picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref
        .read(
          installmentContractEditViewModelProvider(widget.contractId).notifier,
        )
        .submit(
          totalPeriodsText: _periodsController.text,
          rateText: _rateController.text,
          feeText: _feeController.text,
          overrideInstallmentText: _overrideInstallmentController.text,
        );
    if (!mounted) return;
    switch (outcome) {
      case SubmitSuccess():
        context.pop();
      case SubmitFailure(:final error):
        _showError(error.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  const _ConfigSection({
    required this.contract,
    required this.paidCount,
    required this.firstRepaymentDate,
    required this.lastRepaymentDate,
    required this.method,
    required this.ratePeriod,
    required this.accrualMethod,
    required this.periodsController,
    required this.rateController,
    required this.feeController,
    required this.overrideInstallmentController,
    required this.onPickFirstDate,
    required this.onPickLastDate,
    required this.onFirstDateChanged,
    required this.onLastDateChanged,
    required this.onMethodChanged,
    required this.onRatePeriodChanged,
    required this.onAccrualMethodChanged,
    required this.onRecalculate,
  });

  final InstallmentContractReadModel contract;
  final int paidCount;
  final DateTime firstRepaymentDate;
  final DateTime lastRepaymentDate;
  final InstallmentRepaymentMethod method;
  final InterestRatePeriod ratePeriod;
  final InterestAccrualMethod accrualMethod;
  final TextEditingController periodsController;
  final TextEditingController rateController;
  final TextEditingController feeController;
  final TextEditingController overrideInstallmentController;
  final AppPlainSelectTap<DateTime>? onPickFirstDate;
  final AppPlainSelectTap<DateTime> onPickLastDate;
  final ValueChanged<DateTime?> onFirstDateChanged;
  final ValueChanged<DateTime?> onLastDateChanged;
  final ValueChanged<InstallmentRepaymentMethod> onMethodChanged;
  final ValueChanged<InterestRatePeriod> onRatePeriodChanged;
  final ValueChanged<InterestAccrualMethod>? onAccrualMethodChanged;
  final VoidCallback onRecalculate;

  static const double _rowMinHeight = 44;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppFormSection(
      title: '分期配置',
      spacing: AppSpacing.space4,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space12,
        vertical: AppSpacing.space4,
      ),
      children: [
        AppPlainFormRow(
          label: '借款日期',
          minHeight: _rowMinHeight,
          child: _readOnly(context, _formatDate(contract.borrowingDate)),
        ),
        AppPlainFormRow(
          label: '分期类型',
          minHeight: _rowMinHeight,
          child: _readOnly(context, _sourceTypeLabel(contract.sourceType)),
        ),
        AppPlainFormRow(
          label: '本金',
          minHeight: _rowMinHeight,
          child: _readOnly(context, contract.principal.format()),
        ),
        AppPlainIntegerFormRow(
          label: '期数',
          controller: periodsController,
          hintText: '总期数',
          minHeight: _rowMinHeight,
          validator: (value) {
            final n = int.tryParse((value ?? '').trim());
            if (n == null || n <= 0) return '期数必须为正整数';
            if (n < paidCount + 1) {
              return '期数必须不小于已还期数 + 1（当前 ${paidCount + 1}）';
            }
            return null;
          },
        ),
        DateTimePlainFormRow(
          label: '首期还款日',
          dateTime: firstRepaymentDate,
          value: _formatDate(firstRepaymentDate),
          onTap: onPickFirstDate,
          onChanged: onFirstDateChanged,
          minHeight: _rowMinHeight,
        ),
        DateTimePlainFormRow(
          label: '末期还款日',
          dateTime: lastRepaymentDate,
          value: _formatDate(lastRepaymentDate),
          onTap: onPickLastDate,
          onChanged: onLastDateChanged,
          minHeight: _rowMinHeight,
        ),
        DropdownPlainFormRow<InstallmentRepaymentMethod>(
          label: '分期方式',
          value: method,
          items: installmentRepaymentMethodItems,
          onChanged: onMethodChanged,
          minHeight: _rowMinHeight,
        ),
        if (method != InstallmentRepaymentMethod.flatFee &&
            method != InstallmentRepaymentMethod.custom)
          DropdownPlainFormRow<InterestAccrualMethod>(
            label: '计息方式',
            value: accrualMethod,
            items: interestAccrualMethodItems,
            onChanged: onAccrualMethodChanged,
            minHeight: _rowMinHeight,
          ),
        if (method != InstallmentRepaymentMethod.flatFee &&
            method != InstallmentRepaymentMethod.custom)
          ValueWithUnitPlainFormRow<InterestRatePeriod>(
            label: '利率(%)',
            controller: rateController,
            hintText: '例：7.2',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            unit: ratePeriod,
            unitItems: interestRatePeriodItems,
            onUnitChanged: onRatePeriodChanged,
            minHeight: _rowMinHeight,
          ),
        if (method == InstallmentRepaymentMethod.flatFee)
          MoneyPlainFormRow(
            label: '总手续费',
            controller: feeController,
            hintText: '各期合计（可选）',
            minHeight: _rowMinHeight,
          ),
        if (method == InstallmentRepaymentMethod.equalInstallment)
          MoneyPlainFormRow(
            label: '还款固定额',
            controller: overrideInstallmentController,
            hintText: '前 n-1 期固定额（可选）',
            minHeight: _rowMinHeight,
          ),
        Divider(
          height: 1,
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRecalculate,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('按配置重算'),
          ),
        ),
      ],
    );
  }

  Widget _readOnly(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      text,
      style: context.appTextStyles.formPlainValue.copyWith(
        color: colors.onSurface,
      ),
    );
  }
}

typedef _ApplyAmount =
    void Function(
      InstallmentContractDraftRow row,
      InstallmentAmountField field,
      Money value,
    );

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.draft,
    required this.manualPatched,
    required this.onApplyAmount,
    required this.onEditDate,
  });

  final List<InstallmentContractDraftRow> draft;
  final Set<int> manualPatched;
  final _ApplyAmount onApplyAmount;
  final ValueChanged<InstallmentContractDraftRow> onEditDate;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            0,
            AppSpacing.space4,
            AppSpacing.space4,
          ),
          child: Text('还款计划', style: styles.dateSectionTitle),
        ),
        AppSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space6,
              vertical: AppSpacing.space4,
            ),
            child: Column(
              children: [
                _ScheduleHeader(),
                Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                ),
                for (var i = 0; i < draft.length; i++) ...[
                  _ScheduleRow(
                    row: draft[i],
                    edited: manualPatched.contains(draft[i].periodNo),
                    onApplyAmount: onApplyAmount,
                    onEditDate: onEditDate,
                  ),
                  if (i < draft.length - 1)
                    Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.35),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final labelStyle = styles.listSupporting.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space6,
      ),
      child: Row(
        children: [
          SizedBox(
            width: _periodCellWidth,
            child: Text('期', style: labelStyle),
          ),
          SizedBox(width: _dateCellWidth, child: Text('时间', style: labelStyle)),
          Expanded(
            child: Text('本', style: labelStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text('息', style: labelStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text('费', style: labelStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text('总额', style: labelStyle, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: _statusCellWidth,
            child: Text('状态', style: labelStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

const double _periodCellWidth = 28;
const double _dateCellWidth = 56;
const double _statusCellWidth = 36;

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.row,
    required this.edited,
    required this.onApplyAmount,
    required this.onEditDate,
  });

  final InstallmentContractDraftRow row;
  final bool edited;
  final _ApplyAmount onApplyAmount;
  final ValueChanged<InstallmentContractDraftRow> onEditDate;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final pending = row.status == InstallmentScheduleStatus.pending;
    final statusColor = switch (row.status) {
      InstallmentScheduleStatus.pending => colors.primary,
      InstallmentScheduleStatus.partiallyPaid => colors.error,
      InstallmentScheduleStatus.paid => colors.tertiary,
      InstallmentScheduleStatus.skipped => colors.outline,
    };
    final cellStyle = styles.listSupporting.copyWith(
      color: pending ? colors.onSurface : colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _periodCellWidth,
            child: Row(
              children: [
                Text('${row.periodNo}', style: cellStyle),
                if (edited) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.edit, size: 10, color: colors.secondary),
                ],
              ],
            ),
          ),
          SizedBox(
            width: _dateCellWidth,
            child: _Cell(
              text: _formatDateShort(row.date),
              style: cellStyle,
              align: TextAlign.left,
              onTap: pending ? () => onEditDate(row) : null,
            ),
          ),
          Expanded(
            child: _EditableMoneyCell(
              key: ValueKey('p-${row.periodNo}'),
              value: row.principal,
              style: cellStyle,
              canEdit: pending,
              allowZero: false,
              onCommit:
                  (m) =>
                      onApplyAmount(row, InstallmentAmountField.principal, m),
            ),
          ),
          Expanded(
            child: _EditableMoneyCell(
              key: ValueKey('i-${row.periodNo}'),
              value: row.interest,
              style: cellStyle,
              canEdit: pending,
              allowZero: true,
              onCommit:
                  (m) => onApplyAmount(row, InstallmentAmountField.interest, m),
            ),
          ),
          Expanded(
            child: _EditableMoneyCell(
              key: ValueKey('f-${row.periodNo}'),
              value: row.fee,
              style: cellStyle,
              canEdit: pending,
              allowZero: true,
              onCommit:
                  (m) => onApplyAmount(row, InstallmentAmountField.fee, m),
            ),
          ),
          Expanded(
            child: _Cell(
              text: row.total.format(),
              style: cellStyle.copyWith(fontWeight: FontWeight.w600),
              align: TextAlign.right,
              onTap: null,
            ),
          ),
          SizedBox(
            width: _statusCellWidth,
            child: Text(
              _statusLabel(row.status),
              style: styles.listSupporting.copyWith(color: statusColor),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableMoneyCell extends StatefulWidget {
  const _EditableMoneyCell({
    required this.value,
    required this.style,
    required this.canEdit,
    required this.allowZero,
    required this.onCommit,
    super.key,
  });

  final Money value;
  final TextStyle style;
  final bool canEdit;
  final bool allowZero;
  final ValueChanged<Money> onCommit;

  @override
  State<_EditableMoneyCell> createState() => _EditableMoneyCellState();
}

class _EditableMoneyCellState extends State<_EditableMoneyCell> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _commit();
    }
  }

  void _startEdit() {
    if (!widget.canEdit || _isEditing) return;
    final text =
        widget.value.minorUnits == 0 ? '' : widget.value.major.toString();
    _controller.text = text;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _commit() {
    if (!_isEditing) return;
    final text = _controller.text.trim();
    Money? next;
    if (text.isEmpty) {
      if (widget.allowZero) next = Money.zero();
    } else {
      try {
        final m = Money.parse(text);
        if (m.minorUnits >= 0 && (widget.allowZero || m.minorUnits > 0)) {
          next = m;
        }
      } on FormatException {
        // ignore — revert below
      }
    }
    setState(() => _isEditing = false);
    if (next != null && next != widget.value) {
      widget.onCommit(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_isEditing) {
      return Container(
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        child: AppPlainTextFormField(
          controller: _controller,
          focusNode: _focusNode,
          textAlign: TextAlign.right,
          style: widget.style,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _commit(),
        ),
      );
    }
    final cell = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space6,
      ),
      child: Text(
        widget.value.format(),
        style: widget.style,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (!widget.canEdit) return cell;
    return InkWell(onTap: _startEdit, child: cell);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.text,
    required this.style,
    required this.align,
    required this.onTap,
  });

  final String text;
  final TextStyle style;
  final TextAlign align;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space2,
        vertical: AppSpacing.space6,
      ),
      child: Text(
        text,
        style: style,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _MetricsSection extends StatelessWidget {
  const _MetricsSection({required this.metricsAsync, required this.principal});

  final AsyncValue<ContractMetrics> metricsAsync;
  final Money principal;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            0,
            AppSpacing.space4,
            AppSpacing.space4,
          ),
          child: Text('合同汇总', style: styles.dateSectionTitle),
        ),
        switch (metricsAsync) {
          AsyncData(value: final metrics) => AppSurface(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space12),
              child: _MetricGrid(metrics: metrics, principal: principal),
            ),
          ),
          AsyncError() => AppSurface(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space12),
              child: const Text('合同指标加载失败，请稍后重试'),
            ),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(AppSpacing.space12),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.principal});

  final ContractMetrics metrics;
  final Money principal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCell(
                label: '月 IRR',
                value: _formatPercent(metrics.monthlyIrr),
              ),
            ),
            Expanded(
              child: _MetricCell(
                label: '名义年化 APR',
                value: _formatPercent(metrics.nominalApr),
              ),
            ),
            Expanded(
              child: _MetricCell(
                label: '有效年化 EAR',
                value: _formatPercent(metrics.effectiveApr),
              ),
            ),
          ],
        ),
        if (metrics.unavailableReason case final reason?) ...[
          const SizedBox(height: AppSpacing.space8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'IRR / APR / EAR 暂不可计算：${_metricsUnavailableReasonText(reason)}',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.space10),
        Row(
          children: [
            Expanded(
              child: _MetricCell(label: '本金', value: principal.format()),
            ),
            Expanded(
              child: _MetricCell(
                label: '总利息',
                value: metrics.totalInterest.format(),
              ),
            ),
            Expanded(
              child: _MetricCell(
                label: '总费用',
                value: metrics.totalFee.format(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = context.appTextStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: styles.listSupporting.copyWith(color: colors.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.space2),
        Text(
          value,
          style: styles.formLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _formatDateShort(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _statusLabel(InstallmentScheduleStatus status) {
  return switch (status) {
    InstallmentScheduleStatus.pending => '待还',
    InstallmentScheduleStatus.partiallyPaid => '部分已还',
    InstallmentScheduleStatus.paid => '已还',
    InstallmentScheduleStatus.skipped => '已跳过',
  };
}

String _sourceTypeLabel(InstallmentSourceType type) {
  return switch (type) {
    InstallmentSourceType.disbursement => '放款分期',
    InstallmentSourceType.billConversion => '账单分期',
  };
}

String _formatPercent(double? v) {
  if (v == null) return '—';
  if (v.isNaN || v.isInfinite) return '—';
  return '${(v * 100).toStringAsFixed(2)}%';
}

String _metricsUnavailableReasonText(ContractMetricsUnavailableReason reason) {
  return switch (reason) {
    ContractMetricsUnavailableReason.principalNotConserved => '计划本金与合同本金不守恒',
    ContractMetricsUnavailableReason.insufficientCashflows => '现金流不足',
    ContractMetricsUnavailableReason.noRateSolution => '不存在有效利率解',
  };
}
