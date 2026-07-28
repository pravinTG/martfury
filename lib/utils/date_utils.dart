class DateUtilsHelper {
  static String formatToIST(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      DateTime dt;
      if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains(RegExp(r'-\d\d:\d\d'))) {
        dt = DateTime.parse('${dateStr}Z');
      } else {
        dt = DateTime.parse(dateStr);
      }
      
      final istOffset = const Duration(hours: 5, minutes: 30);
      final istDate = dt.toUtc().add(istOffset);
      
      final day = istDate.day.toString().padLeft(2, '0');
      final month = istDate.month.toString().padLeft(2, '0');
      final year = istDate.year;
      
      int hour = istDate.hour;
      final minute = istDate.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      final hourStr = hour.toString().padLeft(2, '0');
      
      return '$day-$month-$year $hourStr:$minute $amPm ';
    } catch (e) {
      return dateStr;
    }
  }
}
