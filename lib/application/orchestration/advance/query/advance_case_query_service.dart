import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/port/advance_case_repository.dart';

class AdvanceCaseQueryService {
  const AdvanceCaseQueryService({required AdvanceCaseRepository repository})
    : _repository = repository;

  final AdvanceCaseRepository _repository;

  Future<AdvanceCase?> findById(String id) => _repository.findById(id);

  Future<Map<String, AdvanceCase>> findByIds(Set<String> ids) =>
      _repository.findByIds(ids);

  Stream<AdvanceCase?> watchById(String id) => _repository.watchById(id);
}
