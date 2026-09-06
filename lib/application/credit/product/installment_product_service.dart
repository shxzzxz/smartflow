import '../../../core/error/app_exception.dart';
import '../../../core/id/id_generator.dart';
import '../../../core/money/rounding_mode.dart';
import '../../../domain/credit/entity/installment_product.dart';
import '../../../domain/credit/port/installment_product_repository.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/valobj/day_count_convention.dart';
import '../../../domain/credit/valobj/installment_stage_rule.dart';
import '../../shared/transaction_runner.dart';

class InstallmentProductReadModel {
  const InstallmentProductReadModel({
    required this.id,
    required this.name,
    required this.archived,
    required this.stages,
    required this.dayCount,
    required this.rounding,
  });
  final String id;
  final String name;
  final bool archived;
  final List<InstallmentStageRule> stages;
  final DayCountConvention dayCount;
  final RoundingMode rounding;
}

abstract interface class InstallmentProductService {
  Future<List<InstallmentProductReadModel>> list();
  Future<String> save({
    String? id,
    required String name,
    required List<InstallmentStageRule> stages,
    required DayCountConvention dayCount,
    required RoundingMode rounding,
  });
  Future<void> setArchived(String id, bool archived);
  Future<void> delete(String id);
}

class InstallmentProductServiceImpl implements InstallmentProductService {
  const InstallmentProductServiceImpl({
    required InstallmentProductRepository repository,
    required TransactionRunner runner,
    required IdGenerator ids,
  }) : _repository = repository,
       _runner = runner,
       _ids = ids;
  final InstallmentProductRepository _repository;
  final TransactionRunner _runner;
  final IdGenerator _ids;

  @override
  Future<List<InstallmentProductReadModel>> list() async => [
    for (final product in await _repository.list())
      InstallmentProductReadModel(
        id: product.id,
        name: product.name,
        archived: product.archived,
        stages: product.stages,
        dayCount: product.dayCount,
        rounding: product.rounding,
      ),
  ];

  @override
  Future<String> save({
    String? id,
    required String name,
    required List<InstallmentStageRule> stages,
    required DayCountConvention dayCount,
    required RoundingMode rounding,
  }) => _runner.run(() async {
    final previous = id == null ? null : await _require(id);
    final productId = previous?.id ?? _ids.newId();
    final owned = previous?.stages.map((s) => s.id).toSet() ?? <String>{};
    final product = InstallmentProduct(
      id: productId,
      name: name.trim(),
      archived: previous?.archived ?? false,
      createdAt: previous?.createdAt ?? DateTime.now(),
      dayCount: dayCount,
      rounding: rounding,
      stages: [
        for (final s in stages)
          _withId(s, owned.contains(s.id) ? s.id : _ids.newId()),
      ],
    );
    product.validate();
    await _repository.save(product);
    return productId;
  });

  @override
  Future<void> setArchived(String id, bool archived) => _runner.run(() async {
    final previous = await _require(id);
    await _repository.save(
      InstallmentProduct(
        id: id,
        name: previous.name,
        stages: previous.stages,
        createdAt: previous.createdAt,
        archived: archived,
        dayCount: previous.dayCount,
        rounding: previous.rounding,
      ),
    );
  });

  @override
  Future<void> delete(String id) => _runner.run(() async {
    await _require(id);
    if (await _repository.isUsed(id)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '已有合同使用该产品，请归档产品',
      );
    }
    await _repository.delete(id);
  });

  Future<InstallmentProduct> _require(String id) async {
    final product = await _repository.find(id);
    if (product == null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '产品不存在',
      );
    }
    return product;
  }

  InstallmentStageRule _withId(InstallmentStageRule s, String id) =>
      s.kind == InstallmentStageKind.deferment
      ? InstallmentStageRule.deferment(id: id)
      : InstallmentStageRule.repayment(
          id: id,
          method: s.method!,
          intervalMonths: s.intervalMonths,
          ratePeriod: s.ratePeriod,
          accrual: s.accrual,
          amountAlgorithm: s.amountAlgorithm,
        );
}
