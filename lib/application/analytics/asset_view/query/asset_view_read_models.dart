import '../../../../core/money/money.dart';

class AssetViewStatistics {
  const AssetViewStatistics({
    required this.assets,
    required this.liabilities,
    required this.netAssetChange,
    this.netAssetChangeRatio,
    this.isNewNetAssetValue = false,
  });
  final Money assets;
  final Money liabilities;
  final Money netAssetChange;
  final double? netAssetChangeRatio;
  final bool isNewNetAssetValue;
  Money get netAssets => assets - liabilities;
}
