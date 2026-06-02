import 'package:smartflow/core/id/id_generator.dart';

class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'id'});

  final String prefix;
  int _counter = 0;

  @override
  String newId() => '$prefix-${++_counter}';
}
