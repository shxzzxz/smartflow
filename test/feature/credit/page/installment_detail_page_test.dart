import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_detail_summary_card.dart';
import 'package:smartflow/feature/credit/page/installment_detail_page.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';

void main() {
  testWidgets('pending schedule exposes skip action', (tester) async {
    final service = _FakeInstallmentAppService();
    await tester.pumpWidget(
      _app(service: service, scheduleStatus: InstallmentScheduleStatus.pending),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDetailSummaryCard), findsOneWidget);
    expect(find.text('分期合同'), findsNWidgets(2));
    expect(find.text('待还本金'), findsOneWidget);
    expect(find.text('已还利息'), findsOneWidget);
    expect(find.text('已还手续费'), findsOneWidget);
    expect(find.textContaining('本金：'), findsOneWidget);
    expect(find.textContaining('分期方式：等额本金'), findsOneWidget);
    expect(find.textContaining('计息方式：按日计息'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('installment-schedule-schedule-1')),
      const Offset(400, 0),
    );
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

    await tester.drag(
      find.byKey(const ValueKey('installment-schedule-schedule-1')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();

    expect(service.restoreCommands.single.scheduleId, 'schedule-1');
  });

  testWidgets('repayment exposes revert action from swipe', (tester) async {
    final repaymentService = _FakeRepaymentAppService();
    await tester.pumpWidget(
      _app(
        service: _FakeInstallmentAppService(),
        repaymentService: repaymentService,
        scheduleStatus: InstallmentScheduleStatus.paid,
        repayments: [_repayment('repayment-1')],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('installment-repayment-repayment-1')),
      200,
    );

    await tester.drag(
      find.byKey(const ValueKey('installment-repayment-repayment-1')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '撤销'));
    await tester.pumpAndSettle();

    expect(repaymentService.deleteCommands.single.repaymentId, 'repayment-1');
  });

  testWidgets(
    'settled contract exposes status validation with result summary',
    (tester) async {
      final service = _FakeInstallmentAppService(
        validationResult: const ContractStatusValidationResult(
          repairedScheduleCount: 2,
          contractStatusChanged: true,
          issues: [
            ContractStatusValidationIssue(
              type:
                  ContractStatusValidationIssueType
                      .skippedScheduleHasAllocation,
              message: '已跳过的还款计划存在还款分摊。',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        _app(
          service: service,
          scheduleStatus: InstallmentScheduleStatus.paid,
          contractStatus: InstallmentContractStatus.settled,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('校验状态'));
      await tester.pumpAndSettle();
      expect(find.text('校验合同状态'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '校验'));
      await tester.pumpAndSettle();

      expect(service.validationCommands.single.contractId, 'contract-1');
      expect(find.text('校验完成，已修复 2 个还款计划及合同状态，另有 1 项数据冲突未处理'), findsOneWidget);
    },
  );

  testWidgets('schedule and repayment rows use whitespace without dividers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        service: _FakeInstallmentAppService(),
        scheduleStatus: InstallmentScheduleStatus.pending,
        scheduleCount: 2,
        repayments: [_repayment('repayment-1'), _repayment('repayment-2')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsNothing);
    expect(
      tester
          .widget<SizedBox>(
            find.byKey(const ValueKey('installment-schedule-gap-0')),
          )
          .height,
      AppSpacing.space4,
    );
    expect(
      tester
          .widget<SizedBox>(
            find.byKey(const ValueKey('installment-repayment-gap-0')),
          )
          .height,
      AppSpacing.space4,
    );
  });
}

Widget _app({
  required _FakeInstallmentAppService service,
  required InstallmentScheduleStatus scheduleStatus,
  InstallmentContractStatus contractStatus = InstallmentContractStatus.active,
  _FakeRepaymentAppService? repaymentService,
  int scheduleCount = 1,
  List<ContractRepayment> repayments = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      installmentContractProvider.overrideWith(
        (ref, contractId) async => _contract(status: contractStatus),
      ),
      installmentSchedulesProvider.overrideWith(
        (ref, contractId) async => [
          for (var period = 1; period <= scheduleCount; period++)
            _schedule(scheduleStatus, period: period),
        ],
      ),
      installmentRepaymentsProvider.overrideWith(
        (ref, contractId) async => repayments,
      ),
      installmentAppServiceProvider.overrideWithValue(service),
      if (repaymentService != null)
        repaymentAppServiceProvider.overrideWithValue(repaymentService),
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

InstallmentContractReadModel _contract({
  InstallmentContractStatus status = InstallmentContractStatus.active,
}) {
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
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentScheduleReadModel _schedule(
  InstallmentScheduleStatus status, {
  int period = 1,
}) {
  return InstallmentScheduleReadModel(
    id: 'schedule-$period',
    contractId: 'contract-1',
    periodNo: period,
    expectedRepaymentDate: DateTime(2026, period + 1),
    expectedPrincipal: const Money(minorUnits: 10000),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

ContractRepayment _repayment(String id) {
  return ContractRepayment(
    id: id,
    repaymentType: RepaymentType.installment,
    occurredAt: DateTime(2026, 2, 1),
    principal: const Money(minorUnits: 10000),
    interest: Money.zero(),
    fee: Money.zero(),
  );
}

class _FakeInstallmentAppService implements InstallmentAppService {
  _FakeInstallmentAppService({
    this.validationResult = const ContractStatusValidationResult(
      repairedScheduleCount: 0,
      contractStatusChanged: false,
    ),
  });

  final ContractStatusValidationResult validationResult;
  final skipCommands = <SkipInstallmentScheduleCommand>[];
  final restoreCommands = <RestoreInstallmentScheduleCommand>[];
  final validationCommands = <ValidateContractStatusesCommand>[];

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
  Future<ContractStatusValidationResult> validateContractStatuses(
    ValidateContractStatusesCommand command,
  ) async {
    validationCommands.add(command);
    return validationResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepaymentAppService implements RepaymentAppService {
  final deleteCommands = <DeleteCreditRepaymentCommand>[];

  @override
  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command) async {
    deleteCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
