import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/port/advance_case_repository.dart';

class FakeAdvanceCaseRepository implements AdvanceCaseRepository {
  FakeAdvanceCaseRepository([Iterable<AdvanceCase> initial = const []])
    : _cases = {for (final value in initial) value.id: value};

  final Map<String, AdvanceCase> _cases;

  Iterable<AdvanceCase> get values => _cases.values;

  @override
  Future<AdvanceCase?> findById(String id) async => _cases[id];

  @override
  Future<void> save(AdvanceCase advanceCase) async {
    advanceCase.validate();
    _cases[advanceCase.id] = advanceCase;
  }

  @override
  Future<void> deleteById(String id) async {
    _cases.remove(id);
  }
}
