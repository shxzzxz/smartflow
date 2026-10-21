import 'package:smartflow/application/ledger/counterparty/query/counterparty_read_models.dart';
import 'package:smartflow/application/ledger/counterparty/query/port/counterparty_repository.dart';

class FakeCounterpartyRepository implements CounterpartyRepository {
  FakeCounterpartyRepository([Iterable<CounterpartyView> initial = const []])
    : _counterparties = {for (final item in initial) item.id: item};

  final Map<String, CounterpartyView> _counterparties;

  @override
  Future<Map<String, CounterpartyView>> findByIds(Set<String> ids) async {
    final result = <String, CounterpartyView>{};
    for (final id in ids) {
      final counterparty = _counterparties[id];
      if (counterparty != null) result[id] = counterparty;
    }
    return result;
  }

  @override
  Future<void> insertCounterparty({
    required String id,
    required String name,
  }) async {
    _counterparties[id] = CounterpartyView(id: id, name: name);
  }

  @override
  Future<List<CounterpartyView>> listCounterparties() async {
    final items = _counterparties.values.toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    return items;
  }

  @override
  Stream<List<CounterpartyView>> watchCounterparties() async* {
    yield await listCounterparties();
  }
}
