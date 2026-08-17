import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/shared/provider/tag_providers.dart';
import 'package:smartflow/feature/tag/page/tags_page.dart';

import '../../../helper/fake_transaction_tag_repository.dart';

void main() {
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

    await tester.tap(find.byTooltip('批量删除标签'));
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
}

class _NoopIdGenerator implements IdGenerator {
  @override
  String newId() => 'unused';
}
