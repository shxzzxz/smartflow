import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_status_banner.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/token/spacing.dart';
import 'package:smartflow/design_system/widget/app_detail_summary_card.dart';
import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:smartflow/feature/credit/page/installment_detail_page.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';

void main() {
  testWidgets(
    'contract operations live in the more menu and deletion remains confirmed',
    (tester) async {
      final service = _FakeInstallmentContractAppService();
      await tester.pumpWidget(
        _app(
          service: service,
          scheduleStatus: InstallmentScheduleStatus.pending,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('利率与利息调整'), findsNothing);
      expect(find.byTooltip('删除合同'), findsNothing);
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('重定价'), findsOneWidget);
      expect(find.text('利息调整'), findsOneWidget);
      await tester.tap(find.text('删除合同'));
      await tester.pumpAndSettle();
      expect(find.text('删除分期合同'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets(
    'repricing banner confirms loaded records and prevents duplicate taps',
    (tester) async {
      final service = _MockRepricingService();
      final completion = Completer<void>();
      var ids = ['repricing-1', 'repricing-2'];
      when(() => service.confirm('contract-1', any())).thenAnswer((_) async {
        await completion.future;
        ids = [];
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          service: _FakeInstallmentContractAppService(),
          scheduleStatus: InstallmentScheduleStatus.pending,
          repricingService: service,
          unconfirmedRepricingIds: () => ids,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('分期合同已执行重定价，请查看后确认'), findsOneWidget);
      expect(find.byTooltip('重定价预览'), findsNothing);
      expect(find.textContaining('浮动利率计划：'), findsNothing);
      expect(
        tester.getTopLeft(find.byType(AppStatusBanner)).dy,
        greaterThan(tester.getTopLeft(find.text('校验状态')).dy),
      );
      expect(
        tester.getBottomLeft(find.byType(AppStatusBanner)).dy,
        lessThan(tester.getTopLeft(find.text('还款计划')).dy),
      );
      await tester.tap(find.widgetWithText(TextButton, '确认'));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '确认'))
            .onPressed,
        isNull,
      );
      completion.complete();
      await tester.pumpAndSettle();
      verify(
        () => service.confirm('contract-1', {'repricing-1', 'repricing-2'}),
      ).called(1);
      expect(find.byType(AppStatusBanner), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed repricing confirmation keeps the banner and supports retry',
    (tester) async {
      final service = _MockRepricingService();
      var ids = ['repricing-1'];
      when(() => service.confirm('contract-1', any())).thenThrow(
        BusinessException(
          CreditErrorCode.contractPersistenceConflict,
          message: '确认失败，请重试',
        ),
      );
      await tester.pumpWidget(
        _app(
          service: _FakeInstallmentContractAppService(),
          scheduleStatus: InstallmentScheduleStatus.pending,
          repricingService: service,
          unconfirmedRepricingIds: () => ids,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '确认'));
      await tester.pumpAndSettle();
      expect(find.text('确认失败，请重试'), findsOneWidget);
      expect(find.byType(AppStatusBanner), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '确认'))
            .onPressed,
        isNotNull,
      );
      when(() => service.confirm('contract-1', any())).thenAnswer((_) async {
        ids = [];
      });
      await tester.tap(find.widgetWithText(TextButton, '确认'));
      await tester.pumpAndSettle();
      expect(find.byType(AppStatusBanner), findsNothing);
    },
  );

  testWidgets('pending schedule exposes skip action', (tester) async {
    final service = _FakeInstallmentContractAppService();
    await tester.pumpWidget(
      _app(service: service, scheduleStatus: InstallmentScheduleStatus.pending),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDetailSummaryCard), findsOneWidget);
    expect(find.text('分期合同'), findsOneWidget);
    expect(find.text('20260101'), findsOneWidget);
    expect(find.text('待还本金'), findsOneWidget);
    expect(find.text('已还利息'), findsOneWidget);
    expect(find.text('已还手续费'), findsOneWidget);
    expect(find.textContaining('本金 '), findsWidgets);
    expect(find.textContaining('分期方式 等额本金'), findsOneWidget);
    expect(find.textContaining('计息方式 按日计息'), findsOneWidget);
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
    final service = _FakeInstallmentContractAppService();
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
        service: _FakeInstallmentContractAppService(),
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
      final repair = _FakeStatusRepairAppService(
        validationResult: const ContractStatusValidationResult(
          repairedScheduleCount: 2,
          contractStatusChanged: true,
          issues: [
            ContractStatusValidationIssue(
              type: ContractStatusValidationIssueType
                  .skippedScheduleHasAllocation,
              message: '已跳过的还款计划存在还款分摊。',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        _app(
          service: _FakeInstallmentContractAppService(),
          statusRepair: repair,
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

      expect(repair.contractIds.single, 'contract-1');
      expect(find.text('校验完成，已修复 2 个还款计划及合同状态，另有 1 项数据冲突未处理'), findsOneWidget);
    },
  );

  testWidgets('schedule and repayment rows use badges and whitespace', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        service: _FakeInstallmentContractAppService(),
        scheduleStatus: InstallmentScheduleStatus.pending,
        scheduleCount: 2,
        repayments: [_repayment('repayment-1'), _repayment('repayment-2')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsNothing);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
  });
}

class _MockRepricingService extends Mock
    implements InstallmentRepricingAppService {}

Widget _app({
  required _FakeInstallmentContractAppService service,
  required InstallmentScheduleStatus scheduleStatus,
  InstallmentContractStatus contractStatus = InstallmentContractStatus.active,
  _FakeRepaymentAppService? repaymentService,
  _FakeStatusRepairAppService? statusRepair,
  int scheduleCount = 1,
  List<ContractRepayment> repayments = const [],
  InstallmentRepricingAppService? repricingService,
  List<String> Function()? unconfirmedRepricingIds,
}) {
  final planService = service.planService;
  final container = ProviderContainer(
    overrides: [
      installmentStatusRepairAppServiceProvider.overrideWithValue(
        statusRepair ?? _FakeStatusRepairAppService(),
      ),
      installmentContractProvider.overrideWith(
        (ref, contractId) async => _contract(
          status: contractStatus,
          unconfirmedRepricingIds: unconfirmedRepricingIds?.call() ?? const [],
        ),
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
      installmentContractAppServiceProvider.overrideWithValue(service),
      installmentPlanAppServiceProvider.overrideWithValue(planService),
      if (repricingService != null)
        installmentRepricingAppServiceProvider.overrideWithValue(
          repricingService,
        ),
      if (repaymentService != null)
        repaymentAppServiceProvider.overrideWithValue(repaymentService),
    ],
  );
  addTearDown(container.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const InstallmentDetailPage(contractId: 'contract-1'),
    ),
  );
}

InstallmentContractReadModel _contract({
  InstallmentContractStatus status = InstallmentContractStatus.active,
  List<String> unconfirmedRepricingIds = const [],
}) {
  return InstallmentContractReadModel(
    id: 'contract-1',
    unconfirmedRepricingIds: unconfirmedRepricingIds,
    liabilityAccountId: 'loan',
    sourceType: InstallmentSourceType.disbursement,
    disbursementAccountId: 'cash',
    principal: const Money(minorUnits: 10000),
    borrowingDate: DateTime(2026, 1, 1),
    status: status,
    createdAt: DateTime(2026, 1, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'contract-1:stage:1',
      totalPeriods: 1,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, 2, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.daily,
      feeMinor: 0,
    ),
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

class _FakeInstallmentContractAppService
    implements InstallmentContractAppService {
  final planService = _FakeInstallmentPlanAppService();
  List<SkipInstallmentScheduleCommand> get skipCommands =>
      planService.skipCommands;
  List<RestoreInstallmentScheduleCommand> get restoreCommands =>
      planService.restoreCommands;
  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) async {
    skipCommands.add(command);
  }

  Future<void> restoreSchedule(
    RestoreInstallmentScheduleCommand command,
  ) async {
    restoreCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeInstallmentPlanAppService implements InstallmentPlanAppService {
  final skipCommands = <SkipInstallmentScheduleCommand>[];
  final restoreCommands = <RestoreInstallmentScheduleCommand>[];
  @override
  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) async =>
      skipCommands.add(command);

  @override
  Future<void> restoreSchedule(
    RestoreInstallmentScheduleCommand command,
  ) async => restoreCommands.add(command);

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

class _FakeStatusRepairAppService implements InstallmentStatusRepairAppService {
  _FakeStatusRepairAppService({
    this.validationResult = const ContractStatusValidationResult(
      repairedScheduleCount: 0,
      contractStatusChanged: false,
    ),
  });

  final ContractStatusValidationResult validationResult;
  final contractIds = <String>[];

  @override
  Future<ContractStatusValidationResult> validateAndRepair(
    String contractId,
  ) async {
    contractIds.add(contractId);
    return validationResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
