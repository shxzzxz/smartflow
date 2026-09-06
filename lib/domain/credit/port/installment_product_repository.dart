import '../entity/installment_product.dart';

abstract interface class InstallmentProductRepository {
  Future<List<InstallmentProduct>> list();
  Future<InstallmentProduct?> find(String id);
  Future<void> save(InstallmentProduct product);
  Future<bool> isUsed(String id);
  Future<void> delete(String id);
}
