abstract interface class UpdateChannelStore {
  Future<String?> readUpdateChannel();

  Future<void> saveUpdateChannel(String code);
}
