import 'package:smartflow/domain/ledger/entity/account.dart';

class CategoryNode {
  const CategoryNode({required this.account, this.children = const []});

  final Account account;
  final List<Account> children;
}
