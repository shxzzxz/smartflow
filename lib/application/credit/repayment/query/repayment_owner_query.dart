import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

abstract interface class RepaymentOwnerQuery {
  Future<RepaymentType?> findType(String repaymentId);
}

class RepaymentOwnerQueryImpl implements RepaymentOwnerQuery {
  const RepaymentOwnerQueryImpl({required RepaymentRepository repository})
    : _repository = repository;

  final RepaymentRepository _repository;

  @override
  Future<RepaymentType?> findType(String repaymentId) async {
    return (await _repository.findRepayment(repaymentId))?.repaymentType;
  }
}
