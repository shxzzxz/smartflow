import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/insurance/insurance_command_api.dart';
import '../../../application/insurance/insurance_query_api.dart';
import '../../../core/money/money.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/insurance_presentation.dart';
import 'commercial_insurance_list_view_model.dart';
import 'commercial_insurance_detail_view_model.dart';
import 'insurance_members_view_model.dart';
import 'insurance_overview_view_model.dart';
import 'member_coverage_view_model.dart';

part 'commercial_insurance_form_view_model.g.dart';

final _logger = Logger('feature.insurance.commercial_form');

@riverpod
class CommercialInsuranceFormViewModel
    extends _$CommercialInsuranceFormViewModel {
  CommercialInsuranceFormState? _initializedState;

  @override
  Future<CommercialInsuranceFormState?> build(
    String? insuranceId,
    String? initialInsuredPersonId,
  ) async {
    final query = ref.watch(insuranceCoverageQueryServiceProvider);
    final people = await query.listInsuredPeople();
    if (insuranceId == null) {
      return _initializedState ??= CommercialInsuranceFormState.initial(
        insuredPeople: people,
        initialInsuredPersonId: initialInsuredPersonId,
        today: DateTime.now(),
      );
    }
    final detail = await query.commercialInsuranceDetail(insuranceId);
    if (detail == null) return null;
    return _initializedState ??= CommercialInsuranceFormState.fromInsurance(
      detail.insurance,
      insuredPeople: people,
    );
  }

  void setCategory(CommercialInsuranceCategory value) {
    _update((current) => current.copyWith(category: value));
  }

  void setCoverageStartDate(DateTime value) {
    _update((current) => current.copyWith(coverageStartDate: value));
  }

  void setCoverageEndDate(DateTime? value) {
    _update((current) => current.copyWith(coverageEndDate: value));
  }

  void setLifetime(bool value) {
    _update(
      (current) => current.copyWith(
        lifetime: value,
        coverageEndDate: value ? null : current.coverageEndDate,
      ),
    );
  }

  void setPremiumFrequency(PremiumFrequency value) {
    _update((current) => current.copyWith(premiumFrequency: value));
  }

  void toggleInsuredPerson(String insuredPersonId) {
    _update((current) {
      final next = Set<String>.of(current.insuredPersonIds);
      if (!next.remove(insuredPersonId)) next.add(insuredPersonId);
      return current.copyWith(insuredPersonIds: next.toList());
    });
  }

  Future<UiActionOutcome<String>> save({
    required String nameText,
    required String insurerNameText,
    required String productFormText,
    required String coverageAmountText,
    required String premiumAmountText,
    required String premiumTermCountText,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalid('商业保险表单尚未加载');
    if (current.submitting) return _invalid('正在保存，请勿重复提交');
    final name = nameText.trim();
    final insurerName = insurerNameText.trim();
    if (name.isEmpty || insurerName.isEmpty) {
      return _invalid('请填写保险名称和保险公司');
    }
    if (current.insuredPersonIds.isEmpty) {
      return _invalid('请至少选择一个被保险人');
    }

    final coverageAmount = _coverageAmount(amountText: coverageAmountText);
    if (coverageAmount.error != null) {
      return _invalid(coverageAmount.error!);
    }
    final premiumAmount = _moneyOrNull(premiumAmountText);
    if (premiumAmount.invalid || (premiumAmount.money?.minorUnits ?? 0) < 0) {
      return _invalid('请输入有效的期缴金额');
    }
    final premiumTermCount = _positiveIntegerOrNull(premiumTermCountText);
    if (premiumTermCount.invalid) {
      return _invalid('缴费期数必须为正整数');
    }
    final coverageTerm = CoverageTerm(
      startDate: current.coverageStartDate,
      endDate: current.lifetime ? null : current.coverageEndDate,
      lifetime: current.lifetime,
    );
    try {
      coverageTerm.validate();
    } on ArgumentError {
      return _invalid('保障结束日期不能早于开始日期');
    }

    _update((value) => value.copyWith(submitting: true));
    try {
      final outcome = await guardUiAction(
        _logger,
        'Save commercial insurance',
        () => ref
            .read(commercialInsuranceAppServiceProvider)
            .save(
              SaveCommercialInsuranceCommand(
                id: current.id,
                name: name,
                insurerName: insurerName,
                category: current.category,
                productForm: _nullIfBlank(productFormText),
                coverageTerm: coverageTerm,
                coverageAmount: coverageAmount.value,
                premiumPlan: PremiumPlan(
                  amount: premiumAmount.money,
                  frequency: current.premiumFrequency,
                  termCount: premiumTermCount.value,
                ),
                insuredPersonIds: current.insuredPersonIds,
              ),
            ),
      );
      if (outcome is UiActionSuccess<String>) {
        ref.invalidate(insuranceMembersViewModelProvider);
        ref.invalidate(insuranceOverviewViewModelProvider);
        ref.invalidate(commercialInsuranceListViewModelProvider);
        ref.invalidate(memberCoverageViewModelProvider);
        ref.invalidate(commercialInsuranceDetailViewModelProvider);
      }
      return outcome;
    } finally {
      if (ref.mounted) {
        _update((latest) => latest.copyWith(submitting: false));
      }
    }
  }

  _MoneyResult _moneyOrNull(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const _MoneyResult(money: null);
    final money = Money.tryParse(trimmed);
    return money == null
        ? const _MoneyResult.invalid()
        : _MoneyResult(money: money);
  }

  _CoverageAmountResult _coverageAmount({required String amountText}) {
    final amount = _moneyOrNull(amountText);
    if (amount.invalid) {
      return const _CoverageAmountResult(error: '请输入有效的保额');
    }
    if ((amount.money?.minorUnits ?? 0) < 0) {
      return const _CoverageAmountResult(error: '保额不能为负');
    }
    return _CoverageAmountResult(
      value: amount.money == null ? null : CoverageAmount(amount: amount.money),
    );
  }

  _IntegerResult _positiveIntegerOrNull(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const _IntegerResult();
    final value = int.tryParse(trimmed);
    return value == null || value <= 0
        ? const _IntegerResult.invalid()
        : _IntegerResult(value: value);
  }

  void _update(
    CommercialInsuranceFormState Function(CommercialInsuranceFormState) update,
  ) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = update(current);
    _initializedState = next;
    state = AsyncData(next);
  }

  UiActionOutcome<String> _invalid(String message) {
    return UiActionOutcome.failure(
      UiError(code: InsuranceErrorCode.invalidCommand.code, message: message),
    );
  }
}

class CommercialInsuranceFormState {
  CommercialInsuranceFormState({
    required this.initialValues,
    required this.insuredPeople,
    required this.category,
    required this.coverageStartDate,
    required this.lifetime,
    required this.premiumFrequency,
    required List<String> insuredPersonIds,
    this.id,
    this.coverageEndDate,
    this.submitting = false,
  }) : insuredPersonIds = List.unmodifiable(insuredPersonIds);

  factory CommercialInsuranceFormState.initial({
    required List<InsuredPerson> insuredPeople,
    required DateTime today,
    String? initialInsuredPersonId,
  }) {
    return CommercialInsuranceFormState(
      initialValues: const CommercialInsuranceFormInitialValues(),
      insuredPeople: List.unmodifiable(insuredPeople),
      category: CommercialInsuranceCategory.medical,
      coverageStartDate: DateTime(today.year, today.month, today.day),
      lifetime: false,
      premiumFrequency: PremiumFrequency.other,
      insuredPersonIds: [?initialInsuredPersonId],
    );
  }

  factory CommercialInsuranceFormState.fromInsurance(
    CommercialInsurance insurance, {
    required List<InsuredPerson> insuredPeople,
  }) {
    return CommercialInsuranceFormState(
      id: insurance.id,
      initialValues: CommercialInsuranceFormInitialValues.fromInsurance(
        insurance,
      ),
      insuredPeople: List.unmodifiable(insuredPeople),
      category: insurance.category,
      coverageStartDate: insurance.coverageTerm.startDate,
      coverageEndDate: insurance.coverageTerm.endDate,
      lifetime: insurance.coverageTerm.lifetime,
      premiumFrequency:
          insurance.premiumPlan?.frequency ?? PremiumFrequency.other,
      insuredPersonIds: insurance.insuredPersonIds,
    );
  }

  final String? id;
  final CommercialInsuranceFormInitialValues initialValues;
  final List<InsuredPerson> insuredPeople;
  final CommercialInsuranceCategory category;
  final DateTime coverageStartDate;
  final DateTime? coverageEndDate;
  final bool lifetime;
  final List<String> insuredPersonIds;
  final PremiumFrequency premiumFrequency;
  final bool submitting;

  CommercialInsuranceFormState copyWith({
    CommercialInsuranceCategory? category,
    DateTime? coverageStartDate,
    Object? coverageEndDate = _sentinel,
    bool? lifetime,
    List<String>? insuredPersonIds,
    PremiumFrequency? premiumFrequency,
    bool? submitting,
  }) {
    return CommercialInsuranceFormState(
      id: id,
      initialValues: initialValues,
      insuredPeople: insuredPeople,
      category: category ?? this.category,
      coverageStartDate: coverageStartDate ?? this.coverageStartDate,
      coverageEndDate: coverageEndDate == _sentinel
          ? this.coverageEndDate
          : coverageEndDate as DateTime?,
      lifetime: lifetime ?? this.lifetime,
      insuredPersonIds: insuredPersonIds ?? this.insuredPersonIds,
      premiumFrequency: premiumFrequency ?? this.premiumFrequency,
      submitting: submitting ?? this.submitting,
    );
  }
}

class CommercialInsuranceFormInitialValues {
  const CommercialInsuranceFormInitialValues({
    this.name = '',
    this.insurerName = '',
    this.productForm = '',
    this.coverageAmount = '',
    this.premiumAmount = '',
    this.premiumTermCount = '',
  });

  factory CommercialInsuranceFormInitialValues.fromInsurance(
    CommercialInsurance insurance,
  ) {
    return CommercialInsuranceFormInitialValues(
      name: insurance.name,
      insurerName: insurance.insurerName,
      productForm: insurance.productForm ?? '',
      coverageAmount: insuranceMoneyInputText(insurance.coverageAmount?.amount),
      premiumAmount: insuranceMoneyInputText(insurance.premiumPlan?.amount),
      premiumTermCount: insurance.premiumPlan?.termCount?.toString() ?? '',
    );
  }

  final String name;
  final String insurerName;
  final String productForm;
  final String coverageAmount;
  final String premiumAmount;
  final String premiumTermCount;
}

class _MoneyResult {
  const _MoneyResult({required this.money}) : invalid = false;
  const _MoneyResult.invalid() : money = null, invalid = true;

  final Money? money;
  final bool invalid;
}

class _CoverageAmountResult {
  const _CoverageAmountResult({this.value, this.error});

  final CoverageAmount? value;
  final String? error;
}

class _IntegerResult {
  const _IntegerResult({this.value}) : invalid = false;
  const _IntegerResult.invalid() : value = null, invalid = true;

  final int? value;
  final bool invalid;
}

const Object _sentinel = Object();

String? _nullIfBlank(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
