class InsuranceAttachment {
  const InsuranceAttachment({
    required this.id,
    required this.fileName,
    required this.storageKey,
    required this.mimeType,
    required this.createdAt,
  });

  final String id;
  final String fileName;
  final String storageKey;
  final String mimeType;
  final DateTime createdAt;

  void validate() {
    if (id.trim().isEmpty ||
        fileName.trim().isEmpty ||
        storageKey.trim().isEmpty ||
        mimeType.trim().isEmpty) {
      throw ArgumentError('Insurance attachment metadata is incomplete.');
    }
  }
}
