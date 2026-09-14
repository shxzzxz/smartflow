import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/valobj/reference_rate.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import 'installment_terms_draft.dart';

part 'loan_configuration_view_model.g.dart';

final _logger = Logger('feature.credit.loan_configuration');

/// 合同表单的配置草稿；返回配置不计算或替换合同还款计划。
class InstallmentConfigurationDraft {
  const InstallmentConfigurationDraft({
    required this.borrowingDate,
    required this.terms,
    this.principal,
    this.productId,
    this.productName,
    this.basicInfoReadOnly = false,
  });

  final Money? principal;
  final DateTime borrowingDate;
  final InstallmentTermsDraft terms;
  final String? productId, productName;
  final bool basicInfoReadOnly;
}

/// 已完成校验的本次贷款配置；编辑时复制草稿，完成后才替换调用方方案。
class LoanConfiguration {
  const LoanConfiguration({
    required this.principal,
    required this.borrowingDate,
    required this.terms,
    required this.calculation,
    this.productName,
    this.advanced = false,
  });

  final Money principal;
  final DateTime borrowingDate;
  final InstallmentTermsDraft terms;
  final LoanCalculation calculation;
  final String? productName;
  final bool advanced;
}

class LoanConfigurationState {
  const LoanConfigurationState({
    required this.borrowingDate,
    required this.terms,
    required this.selection,
    this.advanced = false,
    this.productName,
    this.productId,
    this.installment,
    this.rateMessages = const {},
    this.retryableRateStageIds = const {},
    this.resolvingRates = false,
  });

  final DateTime borrowingDate;
  final InstallmentTermsDraft terms;
  final bool selection, advanced;
  final String? productName;
  final String? productId;
  final InstallmentConfigurationDraft? installment;
  final Map<String, String> rateMessages;
  final Set<String> retryableRateStageIds;
  final bool resolvingRates;

  bool get canSelectProduct => installment?.basicInfoReadOnly != true;

  String get submitLabel =>
      selection || installment != null ? '使用此配置' : '生成还款计划';

  LoanConfigurationState copyWith({
    DateTime? borrowingDate,
    InstallmentTermsDraft? terms,
    bool? advanced,
    String? productName,
    String? productId,
    Map<String, String>? rateMessages,
    Set<String>? retryableRateStageIds,
    bool? resolvingRates,
  }) => LoanConfigurationState(
    borrowingDate: borrowingDate ?? this.borrowingDate,
    terms: terms ?? this.terms,
    selection: selection,
    advanced: advanced ?? this.advanced,
    productName: productName ?? this.productName,
    productId: productId ?? this.productId,
    installment: installment,
    rateMessages: rateMessages ?? this.rateMessages,
    retryableRateStageIds: retryableRateStageIds ?? this.retryableRateStageIds,
    resolvingRates: resolvingRates ?? this.resolvingRates,
  );
}

@riverpod
class LoanConfigurationViewModel extends _$LoanConfigurationViewModel {
  final _rates = <_ReferenceRateKey, ReferenceRateResolution>{};
  final _failedRates = <_ReferenceRateKey>{};
  final _pendingRates = <_ReferenceRateKey, Future<void>>{};

  @override
  LoanConfigurationState build({
    LoanConfiguration? initial,
    bool selection = false,
    InstallmentConfigurationDraft? installment,
  }) {
    final now = DateTime.now();
    final date =
        installment?.borrowingDate ??
        initial?.borrowingDate ??
        DateTime(now.year, now.month, now.day);
    unawaited(
      Future<void>.microtask(() async {
        if (ref.mounted) await refreshReferenceRates();
      }),
    );
    return LoanConfigurationState(
      borrowingDate: date,
      terms:
          installment?.terms ??
          initial?.terms ??
          InstallmentTermsDraft.loan(date),
      selection: selection,
      advanced: initial?.advanced ?? false,
      productName: installment?.productName ?? initial?.productName,
      productId: installment?.productId,
      installment: installment,
    );
  }

  void setTerms(InstallmentTermsDraft value) {
    final previous = {for (final stage in state.terms.stages) stage.id: stage};
    state = state.copyWith(
      terms: value.copyWith(
        stages: [
          for (final stage in value.stages)
            if (stage.floating &&
                previous[stage.id]?.rateType != stage.rateType &&
                stage.text(StageInput.spreadBp).trim().isEmpty)
              stage.setInput(StageInput.spreadBp, '0')
            else
              stage,
        ],
      ),
    );
    _applyReferenceRates();
    unawaited(refreshReferenceRates());
  }

  void setAdvanced(bool value) => state = state.copyWith(advanced: value);
  void setBorrowingDate(DateTime value) {
    state = state.copyWith(
      borrowingDate: DateTime(value.year, value.month, value.day),
    );
    _applyReferenceRates();
    unawaited(refreshReferenceRates());
  }

  _ReferenceRateKey? _rateKey(int index) {
    final stage = state.terms.stages[index];
    if (stage.deferment || !stage.floating) return null;
    final start = state.terms.stageStartDate(index, state.borrowingDate);
    if (start == null) return null;
    final date = referenceDate(start);
    final today = referenceDate(DateTime.now());
    return (stage.rateType, date.isAfter(today) ? today : date);
  }

  Future<void> refreshReferenceRates({bool retry = false}) async {
    if (retry) {
      _failedRates.clear();
      _rates.removeWhere((_, value) => value.rate == null);
    }
    final requests = <Future<void>>[];
    for (var i = 0; i < state.terms.stages.length; i++) {
      final key = _rateKey(i);
      if (key == null ||
          _rates.containsKey(key) ||
          _failedRates.contains(key)) {
        continue;
      }
      requests.add(_pendingRates.putIfAbsent(key, () => _resolveRate(key)));
    }
    _applyReferenceRates();
    await Future.wait(requests);
  }

  Future<void> _resolveRate(_ReferenceRateKey key) async {
    final outcome = await guardUiAction(
      _logger,
      'Resolve initial installment rate',
      () => ref.read(referenceRateServiceProvider).resolveOne(key.$1, key.$2),
    );
    if (!ref.mounted) return;
    switch (outcome) {
      case UiActionSuccess<ReferenceRateResolution>(:final value):
        _rates[key] = value;
      case UiActionFailure<ReferenceRateResolution>():
        _failedRates.add(key);
    }
    _pendingRates.remove(key);
    _applyReferenceRates();
  }

  void _applyReferenceRates() {
    var terms = state.terms;
    final messages = <String, String>{};
    final retryable = <String>{};
    var loading = false;
    for (var i = 0; i < terms.stages.length; i++) {
      final stage = terms.stages[i];
      if (stage.deferment || !stage.floating) continue;
      final key = _rateKey(i);
      final rate = _rates[key]?.rate;
      final spread = int.tryParse(stage.text(StageInput.spreadBp).trim());
      String text = '';
      if (key == null) {
        messages[stage.id] = '请先完善上一阶段的时间配置';
      } else if (_failedRates.contains(key) ||
          (_rates.containsKey(key) && rate == null)) {
        messages[stage.id] = '对应日期的参考利率暂不可用';
        retryable.add(stage.id);
      } else if (rate == null) {
        messages[stage.id] = '正在读取历史报价…';
        loading = true;
      } else if (spread == null) {
        messages[stage.id] = '请填写整数基点';
      } else {
        final ppm = rate.ratePpm + spread * 100;
        if (ppm < 0) {
          messages[stage.id] = '执行利率不得为负';
        } else {
          text = (Decimal.fromInt(ppm) * Decimal.parse('0.0001')).toString();
          final start = terms.stageStartDate(i, state.borrowingDate)!;
          if (referenceDate(start).isAfter(key.$2)) {
            messages[stage.id] = '未来阶段按当前已知报价试算';
          }
        }
      }
      if (text != stage.text(StageInput.rate)) {
        terms = terms.replace(stage.setInput(StageInput.rate, text));
      }
    }
    state = state.copyWith(
      terms: terms,
      rateMessages: Map.unmodifiable(messages),
      retryableRateStageIds: Set.unmodifiable(retryable),
      resolvingRates: loading,
    );
  }

  void _requireCalculatedRates() {
    for (final stage in state.terms.stages) {
      if (!stage.deferment &&
          stage.floating &&
          stage.text(StageInput.rate).isEmpty) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: state.rateMessages[stage.id] ?? '参考利率尚未确定',
        );
      }
    }
  }

  Future<UiActionOutcome<List<InstallmentProductReadModel>>> loadProducts() =>
      guardUiAction(_logger, 'Load loan products', () async {
        final products = await ref
            .read(installmentProductServiceProvider)
            .list();
        return products
            .where(
              (p) =>
                  !p.archived &&
                  (state.installment != null ||
                      p.stages.every(
                        (s) => s.method != InstallmentRepaymentMethod.custom,
                      )),
            )
            .toList();
      });

  void selectProduct(InstallmentProductReadModel product) {
    if (!state.canSelectProduct) return;
    var terms = InstallmentTermsDraft.product(
      product.stages,
      product.dayCount,
      product.rounding,
    );
    if (state.installment != null) {
      final index = terms.stages.indexWhere((stage) => !stage.deferment);
      if (index >= 0) {
        final stage = terms.stages[index];
        terms = terms.replace(
          stage.copyWith(
            firstDate: IntervalRepaymentDates.addMonthsClamped(
              state.borrowingDate,
              1,
            ),
          ),
        );
      }
    }
    state = state.copyWith(productName: product.name, productId: product.id);
    setTerms(
      terms.copyWith(
        stages: [
          for (final stage in terms.stages)
            stage.floating ? stage.setInput(StageInput.spreadBp, '0') : stage,
        ],
      ),
    );
  }

  Future<UiActionOutcome<InstallmentConfigurationDraft>> submitInstallment(
    String principalText,
  ) => guardUiAction(_logger, 'Confirm installment configuration', () async {
    await refreshReferenceRates();
    _requireCalculatedRates();
    final current = state;
    final initial = current.installment!;
    final principal = Money.tryParse(principalText.trim());
    if (principal == null || principal.minorUnits <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '请输入有效本金',
      );
    }
    current.terms.contractTerms();
    return InstallmentConfigurationDraft(
      principal: principal,
      borrowingDate: current.borrowingDate,
      terms: current.terms,
      productId: current.productId,
      productName: current.productName,
      basicInfoReadOnly: initial.basicInfoReadOnly,
    );
  });

  Future<UiActionOutcome<LoanConfiguration>> submit(String principalText) =>
      guardUiAction(_logger, 'Calculate loan configuration', () async {
        final principal = Money.tryParse(principalText.trim());
        if (principal == null || principal.minorUnits <= 0) {
          throw BusinessException(
            CreditErrorCode.contractInvalidCommand,
            message: '请输入有效本金',
          );
        }
        await refreshReferenceRates();
        _requireCalculatedRates();
        final current = state;
        final terms = current.terms.contractTerms().planTerms(
          principal,
          current.borrowingDate,
        );
        final calculation = ref
            .read(loanCalculatorQueryProvider)
            .calculate(terms);
        return LoanConfiguration(
          principal: principal,
          borrowingDate: current.borrowingDate,
          terms: current.terms,
          calculation: calculation,
          productName: current.productName,
          advanced: current.advanced,
        );
      });
}

typedef _ReferenceRateKey = (InterestRateType, DateTime);
