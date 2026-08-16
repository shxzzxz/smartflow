// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 标签词表（按词表排序）。录入、筛选与统计展示共享同一份词表快照。

@ProviderFor(tagList)
final tagListProvider = TagListProvider._();

/// 标签词表（按词表排序）。录入、筛选与统计展示共享同一份词表快照。

final class TagListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TagView>>,
          List<TagView>,
          Stream<List<TagView>>
        >
    with $FutureModifier<List<TagView>>, $StreamProvider<List<TagView>> {
  /// 标签词表（按词表排序）。录入、筛选与统计展示共享同一份词表快照。
  TagListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagListHash();

  @$internal
  @override
  $StreamProviderElement<List<TagView>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TagView>> create(Ref ref) {
    return tagList(ref);
  }
}

String _$tagListHash() => r'7662c5aa9d086c9364913365351dc5487547896a';

/// 某笔交易当前携带的标签 ID。子交易返回所属顶层交易的标签。

@ProviderFor(transactionTagIds)
final transactionTagIdsProvider = TransactionTagIdsFamily._();

/// 某笔交易当前携带的标签 ID。子交易返回所属顶层交易的标签。

final class TransactionTagIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          Stream<Set<String>>
        >
    with $FutureModifier<Set<String>>, $StreamProvider<Set<String>> {
  /// 某笔交易当前携带的标签 ID。子交易返回所属顶层交易的标签。
  TransactionTagIdsProvider._({
    required TransactionTagIdsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transactionTagIdsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transactionTagIdsHash();

  @override
  String toString() {
    return r'transactionTagIdsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Set<String>> create(Ref ref) {
    final argument = this.argument as String;
    return transactionTagIds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionTagIdsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transactionTagIdsHash() => r'331dd2df517bcffa1ecabfc9df381e84561b4589';

/// 某笔交易当前携带的标签 ID。子交易返回所属顶层交易的标签。

final class TransactionTagIdsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Set<String>>, String> {
  TransactionTagIdsFamily._()
    : super(
        retry: null,
        name: r'transactionTagIdsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 某笔交易当前携带的标签 ID。子交易返回所属顶层交易的标签。

  TransactionTagIdsProvider call(String transactionId) =>
      TransactionTagIdsProvider._(argument: transactionId, from: this);

  @override
  String toString() => r'transactionTagIdsProvider';
}
