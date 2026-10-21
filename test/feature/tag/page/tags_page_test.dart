import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/feature/tag/page/tags_page.dart';

import '../../../helper/fake_transaction_tag_repository.dart';

void main() {
  testWidgets('opens tag transactions when the tag row is tapped', (
    tester,
  ) async {
    final repository = FakeTransactionTagRepository();
    const tag = TagView(id: 'travel', name: '旅行', sortOrder: 0, usageCount: 2);
    await repository.insertTag(id: tag.id, name: tag.name);
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _NoopIdGenerator(),
      transactionRunner: const _DirectTransactionRunner(),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const TagsPage()),
        GoRoute(
          path: '/tags/:id/transactions',
          builder: (context, state) =>
              Scaffold(body: Text('标签流水:${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagApplicationServiceProvider.overrideWithValue(service),
          tagListProvider.overrideWithValue(const AsyncData([tag])),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();

    expect(find.text('标签流水:travel'), findsOneWidget);
  });

  testWidgets('filters the tag list directly in management mode', (
    tester,
  ) async {
    final repository = FakeTransactionTagRepository();
    const tags = [
      TagView(id: 'travel', name: '旅行', sortOrder: 0, usageCount: 2),
      TagView(id: 'work', name: '出差', sortOrder: 1, usageCount: 1),
    ];
    for (final tag in tags) {
      await repository.insertTag(id: tag.id, name: tag.name);
    }
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _NoopIdGenerator(),
      transactionRunner: const _DirectTransactionRunner(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagApplicationServiceProvider.overrideWithValue(service),
          tagListProvider.overrideWithValue(const AsyncData(tags)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const TagsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '旅');
    await tester.pump();

    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('出差'), findsNothing);
  });

  testWidgets('migrates a tag without deleting the source', (tester) async {
    final repository = FakeTransactionTagRepository();
    const tags = [
      TagView(id: 'travel', name: '旅行', sortOrder: 0, usageCount: 1),
      TagView(id: 'work', name: '出差', sortOrder: 1, usageCount: 0),
    ];
    for (final tag in tags) {
      await repository.insertTag(id: tag.id, name: tag.name);
    }
    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: const {'travel'},
    );
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _NoopIdGenerator(),
      transactionRunner: const _DirectTransactionRunner(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagApplicationServiceProvider.overrideWithValue(service),
          tagListProvider.overrideWithValue(const AsyncData(tags)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const TagsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('迁移到…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '出差'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '迁移'));
    await tester.pumpAndSettle();

    expect((await repository.listTags()).map((tag) => tag.id), {
      'travel',
      'work',
    });
    expect(await repository.transactionTagIds('tx-1'), {'work'});
  });

  testWidgets('batch deletion searches and deletes selected tags', (
    tester,
  ) async {
    final repository = FakeTransactionTagRepository();
    final tags = const [
      TagView(id: 'travel', name: '旅行', sortOrder: 0, usageCount: 2),
      TagView(id: 'work', name: '出差', sortOrder: 1, usageCount: 1),
    ];
    for (final tag in tags) {
      await repository.insertTag(id: tag.id, name: tag.name);
    }
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _NoopIdGenerator(),
      transactionRunner: const _DirectTransactionRunner(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagApplicationServiceProvider.overrideWithValue(service),
          tagListProvider.overrideWithValue(AsyncData(tags)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const TagsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('批量操作标签'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旅');
    await tester.pump();

    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('出差'), findsNothing);

    await tester.tap(find.text('旅行'));
    await tester.pump();
    expect(find.text('已选 1 个标签'), findsOneWidget);
    await tester.tap(find.byTooltip('删除已选标签'));
    await tester.pumpAndSettle();

    expect(find.textContaining('确定删除选中的 1 个标签'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(
      (await repository.listTags()).map((tag) => tag.id),
      isNot(contains('travel')),
    );
    expect(await repository.listTags(), hasLength(1));
  });

  testWidgets('batch migration retargets selected tags and keeps them', (
    tester,
  ) async {
    final repository = FakeTransactionTagRepository();
    const tags = [
      TagView(id: 'travel', name: '旅行', sortOrder: 0, usageCount: 1),
      TagView(id: 'work', name: '出差', sortOrder: 1, usageCount: 1),
      TagView(id: 'home', name: '家庭', sortOrder: 2, usageCount: 0),
    ];
    for (final tag in tags) {
      await repository.insertTag(id: tag.id, name: tag.name);
    }
    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: const {'travel'},
    );
    await repository.replaceTransactionTags(
      transactionId: 'tx-2',
      tagIds: const {'work'},
    );
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _NoopIdGenerator(),
      transactionRunner: const _DirectTransactionRunner(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagApplicationServiceProvider.overrideWithValue(service),
          tagListProvider.overrideWithValue(const AsyncData(tags)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const TagsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('批量操作标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('旅行'));
    await tester.tap(find.text('出差'));
    await tester.pump();
    await tester.tap(find.byTooltip('更多批量操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('迁移到…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('家庭').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '迁移'));
    await tester.pumpAndSettle();

    expect((await repository.listTags()).map((tag) => tag.id), {
      'travel',
      'work',
      'home',
    });
    expect(await repository.transactionTagIds('tx-1'), {'home'});
    expect(await repository.transactionTagIds('tx-2'), {'home'});
  });

  testWidgets('batch merge removes selected tags after retargeting', (
    tester,
  ) async {
    final repository = FakeTransactionTagRepository();
    const tags = [
      TagView(id: 'travel', name: '旅行', sortOrder: 0, usageCount: 1),
      TagView(id: 'work', name: '出差', sortOrder: 1, usageCount: 1),
      TagView(id: 'home', name: '家庭', sortOrder: 2, usageCount: 0),
    ];
    for (final tag in tags) {
      await repository.insertTag(id: tag.id, name: tag.name);
    }
    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: const {'travel'},
    );
    await repository.replaceTransactionTags(
      transactionId: 'tx-2',
      tagIds: const {'work'},
    );
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _NoopIdGenerator(),
      transactionRunner: const _DirectTransactionRunner(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagApplicationServiceProvider.overrideWithValue(service),
          tagListProvider.overrideWithValue(const AsyncData(tags)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const TagsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('批量操作标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('旅行'));
    await tester.tap(find.text('出差'));
    await tester.pump();
    await tester.tap(find.byTooltip('更多批量操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('合并到…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('家庭').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '合并'));
    await tester.pumpAndSettle();

    expect((await repository.listTags()).map((tag) => tag.id), {'home'});
    expect(await repository.transactionTagIds('tx-1'), {'home'});
    expect(await repository.transactionTagIds('tx-2'), {'home'});
  });
}

class _NoopIdGenerator implements IdGenerator {
  @override
  String newId() => 'unused';
}

class _DirectTransactionRunner implements TransactionRunner {
  const _DirectTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}
