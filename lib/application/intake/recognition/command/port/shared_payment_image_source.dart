class SharedPaymentImage {
  const SharedPaymentImage({required this.id});

  final String id;
}

/// Registers before taking the startup image so warm shares cannot be missed.
abstract interface class SharedPaymentImageSource {
  Stream<SharedPaymentImage> get shares;

  Future<SharedPaymentImage?> takeInitialShare();
}
