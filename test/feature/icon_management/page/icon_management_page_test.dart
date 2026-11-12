import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartflow/app/provider.dart';
import 'package:smartflow/app/user_business_icon_providers.dart';
import 'package:smartflow/application/data_management/icons/port/user_business_icon_store.dart';
import 'package:smartflow/application/data_management/icons/query/port/user_business_icon_reference_query.dart';
import 'package:smartflow/application/data_management/icons/user_business_icon_models.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/icon_management/page/icon_management_page.dart';

void main() {
  testWidgets('lists custom icons and blocks deletion while in use', (
    tester,
  ) async {
    final icon = UserBusinessIconRecord(
      type: UserBusinessIconType.account,
      key: 'account-icon',
      label: '自定义账户',
      filePath: '/missing/account-icon.png',
      createdAt: DateTime.utc(2026, 11, 12),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userBusinessIconStoreProvider.overrideWithValue(
            _FakeIconStore([icon]),
          ),
          userBusinessIconReferenceQueryProvider.overrideWithValue(
            _FakeReferenceQuery({icon.refId: 2}),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const IconManagementPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('账户图标'), findsOneWidget);
    expect(find.text('分类图标'), findsOneWidget);
    expect(find.text('自定义账户'), findsOneWidget);
    expect(find.text('已被 账户使用 2 次'), findsOneWidget);
    final delete = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('正在使用，无法删除'),
        matching: find.byType(IconButton),
      ),
    );
    expect(delete.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

class _FakeIconStore implements UserBusinessIconStore {
  _FakeIconStore(this.icons);

  final List<UserBusinessIconRecord> icons;

  @override
  Future<List<UserBusinessIconRecord>> load() async => icons;

  @override
  Future<UserBusinessIconRecord?> pickAndStore(
    UserBusinessIconType type,
  ) async {
    return null;
  }

  @override
  Future<void> delete(UserBusinessIconRecord icon) async {}

  @override
  Future<Map<String, Uint8List>> exportBackupFiles() async => const {};

  @override
  Future<void> restoreBackupFiles(Map<String, Uint8List> files) async {}
}

class _FakeReferenceQuery implements UserBusinessIconReferenceQuery {
  _FakeReferenceQuery(this.counts);

  final Map<String, int> counts;

  @override
  Future<Map<String, int>> countByRef() async => counts;
}
