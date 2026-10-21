import '../../../../core/id/id_generator.dart';
import '../../../shared/transaction_runner.dart';
import '../query/counterparty_read_models.dart';
import '../query/port/counterparty_repository.dart';

/// 对手方词表应用服务。
///
/// 名称去除首尾空白后精确唯一；创建同名对手方时复用既有记录。交易关联
/// 通过交易自身的 `counterpartyId` 写入，不在本服务中维护关联表。
class CounterpartyApplicationService {
  const CounterpartyApplicationService({
    required CounterpartyRepository repository,
    required IdGenerator idGenerator,
    required TransactionRunner transactionRunner,
  }) : _repository = repository,
       _idGenerator = idGenerator,
       _transactionRunner = transactionRunner;

  final CounterpartyRepository _repository;
  final IdGenerator _idGenerator;
  final TransactionRunner _transactionRunner;

  Stream<List<CounterpartyView>> watchCounterparties() =>
      _repository.watchCounterparties();

  Future<List<CounterpartyView>> listCounterparties() =>
      _repository.listCounterparties();

  /// 创建对手方并返回其 ID；词表内已有同名对手方时复用既有记录。
  Future<String> createCounterparty(String name) async {
    final trimmed = _normalizeName(name);
    final counterparties = await _repository.listCounterparties();
    for (final counterparty in counterparties) {
      if (counterparty.name == trimmed) return counterparty.id;
    }
    final id = _idGenerator.newId();
    await _repository.insertCounterparty(id: id, name: trimmed);
    return id;
  }

  Future<void> renameCounterparty({
    required String id,
    required String name,
  }) async {
    final trimmed = _normalizeName(name);
    final counterparties = await _repository.listCounterparties();
    for (final counterparty in counterparties) {
      if (counterparty.id != id && counterparty.name == trimmed) {
        throw StateError('A counterparty named "$trimmed" already exists.');
      }
    }
    await _repository.renameCounterparty(id: id, name: trimmed);
  }

  /// 删除词表记录并解除全部交易引用；两步写入由同一用例事务包裹。
  Future<void> deleteCounterparty(String id) {
    return _transactionRunner.run(() async {
      await _repository.clearTransactionReferences(id);
      await _repository.deleteCounterparty(id);
    });
  }

  String _normalizeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Counterparty name cannot be empty.',
      );
    }
    return trimmed;
  }
}
