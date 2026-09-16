import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/product/installment_product_app_service.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/design_system/widget/app_surface.dart';
import 'package:smartflow/domain/credit/valobj/day_count_convention.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/feature/credit/page/installment_form_page.dart';
import 'package:smartflow/feature/credit/page/installment_products_page.dart';
import 'package:smartflow/feature/credit/page/installment_product_edit_page.dart';
import 'package:smartflow/feature/credit/view_model/loan_configuration_view_model.dart';
import 'package:smartflow/feature/credit/page/loan_configuration_page.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

class _Products extends Mock implements InstallmentProductAppService {}

void main() {
  setUpAll(() {
    registerFallbackValue(DayCountConvention.thirty360);
    registerFallbackValue(RoundingMode.halfUp);
  });
  late _Products service;
  setUp(() {
    service = _Products();
    when(() => service.list()).thenAnswer((_) async => [_product]);
  });

  testWidgets('product list keeps its summary inside a card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          installmentProductAppServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: InstallmentProductsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppSurface), findsOneWidget);
    expect(find.text('借呗先息后本'), findsOneWidget);
    expect(find.text('先息后本'), findsOneWidget);
    expect(find.text('1 个阶段'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product editor omits all per-loan fields on a phone screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          installmentProductAppServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: InstallmentProductEditPage(productId: 'p'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('产品名称'), findsOneWidget);
    expect(find.text('间隔月数'), findsOneWidget);
    for (final label in [
      '本金',
      '期数',
      '利率（%）',
      '期末本金',
      '手续费',
      '指定固定额',
      '首期还款日',
      '末期还款日',
      '免还结束日',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'template rules are editable immediately and advanced toggle preserves edits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          installmentProductAppServiceProvider.overrideWithValue(service),
          accountsForSelectionPurposeProvider.overrideWith(
            (ref, purpose) => Stream.value(
              purpose == AccountSelectionPurpose.repaymentTarget
                  ? [
                      Account(
                        id: 'loan',
                        name: '贷款',
                        type: AccountType.liability,
                        profileKey: 'credit.loan',
                        balance: Money.zero(),
                      ),
                    ]
                  : [
                      Account(
                        id: 'cash',
                        name: '现金',
                        type: AccountType.asset,
                        balance: Money.zero(),
                      ),
                    ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: InstallmentFormPage(liabilityAccountId: 'loan'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('分期配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('产品模板'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('借呗先息后本'));
      await tester.pumpAndSettle();
      final selector = find.byType(
        AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>,
      );
      expect(
        tester
            .widget<AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>>(
              selector,
            )
            .enabled,
        isTrue,
      );
      expect(find.text('期数'), findsOneWidget);
      expect(find.text('自定义本笔贷款'), findsNothing);
      final page = tester.widget<LoanConfigurationPage>(
        find.byType(LoanConfigurationPage),
      );
      final provider = loanConfigurationViewModelProvider(
        installment: page.installment,
      );
      final vm = container.read(provider.notifier);
      vm.setTerms(container.read(provider).terms.add(true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('高级配置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('基础配置'));
      await tester.pumpAndSettle();
      final after = container.read(provider);
      expect(after.advanced, isFalse);
      expect(after.terms.stages, hasLength(2));
      expect(after.productId, 'p');
      verifyNever(
        () => service.save(
          id: any(named: 'id'),
          name: any(named: 'name'),
          stages: any(named: 'stages'),
          dayCount: any(named: 'dayCount'),
          rounding: any(named: 'rounding'),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

const _product = InstallmentProductReadModel(
  id: 'p',
  name: '借呗先息后本',
  archived: false,
  dayCount: DayCountConvention.thirty360,
  rounding: RoundingMode.halfUp,
  stages: [
    InstallmentStageRule.repayment(
      id: 's',
      method: InstallmentRepaymentMethod.interestFirst,
      intervalMonths: 1,
      ratePeriod: InterestRatePeriod.annual,
      accrual: InterestAccrualMethod.monthly,
    ),
  ],
);
