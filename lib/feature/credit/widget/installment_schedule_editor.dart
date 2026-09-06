import 'package:flutter/material.dart';

import '../../../application/credit/credit_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/finance/money_input.dart';
import '../presentation/installment_schedule_presentation.dart';
import '../view_model/installment_schedule_draft.dart';

typedef InstallmentScheduleAmountChanged =
    void Function(
      InstallmentContractDraftRow row,
      InstallmentAmountField field,
      Money value,
    );

class InstallmentScheduleEditor extends StatelessWidget {
  const InstallmentScheduleEditor({
    required this.draft,
    required this.manualPatched,
    required this.onApplyAmount,
    required this.onEditDate,
    super.key,
  });

  final List<InstallmentContractDraftRow> draft;
  final Set<int> manualPatched;
  final InstallmentScheduleAmountChanged onApplyAmount;
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
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth < 620 ? 620 : constraints.maxWidth,
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
                          key: ValueKey(
                            draft[i].scheduleId ?? 'draft-${draft[i].periodNo}',
                          ),
                          row: draft[i],
                          edited: manualPatched.contains(draft[i].periodNo),
                          onApplyAmount: onApplyAmount,
                          onEditDate: onEditDate,
                        ),
                        if (i < draft.length - 1)
                          Divider(
                            height: 1,
                            color: colors.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
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
          SizedBox(
            width: _dateCellWidth,
            child: Text('时间', style: labelStyle),
          ),
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
const double _dateCellWidth = 88;
const double _statusCellWidth = 36;

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.row,
    required this.edited,
    required this.onApplyAmount,
    required this.onEditDate,
    super.key,
  });

  final InstallmentContractDraftRow row;
  final bool edited;
  final InstallmentScheduleAmountChanged onApplyAmount;
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
              text: formatDateLabel(row.date),
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
              onCommit: (m) =>
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
              onCommit: (m) =>
                  onApplyAmount(row, InstallmentAmountField.interest, m),
            ),
          ),
          Expanded(
            child: _EditableMoneyCell(
              key: ValueKey('f-${row.periodNo}'),
              value: row.fee,
              style: cellStyle,
              canEdit: pending,
              allowZero: true,
              onCommit: (m) =>
                  onApplyAmount(row, InstallmentAmountField.fee, m),
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
              installmentScheduleStatusLabel(row.status),
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
    final text = widget.value.minorUnits == 0
        ? ''
        : widget.value.major.toString();
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
          inputFormatters: [moneyInputFormatter],
          validator: widget.allowZero
              ? validateOptionalNonNegativeMoneyText
              : validatePositiveMoneyText,
          onFieldSubmitted: (_) => _commit(),
          onSaved: (_) => _commit(),
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
