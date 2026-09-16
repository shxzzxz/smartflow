import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
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
  });

  final DateTime borrowingDate;
  final InstallmentTermsDraft terms;
  final bool selection, advanced;
  final String? productName;
  final String? productId;
  final InstallmentConfigurationDraft? installment;

  bool get canSelectProduct => installment?.basicInfoReadOnly != true;
  bool get canUseCalculatorActions => !selection && installment == null;

  String get submitLabel =>
      selection || installment != null ? '使用此配置' : '生成还款计划';

  LoanConfigurationState copyWith({
    DateTime? borrowingDate,
    InstallmentTermsDraft? terms,
    bool? advanced,
    String? productName,
    String? productId,
  }) => LoanConfigurationState(
    borrowingDate: borrowingDate ?? this.borrowingDate,
    terms: terms ?? this.terms,
    selection: selection,
    advanced: advanced ?? this.advanced,
    productName: productName ?? this.productName,
    productId: productId ?? this.productId,
    installment: installment,
  );
}

@riverpod
class LoanConfigurationViewModel extends _$LoanConfigurationViewModel {
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

  void setTerms(InstallmentTermsDraft value) =>
      state = state.copyWith(terms: value);

  void setAdvanced(bool value) => state = state.copyWith(advanced: value);
  void setBorrowingDate(DateTime value) {
    state = state.copyWith(
      borrowingDate: DateTime(value.year, value.month, value.day),
    );
  }

  Future<UiActionOutcome<List<InstallmentProductReadModel>>> loadProducts() =>
      guardUiAction(_logger, 'Load loan products', () async {
        final products = await ref
            .read(installmentProductAppServiceProvider)
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
    setTerms(terms);
  }

  Future<UiActionOutcome<InstallmentConfigurationDraft>> submitInstallment(
    String principalText,
  ) => guardUiAction(_logger, 'Confirm installment configuration', () async {
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
