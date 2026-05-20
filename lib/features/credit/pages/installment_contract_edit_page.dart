import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../design_system/widgets/app_datetime_picker.dart';
import '../../../design_system/widgets/app_plain_form_row.dart';
import '../../../design_system/widgets/app_submit_button.dart';
import '../../../design_system/widgets/app_surface.dart';
import '../../../domain/credit/entities/installment_contract.dart';
import '../../../domain/credit/entities/installment_schedule.dart';
import '../../../domain/credit/enums/installment_enums.dart';
import '../../../domain/credit/services/installment_metrics.dart';
import '../../../domain/credit/services/installment_schedule_generator.dart';
import '../../../domain/credit/services/installment_service.dart';
import '../../../widgets/business/plain_transaction_fields.dart';
import '../widgets/installment_field_options.dart';

class InstallmentContractEditPage extends ConsumerStatefulWidget {
  const InstallmentContractEditPage({required this.contractId, super.key});

  final int contractId;

  @override
  ConsumerState<InstallmentContractEditPage> createState() =>
      _InstallmentContractEditPageState();
}

class _InstallmentContractEditPageState
    extends ConsumerState<InstallmentContractEditPage> {
  static const _generator = InstallmentScheduleGenerator();

  final _formKey = GlobalKey<FormState>();
  final _periodsController = TextEditingController();
  final _rateController = TextEditingController();
  final _feeController = TextEditingController();
  final _overrideInstallmentController = TextEditingController();

  late DateTime _firstRepaymentDate;
  late DateTime _lastRepaymentDate;
  late InstallmentRepaymentMethod _method;
  late InterestRatePeriod _ratePeriod;
  late InterestAccrualMethod _accrualMethod;

  // 当前显示的还款计划（预览）。
  List<_DraftRow> _draft = const [];
  // 自上次"按配置重算"以来手工修改过的 periodNo。
  final Set<int> _manualPatched = {};

  InstallmentContract? _contract;
  int _paidCount = 0;
  String _currency = Money.defaultCurrency;
  bool _initialized = false;
  bool _submitting = false;

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
    final contractAsync =
        ref.watch(installmentContractProvider(widget.contractId));
    final schedulesAsync =
        ref.watch(installmentSchedulesProvider(widget.contractId));
    final metricsAsync =
        ref.watch(installmentMetricsProvider(widget.contractId));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('编辑合同')),
      body: switch ((contractAsync, schedulesAsync)) {
        (AsyncData(value: final contract), AsyncData(value: final schedules)) =>
          contract == null
              ? const Center(child: Text('合同不存在'))
              : _buildBody(contract, schedules, metricsAsync),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) =>
          Center(child: Text('加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildBody(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
    AsyncValue<({ContractMetrics designed, ContractMetrics actual})>
        metricsAsync,
  ) {
    if (!_initialized) {
      _initialize(contract, schedules);
    }

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
            paidCount: _paidCount,
            firstRepaymentDate: _firstRepaymentDate,
            lastRepaymentDate: _lastRepaymentDate,
            method: _method,
            ratePeriod: _ratePeriod,
            accrualMethod: _accrualMethod,
            periodsController: _periodsController,
            rateController: _rateController,
            feeController: _feeController,
            overrideInstallmentController: _overrideInstallmentController,
            onPickFirstDate: _paidCount > 0 ? null : _pickFirstDate,
            onPickLastDate: _pickLastDate,
            onMethodChanged: (v) => setState(() => _method = v),
            onRatePeriodChanged: (v) => setState(() => _ratePeriod = v),
            onAccrualMethodChanged: _paidCount > 0
                ? null
                : (v) => setState(() => _accrualMethod = v),
            onRecalculate: _recalculate,
          ),
          const SizedBox(height: AppSpacing.space12),
          _ScheduleSection(
            draft: _draft,
            currency: _currency,
            manualPatched: _manualPatched,
            onApplyAmount: _applyAmount,
            onEditDate: _editScheduleDate,
          ),
          const SizedBox(height: AppSpacing.space20),
          AppSubmitButton(
            label: '保存',
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  void _initialize(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  ) {
    _initialized = true;
    _contract = contract;
    _currency = contract.principal.currency;
    _paidCount = schedules
        .where((s) => s.status == InstallmentScheduleStatus.paid)
        .length;
    _firstRepaymentDate = contract.firstRepaymentDate;
    _lastRepaymentDate = contract.lastRepaymentDate;
    _method = contract.repaymentMethod;
    _ratePeriod = contract.interestRatePeriod ?? InterestRatePeriod.monthly;
    _accrualMethod = contract.interestAccrualMethod;

    _periodsController.text = contract.totalPeriods.toString();
    if (contract.interestRatePpm != null && contract.interestRatePpm! > 0) {
      final percent = contract.interestRatePpm! / 10000.0;
      _rateController.text = _trimTrailingZeros(percent.toStringAsFixed(4));
    }
    if (contract.totalFeeMinor > 0) {
      _feeController.text = Money(
        minorUnits: contract.totalFeeMinor,
        currency: _currency,
      ).major.toString();
    }
    // 还款固定额是瞬态输入，不从合同读取（也不落库）。
    _overrideInstallmentController.text = '';

    _draft = [
      for (final s in schedules)
        _DraftRow(
          scheduleId: s.id,
          periodNo: s.periodNo,
          date: s.expectedRepaymentDate,
          principal: s.expectedPrincipal,
          interest: s.expectedInterest,
          fee: s.expectedFee,
          status: s.status,
        ),
    ];
  }

  Future<void> _pickFirstDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _firstRepaymentDate,
      title: '选择首期还款日',
    );
    if (picked == null || !mounted) return;
    setState(() => _firstRepaymentDate = picked);
  }

  Future<void> _pickLastDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _lastRepaymentDate,
      title: '选择末期还款日',
    );
    if (picked == null || !mounted) return;
    setState(() => _lastRepaymentDate = picked);
  }

  void _recalculate() {
    final contract = _contract;
    if (contract == null) return;
    final totalPeriods = int.tryParse(_periodsController.text.trim());
    if (totalPeriods == null || totalPeriods <= 0) {
      _showError('请输入有效期数');
      return;
    }
    if (totalPeriods < _paidCount + 1) {
      _showError('期数必须不小于已还期数 + 1');
      return;
    }
    if (totalPeriods > 1 &&
        !_lastRepaymentDate.isAfter(_firstRepaymentDate)) {
      _showError('末期还款日必须晚于首期还款日');
      return;
    }

    final ratePpm = _parseRatePpm(_rateController.text);
    final feeMinor = _parseOptionalMoney(_feeController.text).minorUnits;
    final overrideMinor =
        _method == InstallmentRepaymentMethod.equalInstallment
            ? _parseOptionalOverride(_overrideInstallmentController.text)
            : null;

    // 复用 service 端的算法：以同样的 generator 在本地生成预览。
    final allDates = _generator.generateDates(
      firstRepaymentDate: _firstRepaymentDate,
      lastRepaymentDate: _lastRepaymentDate,
      totalPeriods: totalPeriods,
    );
    final pendingDates = allDates.sublist(_paidCount);

    final paidRows = _draft
        .where((r) => r.status == InstallmentScheduleStatus.paid)
        .toList()
      ..sort((a, b) => a.periodNo.compareTo(b.periodNo));

    final paidPrincipalMinor = paidRows.fold<int>(
      0,
      (acc, r) => acc + r.principal.minorUnits,
    );
    final paidFeeMinor =
        paidRows.fold<int>(0, (acc, r) => acc + r.fee.minorUnits);
    final remainingMinor =
        contract.principal.minorUnits - paidPrincipalMinor;
    if (remainingMinor < 0) {
      _showError('剩余本金为负，无法重算');
      return;
    }
    final anchorDate =
        paidRows.isEmpty ? contract.borrowingDate : paidRows.last.date;

    final remainingFeeMinor = feeMinor - paidFeeMinor;
    final allocations = _generator.allocate(
      remainingPrincipal: Money(
        minorUnits: remainingMinor,
        currency: _currency,
      ),
      anchorDate: anchorDate,
      pendingDates: pendingDates,
      method: _method,
      accrualMethod: _accrualMethod,
      ratePeriod: ratePpm == null ? null : _ratePeriod,
      ratePpm: ratePpm,
      remainingFeeMinor: remainingFeeMinor < 0 ? 0 : remainingFeeMinor,
      equalInstallmentOverrideMinor: overrideMinor,
    );

    final newDraft = <_DraftRow>[];
    for (var i = 0; i < paidRows.length; i++) {
      newDraft.add(paidRows[i]);
    }
    for (var i = 0; i < pendingDates.length; i++) {
      final existing = _draft
          .where((r) =>
              r.status != InstallmentScheduleStatus.paid &&
              r.periodNo == paidRows.length + i + 1)
          .firstOrNull;
      newDraft.add(
        _DraftRow(
          scheduleId: existing?.scheduleId,
          periodNo: paidRows.length + i + 1,
          date: pendingDates[i],
          principal: allocations[i].principal,
          interest: allocations[i].interest,
          fee: allocations[i].fee,
          status: InstallmentScheduleStatus.pending,
        ),
      );
    }
    setState(() {
      _draft = newDraft;
      _manualPatched.clear();
    });
  }

  void _applyAmount(_DraftRow row, _AmountField field, Money value) {
    if (row.status != InstallmentScheduleStatus.pending) return;
    final newRow = switch (field) {
      _AmountField.principal => row.copyWith(principal: value),
      _AmountField.interest => row.copyWith(interest: value),
      _AmountField.fee => row.copyWith(fee: value),
    };
    setState(() {
      _draft = [
        for (final r in _draft) if (r.periodNo == row.periodNo) newRow else r,
      ];
      _manualPatched.add(row.periodNo);
    });
  }

  Future<void> _editScheduleDate(_DraftRow row) async {
    if (row.status != InstallmentScheduleStatus.pending) return;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: row.date,
      title: '选择第 ${row.periodNo} 期还款日',
    );
    if (picked == null || !mounted) return;
    final newRow = row.copyWith(date: picked);
    setState(() {
      _draft = [
        for (final r in _draft) if (r.periodNo == row.periodNo) newRow else r,
      ];
      _manualPatched.add(row.periodNo);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final contract = _contract;
    if (contract == null) return;
    final totalPeriods = int.tryParse(_periodsController.text.trim());
    if (totalPeriods == null || totalPeriods <= 0) {
      _showError('请输入有效期数');
      return;
    }
    if (totalPeriods < _paidCount + 1) {
      _showError('期数必须不小于已还期数 + 1');
      return;
    }

    final ratePpm = _parseRatePpm(_rateController.text);
    final feeMinor = _parseOptionalMoney(_feeController.text).minorUnits;
    final overrideMinor =
        _method == InstallmentRepaymentMethod.equalInstallment
            ? _parseOptionalOverride(_overrideInstallmentController.text)
            : null;

    // 手工修改过的 pending 行：构造 patch。
    final patches = <SchedulePendingPatch>[
      for (final periodNo in _manualPatched)
        if (_draft.any((r) => r.periodNo == periodNo))
          () {
            final row = _draft.firstWhere((r) => r.periodNo == periodNo);
            return SchedulePendingPatch(
              periodNo: periodNo,
              expectedPrincipal: row.principal,
              expectedInterest: row.interest,
              expectedFee: row.fee,
              expectedRepaymentDate: row.date,
            );
          }(),
    ];

    setState(() => _submitting = true);
    final service = ref.read(installmentServiceProvider);
    final result = await service.updateContract(
      UpdateContractCommand(
        contractId: widget.contractId,
        totalPeriods: totalPeriods,
        firstRepaymentDate: _firstRepaymentDate,
        lastRepaymentDate: _lastRepaymentDate,
        repaymentMethod: _method,
        interestRatePeriod: ratePpm == null
            ? const Patch<InterestRatePeriod>.clear()
            : Patch.set(_ratePeriod),
        interestRatePpm: ratePpm == null
            ? const Patch<int>.clear()
            : Patch.set(ratePpm),
        interestAccrualMethod: _accrualMethod,
        totalFeeMinor: feeMinor,
        equalInstallmentOverrideMinor: overrideMinor,
        // 备注已从本页移除，不修改 contract.note
        schedulePatches: patches,
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case Success():
        ref.invalidate(installmentContractProvider(widget.contractId));
        ref.invalidate(installmentSchedulesProvider(widget.contractId));
        ref.invalidate(installmentRepaymentsProvider(widget.contractId));
        ref.invalidate(installmentMetricsProvider(widget.contractId));
        ref.invalidate(installmentContractsByAccountProvider(
          contract.liabilityAccountId,
        ));
        context.pop();
      case FailureResult(:final failure):
        _showError(failure.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  int? _parseRatePpm(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final percent = double.tryParse(trimmed);
    if (percent == null || percent <= 0) return null;
    return (percent * 10000).round();
  }

  Money _parseOptionalMoney(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return Money.zero(currency: _currency);
    try {
      return Money.parse(trimmed);
    } on FormatException {
      return Money.zero(currency: _currency);
    }
  }

  /// 解析"还款固定额"输入；空或非正返回 null（回落公式推导）。
  int? _parseOptionalOverride(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      final money = Money.parse(trimmed, currency: _currency);
      return money.minorUnits > 0 ? money.minorUnits : null;
    } on FormatException {
      return null;
    }
  }

  String _trimTrailingZeros(String text) {
    if (!text.contains('.')) return text;
    var out = text;
    while (out.endsWith('0')) {
      out = out.substring(0, out.length - 1);
    }
    if (out.endsWith('.')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }
}

/// 表格预览用的临时 row 模型，区别于持久 InstallmentSchedule（可能尚无 id）。
class _DraftRow {
  _DraftRow({
    required this.periodNo,
    required this.date,
    required this.principal,
    required this.interest,
    required this.fee,
    required this.status,
    this.scheduleId,
  });

  final int? scheduleId;
  final int periodNo;
  final DateTime date;
  final Money principal;
  final Money interest;
  final Money fee;
  final InstallmentScheduleStatus status;

  Money get total => principal + interest + fee;

  _DraftRow copyWith({
    DateTime? date,
    Money? principal,
    Money? interest,
    Money? fee,
  }) {
    return _DraftRow(
      scheduleId: scheduleId,
      periodNo: periodNo,
      date: date ?? this.date,
      principal: principal ?? this.principal,
      interest: interest ?? this.interest,
      fee: fee ?? this.fee,
      status: status,
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
    required this.onMethodChanged,
    required this.onRatePeriodChanged,
    required this.onAccrualMethodChanged,
    required this.onRecalculate,
  });

  final InstallmentContract contract;
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
  final VoidCallback? onPickFirstDate;
  final VoidCallback onPickLastDate;
  final ValueChanged<InstallmentRepaymentMethod> onMethodChanged;
  final ValueChanged<InterestRatePeriod> onRatePeriodChanged;
  final ValueChanged<InterestAccrualMethod>? onAccrualMethodChanged;
  final VoidCallback onRecalculate;

  static const double _rowMinHeight = 44;

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
          child: Text('分期配置', style: styles.dateSectionTitle),
        ),
        AppSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space12,
              vertical: AppSpacing.space4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPlainFormSection(
                  children: [
                    AppPlainFormRow(
                      label: '借款日期',
                      minHeight: _rowMinHeight,
                      child: _readOnly(
                        context,
                        _formatDate(contract.borrowingDate),
                      ),
                    ),
                    AppPlainFormRow(
                      label: '分期类型',
                      minHeight: _rowMinHeight,
                      child: _readOnly(
                        context,
                        _sourceTypeLabel(contract.sourceType),
                      ),
                    ),
                    AppPlainFormRow(
                      label: '本金',
                      minHeight: _rowMinHeight,
                      child: _readOnly(context, contract.principal.format()),
                    ),
                    _IntegerPlainFormRow(
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
                      value: _formatDate(firstRepaymentDate),
                      onTap: onPickFirstDate,
                      minHeight: _rowMinHeight,
                    ),
                    DateTimePlainFormRow(
                      label: '末期还款日',
                      value: _formatDate(lastRepaymentDate),
                      onTap: onPickLastDate,
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
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                  ],
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _readOnly(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      text,
      style: context.appTextStyles.formPlainValue
          .copyWith(color: colors.onSurface),
    );
  }
}

enum _AmountField { principal, interest, fee }

typedef _ApplyAmount = void Function(
  _DraftRow row,
  _AmountField field,
  Money value,
);

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.draft,
    required this.currency,
    required this.manualPatched,
    required this.onApplyAmount,
    required this.onEditDate,
  });

  final List<_DraftRow> draft;
  final String currency;
  final Set<int> manualPatched;
  final _ApplyAmount onApplyAmount;
  final ValueChanged<_DraftRow> onEditDate;

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
                    currency: currency,
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
const double _dateCellWidth = 56;
const double _statusCellWidth = 36;

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.row,
    required this.currency,
    required this.edited,
    required this.onApplyAmount,
    required this.onEditDate,
  });

  final _DraftRow row;
  final String currency;
  final bool edited;
  final _ApplyAmount onApplyAmount;
  final ValueChanged<_DraftRow> onEditDate;

  @override
  Widget build(BuildContext context) {
    final styles = context.appTextStyles;
    final colors = Theme.of(context).colorScheme;
    final pending = row.status == InstallmentScheduleStatus.pending;
    final statusColor = switch (row.status) {
      InstallmentScheduleStatus.pending => colors.primary,
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
              currency: currency,
              onCommit: (m) => onApplyAmount(row, _AmountField.principal, m),
            ),
          ),
          Expanded(
            child: _EditableMoneyCell(
              key: ValueKey('i-${row.periodNo}'),
              value: row.interest,
              style: cellStyle,
              canEdit: pending,
              allowZero: true,
              currency: currency,
              onCommit: (m) => onApplyAmount(row, _AmountField.interest, m),
            ),
          ),
          Expanded(
            child: _EditableMoneyCell(
              key: ValueKey('f-${row.periodNo}'),
              value: row.fee,
              style: cellStyle,
              canEdit: pending,
              allowZero: true,
              currency: currency,
              onCommit: (m) => onApplyAmount(row, _AmountField.fee, m),
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
    required this.currency,
    required this.onCommit,
    super.key,
  });

  final Money value;
  final TextStyle style;
  final bool canEdit;
  final bool allowZero;
  final String currency;
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
      if (widget.allowZero) next = Money.zero(currency: widget.currency);
    } else {
      try {
        final m = Money.parse(text, currency: widget.currency);
        if (m.minorUnits >= 0 &&
            (widget.allowZero || m.minorUnits > 0)) {
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
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textAlign: TextAlign.right,
          style: widget.style,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.space6),
            border: InputBorder.none,
            isCollapsed: false,
          ),
          onSubmitted: (_) => _commit(),
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
  const _MetricsSection({
    required this.metricsAsync,
    required this.principal,
  });

  final AsyncValue<({ContractMetrics designed, ContractMetrics actual})>
      metricsAsync;
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
          child: Text(
            '汇总信息（合同 / 履约）',
            style: styles.dateSectionTitle,
          ),
        ),
        switch (metricsAsync) {
          AsyncData(value: final pair) =>
            _MetricsPair(pair: pair, principal: principal),
          AsyncError(:final error) => AppSurface(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.space12),
                child: Text('指标加载失败：$error'),
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

class _MetricsPair extends StatelessWidget {
  const _MetricsPair({required this.pair, required this.principal});

  final ({ContractMetrics designed, ContractMetrics actual}) pair;
  final Money principal;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space12),
        child: _MetricGrid(
          designed: pair.designed,
          actual: pair.actual,
          principal: principal,
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.designed,
    required this.actual,
    required this.principal,
  });

  final ContractMetrics designed;
  final ContractMetrics actual;
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
                designed: _formatPercent(designed.monthlyIrr),
                actual: _formatPercent(actual.monthlyIrr),
              ),
            ),
            Expanded(
              child: _MetricCell(
                label: '名义年化 APR',
                designed: _formatPercent(designed.nominalApr),
                actual: _formatPercent(actual.nominalApr),
              ),
            ),
            Expanded(
              child: _MetricCell(
                label: '有效年化 EAR',
                designed: _formatPercent(designed.effectiveApr),
                actual: _formatPercent(actual.effectiveApr),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space10),
        Row(
          children: [
            Expanded(
              child: _MetricCell.single(
                label: '本金',
                value: principal.format(),
              ),
            ),
            Expanded(
              child: _MetricCell(
                label: '总利息',
                designed: designed.totalInterest.format(),
                actual: actual.totalInterest.format(),
              ),
            ),
            Expanded(
              child: _MetricCell(
                label: '总费用',
                designed: designed.totalFee.format(),
                actual: actual.totalFee.format(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required String this.designed,
    required String this.actual,
  }) : single = null;

  const _MetricCell.single({
    required this.label,
    required String value,
  })  : designed = null,
        actual = null,
        single = value;

  final String label;
  final String? designed;
  final String? actual;
  final String? single;

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
        if (single != null)
          Text(
            single!,
            style: styles.formLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        else
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: designed!, style: styles.formLabel),
                TextSpan(
                  text: ' / ',
                  style: styles.listSupporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: actual!,
                  style: styles.formLabel.copyWith(color: colors.primary),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _IntegerPlainFormRow extends StatelessWidget {
  const _IntegerPlainFormRow({
    required this.label,
    required this.controller,
    required this.hintText,
    this.validator,
    this.minHeight = 56,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AppPlainFormRow(
      label: label,
      minHeight: minHeight,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: hintText,
          isDense: true,
          border: InputBorder.none,
        ),
        validator: validator,
      ),
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

String _formatPercent(double v) {
  if (v.isNaN || v.isInfinite) return '—';
  return '${(v * 100).toStringAsFixed(2)}%';
}
