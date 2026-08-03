import 'package:smartflow/domain/ledger/entity/account_group.dart';
import 'package:smartflow/domain/ledger/port/account_group_repository.dart';

abstract interface class AccountGroupQueryService {
  Stream<List<AccountGroup>> watchGroups();
}

class AccountGroupQueryServiceImpl implements AccountGroupQueryService {
  const AccountGroupQueryServiceImpl(this._repository);

  final AccountGroupRepository _repository;

  @override
  Stream<List<AccountGroup>> watchGroups() => _repository.watchAll();
}
