import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/widget/app_form_section.dart';
import 'package:smartflow/feature/account/page/account_form_page.dart';

void main() {
  testWidgets('name validator blocks account submit', (tester) async {
    final service = _FakeAccountAppService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountAppServiceProvider.overrideWith((ref) => service)],
        child: const MaterialApp(home: AccountFormPage()),
      ),
    );

    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入账户名称'), findsWidgets);
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
          accountAppServiceProvider.overrideWith(
            (ref) => _FakeAccountAppService(),
          ),
        ],
        child: const MaterialApp(home: AccountFormPage()),
      ),
    );

    expect(find.byType(AppFormSection), findsAtLeastNWidgets(3));
    expect(find.byType(Divider), findsNothing);
  });
}

class _FakeAccountAppService implements AccountAppService {
  final createCommands = <CreateAccountCommand>[];

  @override
  Future<Account> createAccount(CreateAccountCommand command) async {
    createCommands.add(command);
    return Account(
      id: 'created',
      name: command.name,
      type: command.type,
      balance: const Money(minorUnits: 0),
    );
  }

  @override
  Future<void> editAccount(EditAccountCommand command) async {}

  @override
  Future<void> archiveAccount(ArchiveAccountCommand command) async {}
}
