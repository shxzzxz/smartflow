import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/credit/product/installment_product_service.dart';
import 'package:smartflow/infrastructure/credit/initial_installment_products.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/feature/credit/page/installment_form_page.dart';
import 'package:smartflow/feature/credit/page/loan_configuration_page.dart';
import 'package:smartflow/feature/credit/view_model/installment_form_view_model.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/credit/view_model/loan_configuration_view_model.dart';
import 'package:smartflow/feature/credit/widget/installment_stage_card.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  testWidgets(
    'cash installment can choose and freely edit a product template',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final products = _Products();
      when(() => products.list()).thenAnswer(
        (_) async => [
          for (final product in initialInstallmentProducts)
            InstallmentProductReadModel(
              id: product.id,
              name: product.name,
              archived: false,
              stages: product.stages,
              dayCount: DayCountConvention.thirty360,
              rounding: RoundingMode.halfUp,
            ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          installmentProductServiceProvider.overrideWithValue(products),
          accountsForSelectionPurposeProvider.overrideWith(
            (ref, purpose) => Stream.value(
              purpose == AccountSelectionPurpose.repaymentTarget
                  ? [
                      Account(
                        id: 'credit',
                        name: '信用卡',
                        type: AccountType.liability,
                        profileKey: AccountProfileKind.credit.key,
                        balance: Money.zero(),
                      ),
                    ]
                  : <Account>[],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: InstallmentFormPage(liabilityAccountId: 'credit'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '1000');
      await tester.tap(find.text('分期配置'));
      await tester.pumpAndSettle();
      expect(find.text('自定义本笔贷款'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(
        tester.getCenter(find.text('产品模板')).dy,
        closeTo(tester.getCenter(find.byType(FilterChip)).dy, 1),
      );
      await tester.tap(find.text('产品模板'));
      await tester.pumpAndSettle();
      expect(find.text('国家助学贷款'), findsOneWidget);
      await tester.tap(find.text('等额本金'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilterChip));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).selected,
        isTrue,
      );
      await tester.tap(find.byType(FilterChip));
      await tester.pumpAndSettle();
      final count = find.descendant(
        of: find.byKey(
          const ValueKey('builtin-loan-equal-principal-1:periods'),
        ),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(count);
      await tester.enterText(count, '6');
      await tester.ensureVisible(find.text('使用此配置'));
      await tester.tap(find.text('使用此配置'));
      await tester.pumpAndSettle();
      expect(find.byType(LoanConfigurationPage), findsNothing);
      expect(find.text('等额本金'), findsOneWidget);
      final loaded =
          container
                  .read(
                    installmentFormViewModelProvider(
                      const InstallmentFormArgs(liabilityAccountId: 'credit'),
                    ),
                  )
                  .requireValue
              as InstallmentFormLoaded;
      expect(loaded.termsDraft.stages.single.text(StageInput.periods), '6');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'configuration round trip preserves basic info and cancellation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          accountsForSelectionPurposeProvider.overrideWith(
            (ref, purpose) => Stream.value(switch (purpose) {
              AccountSelectionPurpose.repaymentTarget => [_loanAccount()],
              AccountSelectionPurpose.fund => [_fundAccount()],
              _ => const <Account>[],
            }),
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

      expect(find.byType(AppFormSection), findsWidgets);
      expect(find.text('分期配置'), findsOneWidget);
      expect(find.text('放款信息'), findsNothing);
      expect(find.text('分期设置'), findsNothing);
      expect(find.text('计算约定'), findsNothing);
      expect(find.byType(InstallmentStageCard), findsNothing);

      expect(tester.getTopLeft(find.byType(AppFormSection).first).dx, 16);

      final provider = installmentFormViewModelProvider(
        const InstallmentFormArgs(liabilityAccountId: 'loan'),
      );
      container.read(provider.notifier).setBorrowingDate(DateTime(2026, 1, 1));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '12000');
      await tester.enterText(find.byType(TextField).last, '保留备注');
      await tester.tap(find.text('分期配置'));
      await tester.pumpAndSettle();
      expect(find.byType(LoanConfigurationPage), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '12000.00',
      );
      final page = tester.widget<LoanConfigurationPage>(
        find.byType(LoanConfigurationPage),
      );
      expect(page.installment!.borrowingDate, DateTime(2026, 1, 1));
      final stageId = page.installment!.terms.stages.single.id;
      await tester.enterText(find.byType(TextField).first, '18000');
      final periods = find.descendant(
        of: find.byKey(ValueKey('$stageId:periods')),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(periods);
      await tester.enterText(periods, '6');
      await tester.ensureVisible(find.text('使用此配置'));
      await tester.tap(find.text('使用此配置'));
      await tester.pumpAndSettle();
      expect(find.byType(LoanConfigurationPage), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '18000.00',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '保留备注',
      );
      expect(
        (container.read(provider).requireValue as InstallmentFormLoaded)
            .termsDraft
            .stages
            .single
            .text(StageInput.periods),
        '6',
      );

      await tester.tap(find.text('分期配置'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '24000');
      final currentPage = tester.widget<LoanConfigurationPage>(
        find.byType(LoanConfigurationPage),
      );
      final configProvider = loanConfigurationViewModelProvider(
        installment: currentPage.installment,
      );
      container
          .read(configProvider.notifier)
          .setBorrowingDate(DateTime(2026, 1, 2));
      Navigator.of(tester.element(find.byType(LoanConfigurationPage))).pop();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '18000.00',
      );
      expect(
        (container.read(provider).requireValue as InstallmentFormLoaded)
            .borrowingDate,
        DateTime(2026, 1, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'can choose to create contract without disbursement transaction',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          accountsForSelectionPurposeProvider.overrideWith(
            (ref, purpose) => Stream.value(switch (purpose) {
              AccountSelectionPurpose.repaymentTarget => [_loanAccount()],
              AccountSelectionPurpose.fund => [_fundAccount()],
              _ => const <Account>[],
            }),
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

      expect(find.text('创建交易'), findsOneWidget);
      expect(find.text('关闭则仅创建合同和计划'), findsOneWidget);
      expect(find.text('到账账户'), findsOneWidget);
      expect(find.text('末期还款日'), findsNothing);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.text('到账账户'), findsNothing);
    },
  );
}

class _Products extends Mock implements InstallmentProductService {}

Account _loanAccount() {
  return Account(
    id: 'loan',
    name: '贷款账户',
    type: AccountType.liability,
    profileKey: AccountProfileKind.loan.key,
    balance: Money.zero(),
  );
}

Account _fundAccount() {
  return Account(
    id: 'cash',
    name: '现金',
    type: AccountType.asset,
    balance: Money.zero(),
  );
}
