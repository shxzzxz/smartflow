class CreateAccountGroupCommand {
  const CreateAccountGroupCommand({required this.name});

  final String name;
}

class RenameAccountGroupCommand {
  const RenameAccountGroupCommand({required this.id, required this.name});

  final String id;
  final String name;
}

class DeleteAccountGroupCommand {
  const DeleteAccountGroupCommand({required this.id});

  final String id;
}

class ReorderAccountGroupsCommand {
  const ReorderAccountGroupsCommand({required this.orderedIds});

  final List<String> orderedIds;
}

class MoveAccountToGroupCommand {
  const MoveAccountToGroupCommand({
    required this.accountId,
    required this.groupId,
    required this.orderedAccountIds,
  });

  final String accountId;
  final String? groupId;
  final List<String> orderedAccountIds;
}
