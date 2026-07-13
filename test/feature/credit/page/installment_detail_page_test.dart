import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/page/installment_detail_page.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';

void main() {
  testWidgets('pending schedule exposes skip action', (tester) async {
    final service = _FakeInstallmentAppService();
    await tester.pumpWidget(
      _app(service: service, scheduleStatus: InstallmentScheduleStatus.pending),
    );
    await tester.pumpAndSettle();

    expect(find.text('跳过'), findsOneWidget);
    await tester.tap(find.text('跳过'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '跳过'));
    await tester.pumpAndSettle();

    expect(service.skipCommands.single.scheduleId, 'schedule-1');
  });

  testWidgets('skipped schedule exposes restore action', (tester) async {
    final service = _FakeInstallmentAppService();
    await tester.pumpWidget(
      _app(service: service, scheduleStatus: InstallmentScheduleStatus.skipped),
    );
    await tester.pumpAndSettle();

    expect(find.text('撤销跳过'), findsOneWidget);
    await tester.tap(find.text('撤销跳过'));
    await tester.pumpAndSettle();

    expect(service.restoreCommands.single.scheduleId, 'schedule-1');
  });
}

Widget _app({
  required _FakeInstallmentAppService service,
  required InstallmentScheduleStatus scheduleStatus,
}) {
  final container = ProviderContainer(
    overrides: [
      installmentContractProvider.overrideWith(
        (ref, contractId) async => _contract(),
      ),
      installmentSchedulesProvider.overrideWith(
        (ref, contractId) async => [_schedule(scheduleStatus)],
      ),
      installmentRepaymentsProvider.overrideWith(
        (ref, contractId) async => const [],
      ),
      installmentAppServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: InstallmentDetailPage(contractId: 'contract-1'),
    ),
  );
}

InstallmentContractReadModel _contract() {
  return InstallmentContractReadModel(
    id: 'contract-1',
    liabilityAccountId: 'loan',
    sourceType: InstallmentSourceType.disbursement,
    disbursementAccountId: 'cash',
    principal: const Money(minorUnits: 10000),
    totalPeriods: 1,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, 2, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: InterestAccrualMethod.daily,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentScheduleReadModel _schedule(InstallmentScheduleStatus status) {
  return InstallmentScheduleReadModel(
    id: 'schedule-1',
    contractId: 'contract-1',
    periodNo: 1,
    expectedRepaymentDate: DateTime(2026, 2, 1),
    expectedPrincipal: const Money(minorUnits: 10000),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

class _FakeInstallmentAppService implements InstallmentAppService {
  final skipCommands = <SkipInstallmentScheduleCommand>[];
  final restoreCommands = <RestoreInstallmentScheduleCommand>[];

  @override
  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) async {
    skipCommands.add(command);
  }

  @override
  Future<void> restoreSchedule(
    RestoreInstallmentScheduleCommand command,
  ) async {
    restoreCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
