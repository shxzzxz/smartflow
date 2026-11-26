import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

class CreateAccountCommand {
  const CreateAccountCommand({
    this.transactionBookId,
    required this.name,
    required this.type,
    this.openingBalance = const Money(minorUnits: 0),
    this.subtype,
    this.profileKey,
    this.iconKey,
    this.note,
    this.isHidden = false,
  });

  final String? transactionBookId;
  final String name;
  final AccountType type;
  final Money openingBalance;
  final AccountSubtype? subtype;
  final String? profileKey;
  final String? iconKey;
  final String? note;
  final bool isHidden;
}

class EditAccountCommand {
  const EditAccountCommand({
    this.transactionBookId,
    required this.id,
    this.name,
    this.isHidden,
    this.iconKey,
    this.note,
    this.targetBalance,
  });

  final String? transactionBookId;
  final String id;
  final String? name;
  final bool? isHidden;
  final Patch<String>? iconKey;
  final Patch<String>? note;
  final Money? targetBalance;
}

class ArchiveAccountCommand {
  const ArchiveAccountCommand({required this.id});

  final String id;
}

class RestoreAccountCommand {
  const RestoreAccountCommand({required this.id});

  final String id;
}

class DeleteAccountCommand {
  const DeleteAccountCommand({required this.id});

  final String id;
}
