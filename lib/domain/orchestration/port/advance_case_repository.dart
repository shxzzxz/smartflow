import '../entity/advance_case.dart';

abstract interface class AdvanceCaseRepository {
  Future<AdvanceCase?> findById(String id);

  Future<Map<String, AdvanceCase>> findByIds(Set<String> ids);

  Stream<AdvanceCase?> watchById(String id);

  Future<void> save(AdvanceCase advanceCase);

  Future<void> deleteById(String id);
}
