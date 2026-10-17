import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/widget/business/transaction/transaction_batch_action_bar.dart';
import 'package:smartflow/widget/business/transaction/transaction_feed.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/feature/transaction/page/filtered_transactions_page.dart';
import 'package:smartflow/feature/transaction/view_model/filtered_transactions_view_model.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

void main() {
  testWidgets('renders filtered feed and opens transaction detail', (
    tester,
  ) async {
    final state = FilteredTransactionsState.loaded(
      title: '旅行',
      subtitle: '标签交易',
      emptyMessage: '该标签暂无交易',
      groups: [
        TransactionDayGroup(
          date: _transactionDate,
          incomeMinor: 0,
          expenseMinor: 1234,
          rows: const [
            TransactionRowPresentation(
              transactionId: 'tx-1',
              iconKey: 'meal',
              title: '餐饮',
              subtitle: '12:30',
              amountText: '-12.34',
              amountTone: FinanceTone.expense,
              accountFlow: TransactionAccountFlowPresentation(
                fallbackLabel: '现金',
              ),
              badges: [],
              canQuickEdit: false,
            ),
          ],
        ),
      ],
      hasMore: false,
      isLoadingMore: false,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, routeState) => const FilteredTransactionsPage(
            target: FilteredTransactionTarget.tag,
            targetId: 'travel',
          ),
        ),
        GoRoute(
          path: '/transaction/:id',
          builder: (context, routeState) =>
              Scaffold(body: Text('交易详情:${routeState.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredTransactionsViewModelProvider(
            FilteredTransactionTarget.tag,
            'travel',
          ).overrideWithValue(state),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('标签交易'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('-12.34'), findsOneWidget);

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    expect(find.text('交易详情:tx-1'), findsOneWidget);
  });

  testWidgets(
    'category long press selects rows, select all and back exit batch',
    (tester) async {
      await _pumpCategory(tester);
      expect(find.byType(TransactionBatchActionBar), findsNothing);
      await tester.longPress(find.text('交易 1'));
      await tester.pumpAndSettle();
      expect(find.text('已选 1 笔'), findsOneWidget);
      expect(
        tester
            .widget<TransactionFeedScrollView>(
              find.byType(TransactionFeedScrollView),
            )
            .enableRowQuickEdit,
        isFalse,
      );

      await tester.tap(find.text('交易 2'));
      await tester.pumpAndSettle();
      expect(find.text('已选 2 笔'), findsOneWidget);
      await tester.tap(find.byTooltip('取消全选'));
      await tester.pumpAndSettle();
      expect(find.text('选择交易'), findsOneWidget);
      final tagAction = tester.widget<InkWell>(
        find
            .ancestor(of: find.text('标签'), matching: find.byType(InkWell))
            .first,
      );
      expect(tagAction.onTap, isNull);
      await tester.tap(find.byTooltip('全选已加载'));
      await tester.pumpAndSettle();
      expect(find.text('已选 2 笔'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('分类交易'), findsOneWidget);
      expect(find.byType(TransactionBatchActionBar), findsNothing);
      expect(
        tester
            .widget<TransactionFeedScrollView>(
              find.byType(TransactionFeedScrollView),
            )
            .enableRowQuickEdit,
        isTrue,
      );
    },
  );

  testWidgets(
    'category delete requires confirmation and handles skipped records',
    (tester) async {
      final vm = await _pumpCategory(tester, skippedCount: 1);
      await tester.longPress(find.text('交易 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('全选已加载'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('确定删除选中的 2 笔交易？删除后交易及其账务记录将无法恢复。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(vm.deletedIds, isEmpty);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();
      expect(vm.deletedIds, {'tx-1', 'tx-2'});
      expect(find.text('已选 1 笔'), findsOneWidget);
      expect(find.text('已删除 1 笔交易，跳过 1 笔交易因存在业务关联未处理'), findsOneWidget);
    },
  );

  testWidgets('successful category delete exits batch mode', (tester) async {
    final vm = await _pumpCategory(tester);
    await tester.longPress(find.text('交易 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(vm.deletedIds, {'tx-1'});
    expect(find.byType(TransactionBatchActionBar), findsNothing);
    expect(find.text('已删除 1 笔交易'), findsOneWidget);
  });

  for (final operation in TransactionTagBatchOperation.values) {
    testWidgets('category tag UI forwards $operation', (tester) async {
      final vm = await _pumpCategory(tester);
      await tester.longPress(find.text('交易 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('标签'));
      await tester.pumpAndSettle();
      final label = switch (operation) {
        TransactionTagBatchOperation.add => '新增标签',
        TransactionTagBatchOperation.remove => '删除标签',
        TransactionTagBatchOperation.clear => '清空标签',
      };
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      if (operation == TransactionTagBatchOperation.clear) {
        expect(find.text('确定清空选中的 1 笔交易的全部标签？'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, '清空'));
      } else {
        await tester.enterText(find.byType(TextField), '新标签');
        await tester.pumpAndSettle();
        expect(
          find.text('创建标签“新标签”'),
          operation == TransactionTagBatchOperation.add
              ? findsOneWidget
              : findsNothing,
        );
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        await tester.tap(find.text('旅行'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
      }
      await tester.pumpAndSettle();
      final command = vm.tagCommands.single;
      expect(command.operation, operation);
      expect(command.transactionIds, {'tx-1'});
      expect(
        command.tagIds,
        operation == TransactionTagBatchOperation.clear ? isEmpty : {'travel'},
      );
      expect(find.text('已选 1 笔'), findsOneWidget);
    });
  }
}

final _transactionDate = DateTime(2026, 8, 26);

Future<_CategoryViewModel> _pumpCategory(
  WidgetTester tester, {
  int skippedCount = 0,
}) async {
  final vm = _CategoryViewModel(skippedCount);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const FilteredTransactionsPage(
          target: FilteredTransactionTarget.category,
          targetId: 'food',
        ),
      ),
      GoRoute(
        path: '/transaction/:id',
        builder: (context, state) => const Scaffold(body: Text('交易详情')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        filteredTransactionsViewModelProvider(
          FilteredTransactionTarget.category,
          'food',
        ).overrideWith(() => vm),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return vm;
}

class _CategoryViewModel extends FilteredTransactionsViewModel {
  _CategoryViewModel(this.skippedCount);
  final int skippedCount;
  Set<String> deletedIds = {};
  final tagCommands = <BatchTransactionTagsCommand>[];

  @override
  FilteredTransactionsState build(
    FilteredTransactionTarget target,
    String targetId,
  ) {
    return FilteredTransactionsState.loaded(
      title: '餐饮',
      subtitle: '分类交易',
      emptyMessage: '该分类暂无交易',
      groups: [
        TransactionDayGroup(
          date: _transactionDate,
          incomeMinor: 0,
          expenseMinor: 2468,
          rows: [
            for (var i = 1; i <= 2; i++)
              TransactionRowPresentation(
                transactionId: 'tx-$i',
                iconKey: 'meal',
                title: '交易 $i',
                subtitle: '12:30',
                amountText: '-12.34',
                amountTone: FinanceTone.expense,
                accountFlow: const TransactionAccountFlowPresentation(
                  fallbackLabel: '现金',
                ),
                badges: const [],
                canQuickEdit: true,
              ),
          ],
        ),
      ],
      hasMore: false,
      isLoadingMore: false,
    );
  }

  @override
  void enterBatchMode(String transactionId) {
    final current = state as FilteredTransactionsLoaded;
    state = current.copyWith(
      batch: FilteredTransactionBatchState(
        active: true,
        selectedIds: {transactionId},
      ),
    );
  }

  @override
  void setTransactionSelected(String transactionId, bool selected) {
    final current = state as FilteredTransactionsLoaded;
    final ids = {...current.batch.selectedIds};
    if (selected) {
      ids.add(transactionId);
    } else {
      ids.remove(transactionId);
    }
    state = current.copyWith(batch: current.batch.copyWith(selectedIds: ids));
  }

  @override
  void toggleSelectAll() {
    final current = state as FilteredTransactionsLoaded;
    state = current.copyWith(
      batch: current.batch.copyWith(
        selectedIds:
            current.selectedVisibleIds.length ==
                current.visibleTransactionIds.length
            ? {}
            : current.visibleTransactionIds,
      ),
    );
  }

  @override
  Future<List<TagView>> loadTags() async => const [
    TagView(id: 'travel', name: '旅行', sortOrder: 0, usageCount: 0),
  ];

  @override
  Future<TransactionCleanupResult> deleteTransactions(Set<String> ids) async {
    deletedIds = {...ids};
    if (skippedCount == 0) {
      exitBatchMode();
    } else {
      final current = state as FilteredTransactionsLoaded;
      state = FilteredTransactionsState.loaded(
        title: current.title,
        subtitle: current.subtitle,
        emptyMessage: current.emptyMessage,
        groups: [
          current.groups.single.copyWith(rows: [current.rows.last]),
        ],
        hasMore: false,
        isLoadingMore: false,
        batch: current.batch,
      );
    }
    return TransactionCleanupResult(
      deletedGroupCount: ids.length - skippedCount,
      skippedGroupCount: skippedCount,
    );
  }

  @override
  Future<TransactionBatchTagResult> updateTags({
    required Set<String> ids,
    required TransactionTagBatchOperation operation,
    required Set<String> tagIds,
  }) async {
    tagCommands.add(
      BatchTransactionTagsCommand(
        transactionIds: ids,
        operation: operation,
        tagIds: tagIds,
      ),
    );
    return TransactionBatchTagResult(
      updatedGroupCount: ids.length,
      skippedGroupCount: 0,
    );
  }
}
