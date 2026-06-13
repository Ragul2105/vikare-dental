import 'package:intl/intl.dart';

class IndiaTime {
  IndiaTime._();

  static const Duration offset = Duration(hours: 5, minutes: 30);

  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _datePart = DateFormat('yyyy-MM-dd');
  static final DateFormat _timePart = DateFormat('HH:mm:ss');
  static final RegExp _offsetPattern = RegExp(r'([+-]\d{2}:\d{2}|Z)$');

  static DateTime now() {
    final indiaNow = DateTime.now().toUtc().add(offset);
    return DateTime(
      indiaNow.year,
      indiaNow.month,
      indiaNow.day,
      indiaNow.hour,
      indiaNow.minute,
      indiaNow.second,
      indiaNow.millisecond,
      indiaNow.microsecond,
    );
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String apiDate(DateTime value) => _apiDate.format(dateOnly(value));

  static DateTime fromApiDateTime(String value) {
    final parsed = DateTime.parse(value);
    if (!_offsetPattern.hasMatch(value)) {
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
    }

    final indiaValue = parsed.toUtc().add(offset);
    return DateTime(
      indiaValue.year,
      indiaValue.month,
      indiaValue.day,
      indiaValue.hour,
      indiaValue.minute,
      indiaValue.second,
      indiaValue.millisecond,
      indiaValue.microsecond,
    );
  }

  static String toApiDateTime(DateTime value) {
    final wallClock = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
    return '${_datePart.format(wallClock)}T${_timePart.format(wallClock)}+05:30';
  }
}
