import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';

class CreateCategoryCommand {
  const CreateCategoryCommand({
    required this.name,
    required this.type,
    this.parentId,
    this.iconKey,
    this.note,
    this.sortOrder = 0,
  });

  final String name;
  final AccountType type;
  final int? parentId;
  final String? iconKey;
  final String? note;
  final int sortOrder;
}
