import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _fullDate = DateFormat('EEEE, d MMMM y');
  static final DateFormat _shortDate = DateFormat('d MMM y');
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _time = DateFormat('hh:mm a');
  static final DateFormat _dateTime = DateFormat('d MMM y, hh:mm a');

  static String fullDate(DateTime value) => _fullDate.format(value.toLocal());

  static String shortDate(DateTime value) => _shortDate.format(value.toLocal());

  static String apiDate(DateTime value) => _apiDate.format(value.toLocal());

  static String time(DateTime value) => _time.format(value.toLocal());

  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());
}
