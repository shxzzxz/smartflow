import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/port/advance_case_repository.dart';

class AdvanceCaseQueryService {
  const AdvanceCaseQueryService({required AdvanceCaseRepository repository})
    : _repository = repository;

  final AdvanceCaseRepository _repository;

  Future<AdvanceCase?> findById(String id) => _repository.findById(id);
}
