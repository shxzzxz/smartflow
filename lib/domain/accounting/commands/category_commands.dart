import '../../../core/money/money.dart';
import '../enums/accounting_enums.dart';

class CreateCategoryCommand {
  const CreateCategoryCommand({
    required this.name,
    required this.type,
    this.parentId,
    this.currencyCode = Money.defaultCurrency,
    this.iconKey,
    this.note,
    this.sortOrder = 0,
  });

  final String name;
  final AccountType type;
  final int? parentId;
  final String currencyCode;
  final String? iconKey;
  final String? note;
  final int sortOrder;
}
