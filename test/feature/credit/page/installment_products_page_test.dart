import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/product/installment_product_service.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/rounding_mode.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/domain/credit/valobj/day_count_convention.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/feature/credit/page/installment_form_page.dart';
import 'package:smartflow/feature/credit/page/installment_product_edit_page.dart';
import 'package:smartflow/feature/credit/view_model/installment_form_view_model.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

class _Products extends Mock implements InstallmentProductService {}

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

  testWidgets('product editor omits all per-loan fields on a phone screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          installmentProductServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(
          home: InstallmentProductEditPage(productId: 'p'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('产品名称'), findsOneWidget);
    expect(find.text('各期间隔'), findsOneWidget);
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
    'selection loads rules; switch unlocks and closing preserves edits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          installmentProductServiceProvider.overrideWithValue(service),
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
      await tester.tap(find.text('选择产品'));
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
        isFalse,
      );
      expect(find.text('期数'), findsOneWidget);
      final customSwitch = find.byType(Switch).last;
      await tester.tap(customSwitch);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppPlainSelectMenuFormRow<InstallmentRepaymentMethod>>(
              selector,
            )
            .enabled,
        isTrue,
      );
      final vm = container.read(
        installmentFormViewModelProvider(
          const InstallmentFormArgs(liabilityAccountId: 'loan'),
        ).notifier,
      );
      final before =
          container
                  .read(
                    installmentFormViewModelProvider(
                      const InstallmentFormArgs(liabilityAccountId: 'loan'),
                    ),
                  )
                  .requireValue
              as InstallmentFormLoaded;
      vm.setTermsDraft(before.termsDraft.add(true));
      await tester.pumpAndSettle();
      await tester.tap(customSwitch);
      await tester.pumpAndSettle();
      final after =
          container
                  .read(
                    installmentFormViewModelProvider(
                      const InstallmentFormArgs(liabilityAccountId: 'loan'),
                    ),
                  )
                  .requireValue
              as InstallmentFormLoaded;
      expect(after.customRules, isFalse);
      expect(after.termsDraft.stages, hasLength(2));
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
