import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// 1. Ghi nhận đăng nhập thành công
  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
    print("📊 Analytics: Logged Login ($method)");
  }

  /// 2. Ghi nhận đăng ký thành công
  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
    print("📊 Analytics: Logged SignUp ($method)");
  }

  /// 3. Ghi nhận hành động cụ thể (Ví dụ: Chấm công, Tạo request)
  static Future<void> logEvent(String name, Map<String, Object>? params) async {
    await _analytics.logEvent(name: name, parameters: params);
    print("📊 Analytics: Logged Event ($name) - Params: $params");
  }

  /// 4. Đặt User ID (Để biết ai đang thực hiện hành động)
  static Future<void> setUserId(String id) async {
    await _analytics.setUserId(id: id);
    print("📊 Analytics: Set UserID ($id)");
  }
}
