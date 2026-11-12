import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:smartflow/application/data_management/icons/command/user_business_icon_app_service.dart';
import 'package:smartflow/application/data_management/icons/port/user_business_icon_store.dart';
import 'package:smartflow/application/data_management/icons/query/port/user_business_icon_reference_query.dart';
import 'package:smartflow/application/data_management/icons/query/user_business_icon_query_service.dart';
import 'package:smartflow/application/data_management/icons/user_business_icon_models.dart';
import 'package:smartflow/core/error/app_exception.dart';

void main() {
  final icon = UserBusinessIconRecord(
    type: UserBusinessIconType.account,
    key: 'custom-account',
    label: '自定义账户',
    filePath: '/icons/custom-account.png',
    createdAt: DateTime.utc(2026, 11, 12),
  );

  test(
    'blocks deletion while an account or category still references it',
    () async {
      final store = _FakeIconStore([icon]);
      final service = UserBusinessIconAppService(
        store: store,
        references: _FakeReferenceQuery({icon.refId: 2}),
      );

      await expectLater(
        service.delete(icon),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            'application.data_management.icons.in_use',
          ),
        ),
      );
      expect(store.deleted, isEmpty);
    },
  );

  test('deletes an unreferenced icon', () async {
    final store = _FakeIconStore([icon]);
    final service = UserBusinessIconAppService(
      store: store,
      references: _FakeReferenceQuery(),
    );

    await service.delete(icon);

    expect(store.deleted, [icon.refId]);
  });

  test('query combines stored icons with current reference counts', () async {
    final service = UserBusinessIconQueryServiceImpl(
      store: _FakeIconStore([icon]),
      references: _FakeReferenceQuery({icon.refId: 3}),
    );

    final entries = await service.list();

    expect(entries.single.icon.refId, icon.refId);
    expect(entries.single.usageCount, 3);
  });
}

class _FakeIconStore implements UserBusinessIconStore {
  _FakeIconStore(this.icons);

  final List<UserBusinessIconRecord> icons;
  final List<String> deleted = [];

  @override
  Future<List<UserBusinessIconRecord>> load() async => icons;

  @override
  Future<UserBusinessIconRecord?> pickAndStore(
    UserBusinessIconType type,
  ) async {
    return null;
  }

  @override
  Future<void> delete(UserBusinessIconRecord icon) async {
    deleted.add(icon.refId);
  }

  @override
  Future<Map<String, Uint8List>> exportBackupFiles() async => const {};

  @override
  Future<void> restoreBackupFiles(Map<String, Uint8List> files) async {}
}

class _FakeReferenceQuery implements UserBusinessIconReferenceQuery {
  _FakeReferenceQuery([this.counts = const {}]);

  final Map<String, int> counts;

  @override
  Future<Map<String, int>> countByRef() async => counts;
}
