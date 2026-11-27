import '../app_update_info.dart';

class AndroidAppUpdatePackage extends AppUpdatePackage {
  const AndroidAppUpdatePackage({
    required this.abi,
    required super.url,
    required this.androidVersionCode,
    super.sha256,
    super.size,
  });

  final String abi;
  final int androidVersionCode;

  factory AndroidAppUpdatePackage.fromJson(Map<String, Object?> json) {
    final abi = _readString(json, 'abi');
    final url = _readString(json, 'url');
    final sha256 = _readOptionalString(json, 'sha256');
    final size = _readOptionalInt(json, 'size');
    final androidVersionCode = _readInt(json, 'androidVersionCode');

    return AndroidAppUpdatePackage(
      abi: abi,
      url: url,
      androidVersionCode: androidVersionCode,
      sha256: sha256.isEmpty ? null : sha256.toLowerCase(),
      size: size,
    );
  }

  static String _readString(Map<String, Object?> json, String key) {
    final value = json[key];
    return value is String ? value.trim() : '';
  }

  static String _readOptionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    return value is String ? value.trim() : '';
  }

  static int _readInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static int? _readOptionalInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int && value > 0) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed != null && parsed > 0 ? parsed : null;
    }
    return null;
  }
}
