import '../entity/advance_case.dart';
import '../valobj/advance_enums.dart';

abstract interface class AdvanceCaseRepository {
  Future<AdvanceCase?> findById(String id);

  Future<AdvanceCase?> findAccountCase({
    required String receivableAccountId,
    required AdvanceScenario scenario,
  });

  Future<void> save(AdvanceCase advanceCase);
}
