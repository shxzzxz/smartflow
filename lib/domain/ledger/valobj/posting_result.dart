import '../entity/account.dart';
import '../entity/transaction.dart';

class PostingResult {
  const PostingResult({required this.transaction, required this.accounts});

  final Transaction transaction;
  final List<Account> accounts;
}
