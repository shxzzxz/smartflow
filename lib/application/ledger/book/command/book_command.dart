class CreateBookCommand {
  const CreateBookCommand({required this.name});
  final String name;
}

class RenameBookCommand {
  const RenameBookCommand({required this.id, required this.name});
  final String id;
  final String name;
}

class DeleteBookCommand {
  const DeleteBookCommand({required this.id});
  final String id;
}

class ChangeTransactionBookCommand {
  const ChangeTransactionBookCommand({
    required this.transactionId,
    required this.bookId,
  });
  final String transactionId;
  final String bookId;
}
