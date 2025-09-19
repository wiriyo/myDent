# Flutter wrapper classes that must be kept intact for reflection.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
-keep class io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }

# Preserve the entry point that is referenced from AndroidManifest.xml.
-keep class com.example.mydent_app.MainActivity { *; }

# Allow third-party libraries packaged with keep rules to suppress warnings.
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugin.**
