// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'counterparty_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 对手方词表（按名称排序）。录入交易时与标签词表并行使用。

@ProviderFor(counterpartyList)
final counterpartyListProvider = CounterpartyListProvider._();

/// 对手方词表（按名称排序）。录入交易时与标签词表并行使用。

final class CounterpartyListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<CounterpartyView>>,
          List<CounterpartyView>,
          Stream<List<CounterpartyView>>
        >
    with
        $FutureModifier<List<CounterpartyView>>,
        $StreamProvider<List<CounterpartyView>> {
  /// 对手方词表（按名称排序）。录入交易时与标签词表并行使用。
  CounterpartyListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'counterpartyListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$counterpartyListHash();

  @$internal
  @override
  $StreamProviderElement<List<CounterpartyView>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<CounterpartyView>> create(Ref ref) {
    return counterpartyList(ref);
  }
}

String _$counterpartyListHash() => r'35c6d77920f73de9baa6046cfab9aefe60795a66';
