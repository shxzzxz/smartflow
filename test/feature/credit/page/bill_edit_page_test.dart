import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/page/bill_edit_page.dart';
import 'package:smartflow/feature/credit/provider/bill_query_providers.dart';

void main() {
  testWidgets('shows the consumption item window fields', (tester) async {
    final container = _container();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BillEditPage(billId: 'bill-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('统计起始日'), findsOneWidget);
    expect(find.text('2026-06-05'), findsOneWidget);
    expect(find.text('统计结束日'), findsOneWidget);
    expect(find.text('2026-07-04'), findsOneWidget);
    addTearDown(container.dispose);
  });

  testWidgets('saving pops back after a successful submit', (tester) async {
    final service = _RecordingGenerationService();
    final container = ProviderContainer(
      overrides: [
        billDetailProvider('bill-1').overrideWith((ref) async => _detail()),
        creditBillGenerationAppServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const _HostPage()),
        GoRoute(
          path: '/bills/:billId/edit',
          builder: (context, state) =>
              BillEditPage(billId: state.pathParameters['billId']!),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('host'), findsOneWidget);
    expect(service.updatedConsumptionWindows.single.billId, 'bill-1');
    expect(service.updatedConsumptionWindows.single.billItemId, 'item-1');
    expect(
      service.updatedConsumptionWindows.single.endInclusive,
      DateTime(2026, 7, 4),
    );
  });
}

ProviderContainer _container() {
  return ProviderContainer(
    overrides: [
      billDetailProvider('bill-1').overrideWith((ref) async => _detail()),
    ],
  );
}

BillDetailReadModel _detail() {
  return BillDetailReadModel(
    summary: BillSummaryReadModel(
      id: 'bill-1',
      accountId: 'account',
      period: BillPeriod(year: 2026, month: 7),
      status: BillStatus.open,
      expectedPrincipal: Money.zero(),
      expectedInterest: Money.zero(),
      expectedFee: Money.zero(),
      pendingPrincipal: Money.zero(),
      itemCount: 0,
      overdueItemCount: 0,
    ),
    items: [
      BillItemReadModel(
        id: 'item-1',
        itemType: BillItemType.consumption,
        status: BillItemStatus.pending,
        billingState: BillItemBillingState.open,
        repaymentDate: DateTime(2026, 7, 25),
        startInclusive: DateTime(2026, 6, 5),
        endInclusive: DateTime(2026, 7, 4),
        expectedPrincipal: const Money(minorUnits: 1000),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        allocated: RepaymentAmountDto.zero,
        isOverdue: false,
      ),
    ],
    repayments: const [],
  );
}

class _HostPage extends StatefulWidget {
  const _HostPage();

  @override
  State<_HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<_HostPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.push('/bills/bill-1/edit');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('host'));
}

class _RecordingGenerationService implements CreditBillGenerationAppService {
  final updatedConsumptionWindows =
      <
        ({
          String billId,
          String billItemId,
          DateTime startInclusive,
          DateTime endInclusive,
        })
      >[];

  @override
  Future<void> updateConsumptionWindow({
    required String billId,
    required String billItemId,
    required DateTime startInclusive,
    required DateTime endInclusive,
  }) async {
    updatedConsumptionWindows.add((
      billId: billId,
      billItemId: billItemId,
      startInclusive: startInclusive,
      endInclusive: endInclusive,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
