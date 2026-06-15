# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep platform integration classes
-keep class com.example.billing_app.** { *; }

# Hive database optimization rules
-keep class hive.** { *; }
-dontwarn hive.**
