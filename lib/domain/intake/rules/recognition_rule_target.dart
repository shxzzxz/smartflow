import '../import/import_models.dart' show ImportCategoryKind;
import 'recognition_rule.dart';

class RecognitionRuleTarget {
  RecognitionRuleTarget({
    required this.id,
    required this.kind,
    required List<String> path,
    this.direction,
    this.parentId,
    this.iconKey,
    this.profileKey,
    this.isFundAccount = false,
  }) : path = List.unmodifiable(path);

  final String id;
  final RecognitionRuleKind kind;
  final ImportCategoryKind? direction;
  final String? parentId;
  final String? iconKey;
  final String? profileKey;
  final bool isFundAccount;
  final List<String> path;

  String get name => path.last;
  String get displayName => path.join(' / ');
}
