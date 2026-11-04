import '../../transaction_view_query_streams.dart';
import 'business_activity_query_service.dart';
import 'business_activity_read_models.dart';

/// Keeps the member stream responsible for discovery while refreshing content
/// for the currently selected activity page.
Stream<BusinessActivityPage> watchBusinessActivityContents(
  Stream<BusinessActivityPage> pages,
  BusinessActivityQueryService query,
) {
  return switchMapStreams(pages, (page) {
    if (page.items.isEmpty) return Stream.value(page);
    return query.watchContents(page.items).map((contents) {
      return BusinessActivityPage(
        hasMore: page.hasMore,
        items: [
          for (final item in page.items) contents[item.activityKey] ?? item,
        ],
      );
    });
  });
}
