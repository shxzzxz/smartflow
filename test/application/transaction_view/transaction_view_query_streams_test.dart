import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_streams.dart';

void main() {
  test('combineLatestStreams waits for every stream', () async {
    final first = StreamController<int>();
    final second = StreamController<String>();
    final events = <(int, String)>[];
    final subscription = combineLatestStreams<Object?>([
      first.stream,
      second.stream,
    ]).listen((values) => events.add((values[0] as int, values[1] as String)));
    addTearDown(subscription.cancel);
    addTearDown(first.close);
    addTearDown(second.close);

    first.add(1);
    await pumpEventQueue();
    expect(events, isEmpty);

    second.add('a');
    await pumpEventQueue();
    expect(events, [(1, 'a')]);

    first.add(2);
    await pumpEventQueue();
    expect(events, [(1, 'a'), (2, 'a')]);
  });

  test('switchMapStreams cancels the previous inner subscription', () async {
    final source = StreamController<int>.broadcast();
    final firstInner = StreamController<int>.broadcast();
    final secondInner = StreamController<int>.broadcast();
    final events = <int>[];
    final subscription = switchMapStreams(source.stream, (value) {
      return value == 1 ? firstInner.stream : secondInner.stream;
    }).listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(source.close);
    addTearDown(firstInner.close);
    addTearDown(secondInner.close);

    source.add(1);
    await pumpEventQueue();
    firstInner.add(10);
    await pumpEventQueue();

    source.add(2);
    await pumpEventQueue();
    firstInner.add(11);
    secondInner.add(20);
    await pumpEventQueue();

    expect(events, [10, 20]);
  });

  test('switchMapStreams forwards synchronous replacement values', () async {
    final source = StreamController<int>.broadcast();
    final events = <int>[];
    final subscription = switchMapStreams(
      source.stream,
      (value) => Stream.value(value * 10),
    ).listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(source.close);

    source.add(1);
    source.add(2);
    await pumpEventQueue();

    expect(events, [10, 20]);
  });
}
