import 'app_update_channel.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.channel,
    required this.versionName,
    required this.buildNumber,
    required this.universalApk,
    required this.releaseUrl,
    required this.required,
    required this.notes,
    required this.packages,
  });

  final AppUpdateChannel channel;
  final String versionName;
  final int buildNumber;
  final AppUpdateUniversalApk universalApk;
  final String releaseUrl;
  final bool required;
  final String notes;
  final List<AppUpdatePackage> packages;

  factory AppUpdateInfo.fromJson(Map<String, Object?> json) {
    final channel = AppUpdateChannel.fromCode(_readString(json, 'channel'));
    final versionName = _readString(json, 'versionName');
    final buildNumber = _readInt(json, 'buildNumber');
    final universalApk = _readUniversalApk(json['universalApk']);
    final releaseUrl = _readString(json, 'releaseUrl');
    final notes = _readOptionalString(json, 'notes');
    final required = json['required'] == true;
    final packages = _readPackages(json['apks']);

    if (versionName.isEmpty ||
        buildNumber <= 0 ||
        universalApk.url.isEmpty ||
        universalApk.androidVersionCode <= 0) {
      throw const FormatException('Invalid update manifest.');
    }

    return AppUpdateInfo(
      channel: channel,
      versionName: versionName,
      buildNumber: buildNumber,
      universalApk: universalApk,
      releaseUrl: releaseUrl,
      required: required,
      notes: notes,
      packages: packages,
    );
  }

  bool hasInstallableUpdate({
    required int currentAndroidVersionCode,
    required List<String> supportedAbis,
  }) {
    final package = resolvePackage(supportedAbis);
    return package != null &&
        package.androidVersionCode > currentAndroidVersionCode;
  }

  AppUpdatePackage? resolvePackage(List<String> supportedAbis) {
    final normalizedAbis = supportedAbis
        .map((abi) => abi.trim())
        .where((abi) => abi.isNotEmpty);
    for (final abi in normalizedAbis) {
      for (final package in packages) {
        if (package.abi == abi) {
          return package;
        }
      }
    }
    return null;
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

  static AppUpdateUniversalApk _readUniversalApk(Object? value) {
    if (value is! Map<String, Object?>) {
      return const AppUpdateUniversalApk(url: '', androidVersionCode: 0);
    }
    return AppUpdateUniversalApk.fromJson(value);
  }

  static List<AppUpdatePackage> _readPackages(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map<String, Object?>>()
        .map(AppUpdatePackage.fromJson)
        .where(
          (package) =>
              package.abi.isNotEmpty &&
              package.url.isNotEmpty &&
              package.androidVersionCode > 0,
        )
        .toList(growable: false);
  }
}

class AppUpdateUniversalApk {
  const AppUpdateUniversalApk({
    required this.url,
    required this.androidVersionCode,
    this.sha256,
    this.size,
  });

  final String url;
  final int androidVersionCode;
  final String? sha256;
  final int? size;

  factory AppUpdateUniversalApk.fromJson(Map<String, Object?> json) {
    final url = _readString(json, 'url');
    final sha256 = _readOptionalString(json, 'sha256');
    final size = _readOptionalInt(json, 'size');
    final androidVersionCode = _readInt(json, 'androidVersionCode');

    return AppUpdateUniversalApk(
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

class AppUpdatePackage {
  const AppUpdatePackage({
    required this.abi,
    required this.url,
    required this.androidVersionCode,
    this.sha256,
    this.size,
  });

  final String abi;
  final String url;
  final int androidVersionCode;
  final String? sha256;
  final int? size;

  factory AppUpdatePackage.fromJson(Map<String, Object?> json) {
    final abi = _readString(json, 'abi');
    final url = _readString(json, 'url');
    final sha256 = _readOptionalString(json, 'sha256');
    final size = _readOptionalInt(json, 'size');
    final androidVersionCode = _readInt(json, 'androidVersionCode');

    return AppUpdatePackage(
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

class AppVersionInfo {
  const AppVersionInfo({required this.versionName, required this.buildNumber});

  final String versionName;
  final int buildNumber;

  String get displayName => '$versionName+$buildNumber';
}

class AppUpdateDownloadProgress {
  const AppUpdateDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return receivedBytes / total;
  }
}
