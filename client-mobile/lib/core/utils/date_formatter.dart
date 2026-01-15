import 'package:timeago/timeago.dart' as timeago;

class DateFormatter {
  static String toTimeAgo(String isoString) {
    if (isoString.isEmpty) return "";
    try {
      // 1. Parse chuỗi ISO từ Server thành DateTime
      final date = DateTime.parse(isoString);

      // 2. Chuyển đổi sang dạng "time ago"
      // 'en' = tiếng Anh (5 minutes ago)
      // 'vi' = tiếng Việt (5 phút trước) - Cần đăng ký locale nếu dùng tiếng Việt
      return timeago.format(date, locale: 'en');
    } catch (e) {
      return isoString; // Nếu lỗi thì hiện nguyên gốc
    }
  }
}
