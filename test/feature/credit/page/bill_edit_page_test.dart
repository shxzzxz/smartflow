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
  testWidgets('shows the bill window fields for a credit bill', (tester) async {
    final container = _container();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BillEditPage(billId: 'bill-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('起始日'), findsOneWidget);
    expect(find.text('2026-06-05'), findsOneWidget);
    expect(find.text('出账日'), findsOneWidget);
    expect(find.text('2026-07-05'), findsOneWidget);
    expect(find.text('还款日'), findsOneWidget);
    expect(find.text('2026-07-25'), findsOneWidget);
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
          builder:
              (context, state) =>
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
    expect(service.updatedWindows.single.billId, 'bill-1');
    expect(service.updatedWindows.single.billingDate, DateTime(2026, 7, 5));
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
      windowStartDate: DateTime(2026, 6, 5),
      windowBillingDate: DateTime(2026, 7, 5),
      windowRepaymentDate: DateTime(2026, 7, 25),
    ),
    items: const [],
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
  final updatedWindows =
      <({String billId, DateTime startDate, DateTime billingDate})>[];

  @override
  Future<void> updateBillWindow({
    required String billId,
    required DateTime startDate,
    required DateTime billingDate,
  }) async {
    updatedWindows.add((
      billId: billId,
      startDate: startDate,
      billingDate: billingDate,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
