# Giữ lại các class của Flutter Video Player và ExoPlayer
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

# Ngăn R8 xóa các phương thức quan trọng
-keepattributes Signature
-keepattributes Exceptions
-keepattributes *Annotation*

# Nếu có dùng thư viện webview hoặc url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }