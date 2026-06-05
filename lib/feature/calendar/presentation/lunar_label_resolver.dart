import 'package:lunar/lunar.dart';

abstract interface class CalendarLunarLabelResolver {
  CalendarLunarLabel labelFor(DateTime date);
}

class CalendarLunarLabel {
  const CalendarLunarLabel({required this.text, this.marker});

  final String text;
  final String? marker;
}

class DefaultCalendarLunarLabelResolver implements CalendarLunarLabelResolver {
  const DefaultCalendarLunarLabelResolver();

  @override
  CalendarLunarLabel labelFor(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final lunar = Lunar.fromDate(normalized);
    final solar = Solar.fromDate(normalized);
    final holiday = HolidayUtil.getHolidayByYmd(
      normalized.year,
      normalized.month,
      normalized.day,
    );

    final holidayTarget = holiday?.getTarget();
    final holidayIsOnDate =
        holidayTarget != null && holidayTarget == _formatDate(normalized);

    final marker = holiday != null && holiday.isWork() ? '班' : null;

    final lunarFestival = _firstNonEmpty(lunar.getFestivals());
    if (lunarFestival != null) {
      return CalendarLunarLabel(text: lunarFestival, marker: marker);
    }

    final solarFestival = _firstNonEmpty(solar.getFestivals());
    if (solarFestival != null) {
      return CalendarLunarLabel(text: solarFestival, marker: marker);
    }

    if (holiday != null && holidayIsOnDate) {
      return CalendarLunarLabel(text: holiday.getName(), marker: marker);
    }

    final jieQi = lunar.getJieQi().trim();
    if (jieQi.isNotEmpty) {
      return CalendarLunarLabel(text: jieQi, marker: marker);
    }

    final lunarDay = lunar.getDayInChinese();
    if (lunarDay == '初一') {
      return CalendarLunarLabel(
        text: '${lunar.getMonthInChinese()}月',
        marker: marker,
      );
    }
    return CalendarLunarLabel(text: lunarDay, marker: marker);
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String? _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}
