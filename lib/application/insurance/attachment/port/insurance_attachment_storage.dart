class InsuranceAttachmentDraft {
  const InsuranceAttachmentDraft({
    required this.fileName,
    required this.storageKey,
    required this.mimeType,
  });

  final String fileName;
  final String storageKey;
  final String mimeType;
}

abstract interface class InsuranceAttachmentStorage {
  Future<List<InsuranceAttachmentDraft>> pickAndStore({
    required String commercialInsuranceId,
  });

  Future<void> open(String storageKey);
  Future<void> delete(String storageKey);
}
