import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/port/advance_case_repository.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

class FakeAdvanceCaseRepository implements AdvanceCaseRepository {
  FakeAdvanceCaseRepository([Iterable<AdvanceCase> initial = const []])
    : _cases = {for (final value in initial) value.id: value};

  final Map<String, AdvanceCase> _cases;

  Iterable<AdvanceCase> get values => _cases.values;

  @override
  Future<AdvanceCase?> findAccountCase({
    required String receivableAccountId,
    required AdvanceScenario scenario,
  }) async {
    for (final value in _cases.values) {
      if (value.trackingMode == AdvanceTrackingMode.account &&
          value.receivableAccountId == receivableAccountId &&
          value.scenario == scenario) {
        return value;
      }
    }
    return null;
  }

  @override
  Future<AdvanceCase?> findById(String id) async => _cases[id];

  @override
  Future<void> save(AdvanceCase advanceCase) async {
    advanceCase.validate();
    _cases[advanceCase.id] = advanceCase;
  }
}
