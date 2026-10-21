/// 对手方词表读模型。
class CounterpartyView {
  const CounterpartyView({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is CounterpartyView && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
