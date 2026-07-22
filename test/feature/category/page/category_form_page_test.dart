import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/feature/category/page/category_form_page.dart';
import 'package:smartflow/feature/category/view_model/category_form_view_model.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  testWidgets('name validator blocks category submit', (tester) async {
    final service = _FakeCategoryAppService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryAppServiceProvider.overrideWith((ref) => service),
          categoryTreeProvider(
            AccountType.expense,
          ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
          categoryTreeProvider(
            AccountType.income,
          ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
        ],
        child: const MaterialApp(home: CategoryFormPage()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入分类名称'), findsWidgets);
    expect(service.createCommands, isEmpty);
  });

  testWidgets('uses whitespace sections instead of field dividers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(480, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryAppServiceProvider.overrideWith(
            (ref) => _FakeCategoryAppService(),
          ),
          categoryTreeProvider(
            AccountType.expense,
          ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
          categoryTreeProvider(
            AccountType.income,
          ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
        ],
        child: const MaterialApp(home: CategoryFormPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(AppFormSection), findsAtLeastNWidgets(3));
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('shows loading then creates controllers from category snapshot', (
    tester,
  ) async {
    final categories = StreamController<Map<String, Account>>();
    addTearDown(categories.close);
    final category = _category('category-1', name: '餐饮', note: '日常支出');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsByIdProvider.overrideWith((ref) => categories.stream),
          categoryTreeProvider(
            AccountType.expense,
          ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
          categoryTreeProvider(
            AccountType.income,
          ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
        ],
        child: const MaterialApp(
          home: CategoryFormPage(categoryId: 'category-1'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    categories.add({category.id: category});
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.controller!.text, '餐饮');
  });

  testWidgets('ViewModel changes do not overwrite edited category text', (
    tester,
  ) async {
    final category = _category('category-1', name: '原始名称');
    final container = ProviderContainer(
      overrides: [
        accountsByIdProvider.overrideWithValue(
          AsyncValue.data({category.id: category}),
        ),
        categoryTreeProvider(
          AccountType.expense,
        ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
        categoryTreeProvider(
          AccountType.income,
        ).overrideWith((ref) => Stream.value(const <CategoryNode>[])),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: CategoryFormPage(categoryId: 'category-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '用户正在编辑');

    container
        .read(categoryFormViewModelProvider(categoryId: 'category-1').notifier)
        .setIconKey('another-category-icon');
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '用户正在编辑',
    );
  });
}

Account _category(String id, {required String name, String? note}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.expense,
    balance: const Money(minorUnits: 0),
    note: note,
  );
}

class _FakeCategoryAppService implements CategoryAppService {
  final createCommands = <CreateCategoryCommand>[];

  @override
  Future<Account> createCategory(CreateCategoryCommand command) async {
    createCommands.add(command);
    return Account(
      id: 'created',
      name: command.name,
      type: command.type,
      balance: const Money(minorUnits: 0),
    );
  }

  @override
  Future<void> editCategory(EditCategoryCommand command) async {}
}
