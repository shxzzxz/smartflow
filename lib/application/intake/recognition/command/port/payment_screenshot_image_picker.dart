/// Selects one image and returns an ephemeral recognition handle.
/// A dismissed picker returns null and does not start recognition.
abstract interface class PaymentScreenshotImagePicker {
  Future<String?> pickImage();
}
