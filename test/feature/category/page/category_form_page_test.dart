import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/category/page/category_form_page.dart';

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
