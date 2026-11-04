/// 普通账务交易形成的活动项使用交易身份。
const String ledgerTransactionActivityItemType = 'ledger.transaction';

/// 业务活动项的稳定身份。
///
/// 活动项由业务域提供自身稳定身份；没有额外业务身份的单项交易可以退化为
/// [BusinessActivityItemKey.transaction]。
final class BusinessActivityItemKey {
  const BusinessActivityItemKey({required this.type, required this.id})
    : assert(type != ''),
      assert(id != '');

  const BusinessActivityItemKey.transaction(String id)
    : this(type: ledgerTransactionActivityItemType, id: id);

  final String type;
  final String id;

  @override
  bool operator ==(Object other) {
    return other is BusinessActivityItemKey &&
        other.type == type &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}
