import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/domain/credit/valobj/floating_rate.dart';
import 'package:smartflow/design_system/widget/app_plain_form_field.dart';
import 'package:smartflow/feature/credit/page/installment_contract_edit_page.dart';
import 'package:smartflow/feature/credit/page/loan_configuration_page.dart';
import 'package:smartflow/feature/credit/widget/installment_terms_editor.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';

void main() {
  testWidgets(
    'configuration returns without recalculating and save commits the active cell',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = _FailingInstallmentAppService();
      final container = ProviderContainer(
        overrides: [
          installmentContractProvider.overrideWith(
            (ref, contractId) async => _contract(floating: true),
          ),
          installmentSchedulesProvider.overrideWith(
            (ref, contractId) async => [_schedule()],
          ),
          installmentMetricsProvider.overrideWith(
            (ref, contractId) async => _metrics,
          ),
          installmentAppServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: InstallmentContractEditPage(contractId: 'contract-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InstallmentTermsEditor), findsNothing);
      expect(
        tester.getTopLeft(find.text('20260101').first).dy,
        lessThan(tester.getTopLeft(find.text('合同配置')).dy),
      );
      expect(
        tester.getTopLeft(find.text('合同配置')).dy,
        lessThan(tester.getTopLeft(find.text('还款计划')).dy),
      );
      await tester.enterText(find.byType(TextField).first, '家庭贷款');
      await tester.tap(find.text('分期配置'));
      await tester.pumpAndSettle();
      expect(find.byType(LoanConfigurationPage), findsOneWidget);
      expect(find.text('产品模板'), findsNothing);
      expect(find.text('高级配置'), findsOneWidget);
      final rateType = tester
          .widget<AppPlainSelectMenuFormRow<InterestRateType>>(
            find.byType(AppPlainSelectMenuFormRow<InterestRateType>),
          );
      expect(rateType.value, InterestRateType.lprFiveYearPlus);
      expect(rateType.enabled, isFalse);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('contract-1:stage:1:rate')),
          matching: find.byType(TextFormField),
        ),
        '2',
      );
      await tester.ensureVisible(find.text('使用此配置'));
      await tester.tap(find.text('使用此配置'));
      await tester.pumpAndSettle();
      expect(find.byType(LoanConfigurationPage), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('i-1')),
          matching: find.text('0.50'),
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('p-1')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('p-1')));
      await tester.pump();
      final editor = find.descendant(
        of: find.byKey(const ValueKey('p-1')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(editor, '60');

      await tester.ensureVisible(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();

      final patch = service.updateCommands.single.schedulePatches.single;
      expect(patch.periodNo, 1);
      expect(patch.expectedPrincipal, const Money(minorUnits: 6000));
      expect(service.updateCommands.single.name, '家庭贷款');
      expect(service.updateCommands.single.regeneratePlan, isFalse);
      expect(
        service
            .updateCommands
            .single
            .stageTerms!
            .repayments
            .single
            .floatingRate,
        isNull,
      );
      expect(
        service.updateCommands.single.stageTerms!.repayments.single.rate!.ppm,
        20000,
      );
    },
  );

  testWidgets(
    'all schedule states allow amount editing without a status column',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          installmentContractProvider.overrideWith(
            (ref, id) async => _contract(),
          ),
          installmentSchedulesProvider.overrideWith(
            (ref, id) async => [
              _schedule(),
              _schedule(
                periodNo: 2,
                status: InstallmentScheduleStatus.partiallyPaid,
              ),
              _schedule(periodNo: 3, status: InstallmentScheduleStatus.paid),
              _schedule(periodNo: 4, status: InstallmentScheduleStatus.skipped),
            ],
          ),
          installmentMetricsProvider.overrideWith((ref, id) async => _metrics),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: InstallmentContractEditPage(contractId: 'contract-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('状态'), findsNothing);
      for (final period in [2, 3, 4]) {
        final cell = find.byKey(ValueKey('p-$period'));
        await tester.ensureVisible(cell);
        await tester.tap(cell);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: cell, matching: find.byType(TextFormField)),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('p-1')));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

const _metrics = ContractMetrics(
  monthlyIrr: null,
  nominalApr: null,
  xirr: null,
  totalRepayment: Money(minorUnits: 10050),
  totalInterest: Money(minorUnits: 50),
  totalFee: Money(minorUnits: 0),
  converged: false,
  unavailableReason: ContractMetricsUnavailableReason.noRateSolution,
);

InstallmentContractReadModel _contract({bool floating = false}) {
  return InstallmentContractReadModel(
    id: 'contract-1',
    liabilityAccountId: 'loan',
    sourceType: InstallmentSourceType.disbursement,
    disbursementAccountId: 'bank',
    disbursementTransactionId: 'tx-disbursement',
    principal: const Money(minorUnits: 5000),
    borrowingDate: DateTime(2026, 1, 1),
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
    repricingConfigurations: [
      if (floating)
        InstallmentRepricingConfigurationReadModel(
          id: 'configuration',
          stageId: 'contract-1:stage:1',
          effectiveFrom: DateTime.utc(2026, 1, 1),
          rule: FloatingRateRule(
            referenceRateType: InterestRateType.lprFiveYearPlus,
            spreadBp: -30,
            firstResetDate: DateTime.utc(2026, 1, 20),
            firstEffectiveDate: DateTime.utc(2026, 1, 25),
          ),
        ),
    ],
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'contract-1:stage:1',
      totalPeriods: 1,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, 2, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      ratePeriod: floating
          ? InterestRatePeriod.annual
          : InterestRatePeriod.monthly,
      ratePpm: 10000,
      accrual: InterestAccrualMethod.daily,
      feeMinor: 0,
    ),
  );
}

InstallmentScheduleReadModel _schedule({
  int periodNo = 1,
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentScheduleReadModel(
    id: 'schedule-$periodNo',
    contractId: 'contract-1',
    periodNo: periodNo,
    expectedRepaymentDate: DateTime(2026, periodNo + 1, 1),
    expectedPrincipal: const Money(minorUnits: 5000),
    expectedInterest: const Money(minorUnits: 50),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

class _FailingInstallmentAppService implements InstallmentAppService {
  final updateCommands = <UpdateContractCommand>[];

  @override
  Future<void> updateContract(UpdateContractCommand command) async {
    updateCommands.add(command);
    throw Exception('stop after capturing the update');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
