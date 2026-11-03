import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_detail_presentation.dart';

class DetailAdvance {
  const DetailAdvance({
    required this.summaryText,
    required this.hasActivity,
    required this.isClosed,
    required this.items,
    this.outstanding,
  });

  final String summaryText;
  final bool hasActivity;
  final bool isClosed;
  final List<DetailSheetItem> items;
  final Money? outstanding;
}

sealed class DetailBusinessModule {
  const DetailBusinessModule();

  factory DetailBusinessModule.link({
    required String key,
    required String title,
    required String summary,
    String? route,
  }) = DetailBusinessLinkModule;

  String get key;
  String get title;
  String get summary;
  String? get route;
}

final class DetailBusinessLinkModule extends DetailBusinessModule {
  const DetailBusinessLinkModule({
    required this.key,
    required this.title,
    required this.summary,
    this.route,
  });

  @override
  final String key;
  @override
  final String title;
  @override
  final String summary;
  @override
  final String? route;
}

class TransactionDetailBusinessContent {
  const TransactionDetailBusinessContent({
    this.advance,
    this.modules = const [],
  });

  final DetailAdvance? advance;
  final List<DetailBusinessModule> modules;
}
