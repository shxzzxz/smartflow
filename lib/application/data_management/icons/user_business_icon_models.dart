enum UserBusinessIconType { account, category }

extension UserBusinessIconTypeValue on UserBusinessIconType {
  String get wireName => name;

  static UserBusinessIconType parse(String value) {
    return UserBusinessIconType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () =>
          throw FormatException('Unsupported user business icon type: $value'),
    );
  }
}

class UserBusinessIconRecord {
  const UserBusinessIconRecord({
    required this.type,
    required this.key,
    required this.label,
    required this.filePath,
    required this.createdAt,
  });

  static const groupId = 'my-icons';

  final UserBusinessIconType type;
  final String key;
  final String label;
  final String filePath;
  final DateTime createdAt;

  String get refId => 'user:${type.wireName}:$groupId:$key';
}

class UserBusinessIconEntry {
  const UserBusinessIconEntry({required this.icon, required this.usageCount});

  final UserBusinessIconRecord icon;
  final int usageCount;
}
