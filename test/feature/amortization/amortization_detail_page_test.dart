// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_command.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_plan_app_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_inline_action_button.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_refund.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_termination.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/feature/amortization/page/amortization_detail_page.dart';
import 'package:smartflow/feature/amortization/provider/amortization_providers.dart';

void main() {
  testWidgets('unavailable plan actions remain visible and disabled', (
    tester,
  ) async {
    final created = _plan();
    final terminated = created.terminatedWith(
      termination: AmortizationTermination(
        id: 'termination',
        planId: created.id,
        terminatedAt: DateTime(2026, 2, 1),
        categoryReturnAllocations: const [],
        settlementAllocations: const [],
        recognitionTransactionId: 'termination-entry',
      ),
      periods: created.periods,
    );

    await tester.pumpWidget(
      _app(plan: terminated, service: _FakeAmortizationPlanAppService()),
    );
    await tester.pumpAndSettle();

    final refund = tester.widget<AppInlineActionButton>(
      find.widgetWithText(AppInlineActionButton, '摊销退款'),
    );
    final termination = tester.widget<AppInlineActionButton>(
      find.widgetWithText(AppInlineActionButton, '摊销终止'),
    );
    expect(refund.onPressed, isNull);
    expect(termination.onPressed, isNull);
  });

  testWidgets('completed plan keeps refund and termination actions enabled', (
    tester,
  ) async {
    final created = _plan(totalMinor: 30000, recognitionCount: 1);
    final completed = created.withPeriods([
      created.periods.single.posted('entry'),
    ]);

    await tester.pumpWidget(
      _app(plan: completed, service: _FakeAmortizationPlanAppService()),
    );
    await tester.pumpAndSettle();

    final refund = tester.widget<AppInlineActionButton>(
      find.widgetWithText(AppInlineActionButton, '摊销退款'),
    );
    final termination = tester.widget<AppInlineActionButton>(
      find.widgetWithText(AppInlineActionButton, '摊销终止'),
    );
    expect(completed.status, AmortizationStatus.completed);
    expect(refund.onPressed, isNotNull);
    expect(termination.onPressed, isNotNull);
  });

  testWidgets('right swiping termination deletes that termination', (
    tester,
  ) async {
    final created = _plan();
    final posted = created.withPeriods([
      created.periods.single.posted('entry'),
    ]);
    final terminated = posted.terminatedWith(
      termination: AmortizationTermination(
        id: 'termination',
        planId: posted.id,
        terminatedAt: DateTime(2026, 2, 1),
        categoryReturnAllocations: const [],
        settlementAllocations: const [],
        recognitionTransactionId: 'termination-entry',
      ),
      periods: posted.periods,
    );
    final service = _FakeAmortizationPlanAppService();

    await tester.pumpWidget(_app(plan: terminated, service: service));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('amortization-termination-termination')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('删除摊销终止'),
      ),
      findsOneWidget,
    );
    expect(find.text('撤销终止'), findsNothing);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(service.deleteTerminationCommands, hasLength(1));
    expect(
      service.deleteTerminationCommands.single.terminationId,
      'termination',
    );
    expect(find.text('摊销终止已删除'), findsOneWidget);
  });

  testWidgets('refund row is actionable and hides category and account data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final created = _plan(totalMinor: 30000, recognitionCount: 3);
    final plan = created.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: created.id,
        categoryAllocations: singleAllocation(
          accountId: 'rent',
          amount: const Money(minorUnits: 5000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: const Money(minorUnits: 5000),
        ),
        transferTransactionId: 'refund-transfer',
      ),
    );

    await tester.pumpWidget(
      _app(plan: plan, service: _FakeAmortizationPlanAppService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('待摊金额'), findsOneWidget);
    expect(find.text('已摊销'), findsOneWidget);
    expect(find.text('累计退款'), findsOneWidget);
    expect(find.textContaining('原摊销额'), findsOneWidget);
    expect(find.textContaining('净摊销额'), findsOneWidget);
    expect(find.textContaining('摊销类型'), findsNothing);
    expect(find.textContaining('摊销期数'), findsOneWidget);
    expect(find.textContaining('首期日期'), findsOneWidget);
    expect(find.textContaining('期次间隔'), findsOneWidget);
    expect(find.textContaining('间隔数'), findsOneWidget);
    expect(find.text('摊销退款'), findsWidgets);
    expect(find.text('房租支出'), findsNothing);
    expect(find.text('现金'), findsNothing);
    expect(find.text('预付房租'), findsNothing);
  });

  testWidgets('right swiping refund deletes only that refund', (tester) async {
    final created = _plan(totalMinor: 30000, recognitionCount: 3);
    final plan = created.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: created.id,
        categoryAllocations: singleAllocation(
          accountId: 'rent',
          amount: const Money(minorUnits: 5000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: const Money(minorUnits: 5000),
        ),
        transferTransactionId: 'refund-transfer',
      ),
    );
    final service = _FakeAmortizationPlanAppService();

    await tester.pumpWidget(_app(plan: plan, service: service));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('amortization-refund-refund')),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('amortization-refund-refund')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除摊销退款'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(service.deleteRefundCommands.single.refundId, 'refund');
    expect(service.deleteCommands, isEmpty);
  });

  testWidgets('plan detail confirms destructive deletion', (tester) async {
    final plan = _plan();
    final service = _FakeAmortizationPlanAppService();

    await tester.pumpWidget(_app(plan: plan, service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除摊销计划'));
    await tester.pumpAndSettle();
    expect(find.text('将删除该计划及全部关联账务交易，且无法恢复。'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(service.deleteCommands, hasLength(1));
  });

  testWidgets('plan detail fits a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(
        plan: _plan(totalMinor: 30000, recognitionCount: 3),
        service: _FakeAmortizationPlanAppService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('配置编辑'), findsOneWidget);
  });

  testWidgets('refund activity opens the transaction detail', (tester) async {
    final created = _plan(totalMinor: 30000, recognitionCount: 3);
    final plan = created.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: created.id,
        categoryAllocations: singleAllocation(
          accountId: 'rent',
          amount: const Money(minorUnits: 5000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: const Money(minorUnits: 5000),
        ),
        transferTransactionId: 'refund-transfer',
      ),
    );
    final router = GoRouter(
      initialLocation: '/amortizations/plan',
      routes: [
        GoRoute(
          path: '/amortizations/:id',
          builder: (context, state) =>
              AmortizationDetailPage(planId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/transaction/:id',
          builder: (context, state) =>
              Scaffold(body: Text('交易详情 ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final transactions = {
      plan.initialTransactionId: _transaction(plan.initialTransactionId),
      for (final refund in plan.refunds)
        refund.transferTransactionId: _transaction(
          refund.transferTransactionId,
        ),
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          amortizationPlanProvider(
            plan.id,
          ).overrideWith((ref) => Stream.value(plan)),
          transactionQueryServiceProvider.overrideWithValue(
            _FakeTransactionQueryService(transactions),
          ),
          amortizationPlanAppServiceProvider.overrideWithValue(
            _FakeAmortizationPlanAppService(),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('amortization-refund-refund')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('amortization-refund-refund')));
    await tester.pumpAndSettle();

    expect(find.text('交易详情 refund-transfer'), findsOneWidget);
  });
}

Widget _app({
  required AmortizationPlan plan,
  required AmortizationPlanAppService service,
}) {
  final transactionIds = {
    plan.initialTransactionId,
    for (final period in plan.periods) ?period.transactionId,
    for (final refund in plan.refunds) refund.transferTransactionId,
    if (plan.termination case final termination?) ...[
      ?termination.recognitionTransactionId,
      ?termination.returnTransactionId,
    ],
  };
  final transactions = {
    for (final id in transactionIds)
      id: TransactionReadModel.fromTransaction(
        transaction: Transaction(
          id: id,
          businessPurpose: BusinessPurpose.transfer,
          occurredAt: DateTime(2026, 1, 15),
          primaryAmount: const Money(minorUnits: 10000),
          sourceKind: SourceKind.manual,
          isExcludedFromStats: false,
          isExcludedFromBudget: false,
        ),
      ),
  };
  return ProviderScope(
    overrides: [
      amortizationPlanProvider(
        plan.id,
      ).overrideWith((ref) => Stream.value(plan)),
      transactionQueryServiceProvider.overrideWithValue(
        _FakeTransactionQueryService(transactions),
      ),
      amortizationPlanAppServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: AmortizationDetailPage(planId: plan.id),
    ),
  );
}

AmortizationPlan _plan({int totalMinor = 10000, int recognitionCount = 1}) {
  return AmortizationPlan.create(
    id: 'plan',
    kind: AmortizationKind.prepaidExpense,
    deferralAccountId: 'prepaid',
    fundingAllocations: singleAllocation(
      accountId: 'cash',
      amount: Money(minorUnits: totalMinor),
    ),
    categoryAllocations: singleAllocation(
      accountId: 'rent',
      amount: Money(minorUnits: totalMinor),
    ),
    originalAmount: Money(minorUnits: totalMinor),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    firstRecognitionAt: DateTime(2026, 1, 31),
    recognitionCount: recognitionCount,
    initialTransactionId: 'initial',
  );
}

TransactionReadModel _transaction(String id) {
  return TransactionReadModel.fromTransaction(
    transaction: Transaction(
      id: id,
      businessPurpose: BusinessPurpose.transfer,
      occurredAt: DateTime(2026, 1, 15),
      primaryAmount: const Money(minorUnits: 10000),
      sourceKind: SourceKind.manual,
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
    ),
  );
}

class _FakeAmortizationPlanAppService implements AmortizationPlanAppService {
  final deleteTerminationCommands = <DeleteAmortizationTerminationCommand>[];
  final deleteRefundCommands = <DeleteAmortizationRefundCommand>[];
  final deleteCommands = <DeleteAmortizationPlanCommand>[];

  @override
  Future<AmortizationGenerationResult> deleteTermination(
    DeleteAmortizationTerminationCommand command,
  ) async {
    deleteTerminationCommands.add(command);
    return const AmortizationGenerationResult(generatedCount: 1);
  }

  @override
  Future<void> deletePlan(DeleteAmortizationPlanCommand command) async {
    deleteCommands.add(command);
  }

  @override
  Future<void> deleteRefund(DeleteAmortizationRefundCommand command) async {
    deleteRefundCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeTransactionQueryService implements TransactionQueryService {
  const _FakeTransactionQueryService(this.transactions);

  final Map<String, TransactionReadModel> transactions;

  @override
  Future<List<TransactionReadModel>> findTransactionsByIds(Set<String> ids) {
    return Future.value([for (final id in ids) ?transactions[id]]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
