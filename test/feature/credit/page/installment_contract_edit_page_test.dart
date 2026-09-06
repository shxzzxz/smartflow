import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/feature/credit/page/installment_contract_edit_page.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';

void main() {
  testWidgets('saving commits the active schedule amount editor first', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FailingInstallmentAppService();
    final container = ProviderContainer(
      overrides: [
        installmentContractProvider.overrideWith(
          (ref, contractId) async => _contract(),
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
  });
}

const _metrics = ContractMetrics(
  monthlyIrr: null,
  nominalApr: null,
  effectiveApr: null,
  totalRepayment: Money(minorUnits: 10050),
  totalInterest: Money(minorUnits: 50),
  totalFee: Money(minorUnits: 0),
  converged: false,
  unavailableReason: ContractMetricsUnavailableReason.noRateSolution,
);

InstallmentContractReadModel _contract() {
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
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'contract-1:stage:1',
      totalPeriods: 1,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, 2, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      ratePeriod: InterestRatePeriod.monthly,
      ratePpm: 10000,
      accrual: InterestAccrualMethod.daily,
      feeMinor: 0,
    ),
  );
}

InstallmentScheduleReadModel _schedule() {
  return InstallmentScheduleReadModel(
    id: 'schedule-1',
    contractId: 'contract-1',
    periodNo: 1,
    expectedRepaymentDate: DateTime(2026, 2, 1),
    expectedPrincipal: const Money(minorUnits: 5000),
    expectedInterest: const Money(minorUnits: 50),
    expectedFee: Money.zero(),
    status: InstallmentScheduleStatus.pending,
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
