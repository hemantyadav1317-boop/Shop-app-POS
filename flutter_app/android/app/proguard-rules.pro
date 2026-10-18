# Proguard rules for Flutter and plugins

# Keep Flutter Engine and framework
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep Pigeon platform channel classes
-keep class dev.flutter.pigeon.** { *; }
-dontwarn dev.flutter.pigeon.**

# Keep Shared Preferences plugin classes
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# Keep Kotlin coroutines if referenced
-keep class kotlin.coroutines.** { *; }
-dontwarn kotlin.coroutines.**

# Keep reflection signatures
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
