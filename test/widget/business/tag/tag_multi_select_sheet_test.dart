// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/tag/tag_multi_select_sheet.dart';

import '../../../helper/fake_transaction_tag_repository.dart';

void main() {
  testWidgets('searches tags and selects a matching result', (tester) async {
    final repository = FakeTransactionTagRepository();
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _SequentialIds(),
    );
    TagMultiSelectResult? result;

    await tester.pumpWidget(
      _TestHost(
        service: service,
        tags: const [
          TagView(id: 'travel', name: '旅行', sortOrder: 0, usageCount: 0),
          TagView(id: 'work', name: '出差', sortOrder: 1, usageCount: 0),
        ],
        onResult: (value) => result = value,
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旅');
    await tester.pump();

    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('出差'), findsNothing);

    await tester.tap(find.text('旅行'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result?.selectedTagIds, {'travel'});
  });

  testWidgets('creates and selects the input content', (tester) async {
    final repository = FakeTransactionTagRepository();
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _SequentialIds(),
    );
    TagMultiSelectResult? result;

    await tester.pumpWidget(
      _TestHost(
        service: service,
        tags: const [],
        allowCreate: true,
        onResult: (value) => result = value,
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '装修');
    await tester.pump();

    expect(find.text('创建标签“装修”'), findsOneWidget);
    await tester.tap(find.text('创建标签“装修”'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result?.selectedTagIds, {'id-1'});
    expect((await repository.listTags()).single.name, '装修');
  });

  testWidgets('keeps the confirmation button above the keyboard', (
    tester,
  ) async {
    final repository = FakeTransactionTagRepository();
    final service = TagApplicationService(
      repository: repository,
      idGenerator: _SequentialIds(),
    );

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetViewInsets();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _TestHost(
        service: service,
        tags: const [
          TagView(id: 'travel', name: '旅行', sortOrder: 0, usageCount: 0),
          TagView(id: 'work', name: '出差', sortOrder: 1, usageCount: 0),
          TagView(id: 'home', name: '家庭', sortOrder: 2, usageCount: 0),
          TagView(id: 'project', name: '项目', sortOrder: 3, usageCount: 0),
        ],
        onResult: (_) {},
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    final keyboardTop =
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
        tester.view.viewInsets.bottom;
    final buttonBottom = tester.getBottomRight(find.byType(AppSubmitButton));
    expect(buttonBottom.dy, lessThanOrEqualTo(keyboardTop));
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({
    required this.service,
    required this.tags,
    required this.onResult,
    this.allowCreate = false,
  });

  final TagApplicationService service;
  final List<TagView> tags;
  final ValueChanged<TagMultiSelectResult?> onResult;
  final bool allowCreate;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [tagApplicationServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    onResult(
                      await showTagMultiSelectSheet(
                        context: context,
                        tags: tags,
                        selectedIds: const {},
                        allowCreate: allowCreate,
                      ),
                    );
                  },
                  child: const Text('打开'),
                ),
          ),
        ),
      ),
    );
  }
}

class _SequentialIds implements IdGenerator {
  var _next = 0;

  @override
  String newId() => 'id-${++_next}';
}
