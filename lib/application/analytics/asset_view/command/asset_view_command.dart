import '../../../../domain/analytics/entity/asset_view.dart';

class SaveAssetViewCommand {
  SaveAssetViewCommand({
    this.id,
    this.expectedVersion,
    this.copyFrom,
    required this.name,
    required Iterable<String> accountIds,
  }) : accountIds = List.unmodifiable(accountIds);

  final String? id;
  final int? expectedVersion;
  final AssetView? copyFrom;
  final String name;
  final List<String> accountIds;
}
