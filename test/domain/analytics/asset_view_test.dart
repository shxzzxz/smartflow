import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/analytics/entity/asset_view.dart';

void main() {
  test('custom views require an explicit nonempty account scope', () {
    expect(
      () => AssetView(id: 'custom', name: '日常'),
      throwsA(isA<BusinessException>()),
    );
    expect(
      () => AssetView(id: 'custom', name: '日常', accountIds: ['cash', 'cash']),
      throwsA(isA<BusinessException>()),
    );
  });

  test(
    'default view has an editable explicit scope and a protected name and position',
    () {
      final view = AssetView(
        id: AssetView.defaultId,
        name: AssetView.defaultName,
      );
      expect(view.includesAccount('future-account'), isFalse);
      final edited = view.copyWith(accountIds: ['cash']);
      expect(edited.includesAccount('cash'), isTrue);
      expect(edited.includesAccount('future-account'), isFalse);
      expect(edited.copyWith(accountIds: []).accountIds, isEmpty);
      expect(
        () => view.copyWith(name: '改名'),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => view.copyWith(sortOrder: 1),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'group assignments must reference the view own groups and account scope',
    () {
      for (final assignments in [
        {'outside': 'fund'},
        {'cash': 'unknown'},
      ]) {
        expect(
          () => AssetView(
            id: 'custom',
            name: '日常',
            accountIds: ['cash'],
            groups: [AssetViewGroup(id: 'fund', name: '资金')],
            accountGroupIds: assignments,
          ),
          throwsA(isA<BusinessException>()),
        );
      }
      expect(
        () => AssetView(
          id: 'custom',
          name: '日常',
          accountIds: ['cash'],
          groups: [
            AssetViewGroup(id: 'fund', name: '资金'),
            AssetViewGroup(id: 'fund', name: '重复'),
          ],
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'moving an account appends it to the target group and leaves the original view intact',
    () {
      final original = _view();
      final moved = original.moveAccount('a', 'debt');
      expect(moved.accountsInGroup('fund'), ['hidden', 'b']);
      expect(moved.accountsInGroup('debt'), ['c', 'a']);
      expect(original.accountsInGroup('fund'), ['a', 'hidden', 'b']);
      expect(
        () => original.moveAccount('outside', 'fund'),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => original.moveAccount('a', 'outside-group'),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'reordering a group preserves other groups and rejects incomplete contents',
    () {
      final view = _view();
      final ordered = view.reorderAccounts('fund', ['b', 'hidden', 'a']);
      expect(ordered.accountIds, ['b', 'hidden', 'c', 'a']);
      expect(ordered.accountsInGroup('debt'), ['c']);
      expect(
        () => view.reorderAccounts('fund', ['b', 'a']),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => view.reorderAccounts('fund', ['b', 'b', 'a']),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'deleting a group makes all its scope entries ungrouped without removing accounts',
    () {
      final view = _view();
      final deleted = view.deleteGroup('fund');
      expect(deleted.accountIds, ['a', 'hidden', 'c', 'b']);
      expect(deleted.accountsInGroup(null), ['a', 'hidden', 'b']);
      expect(deleted.groups.map((group) => group.id), ['debt']);
      expect(view.groupIdFor('hidden'), 'fund');
    },
  );
}

AssetView _view() => AssetView(
  id: 'view',
  name: '日常',
  accountIds: ['a', 'hidden', 'c', 'b'],
  groups: [
    AssetViewGroup(id: 'fund', name: '资金'),
    AssetViewGroup(id: 'debt', name: '负债'),
  ],
  accountGroupIds: {'a': 'fund', 'hidden': 'fund', 'b': 'fund', 'c': 'debt'},
);
