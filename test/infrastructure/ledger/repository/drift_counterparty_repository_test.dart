import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_counterparty_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test('lists counterparties by name and resolves ids', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final repository = DriftCounterpartyRepository(database);
    await repository.insertCounterparty(id: 'cp-b', name: '农夫山泉');
    await repository.insertCounterparty(id: 'cp-a', name: '自如');

    final counterparties = await repository.listCounterparties();
    expect(counterparties.map((item) => item.name), ['农夫山泉', '自如']);

    final byId = await repository.findByIds(const {'cp-a', 'missing'});
    expect(byId.keys, {'cp-a'});
    expect(byId['cp-a']?.name, '自如');
  });

  test(
    'counterparty names are unique without a database foreign key',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftCounterpartyRepository(database);
      await repository.insertCounterparty(id: 'cp-a', name: '自如');

      await expectLater(
        repository.insertCounterparty(id: 'cp-b', name: '自如'),
        throwsA(isA<Exception>()),
      );
      expect(
        await database
            .customSelect('PRAGMA foreign_key_list(counterparties)')
            .get(),
        isEmpty,
      );
      expect(
        await database
            .customSelect('PRAGMA foreign_key_list(transactions)')
            .get(),
        isEmpty,
      );
    },
  );
}
