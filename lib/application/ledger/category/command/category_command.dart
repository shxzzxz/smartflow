import 'package:smartflow/core/patch/patch.dart';
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
  final String? parentId;
  final String? iconKey;
  final String? note;
  final int sortOrder;
}

class EditCategoryCommand {
  const EditCategoryCommand({
    required this.id,
    this.name,
    this.parentId,
    this.iconKey,
    this.note,
  });

  final String id;
  final String? name;
  final Patch<String>? parentId;
  final Patch<String>? iconKey;
  final Patch<String>? note;
}
