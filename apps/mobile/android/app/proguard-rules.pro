# R8 keep rules for the release build.
#
# Flutter's own engine rules come from the Flutter Gradle plugin. These cover
# the plugins we depend on that R8 can't see through (reflection, JNI, or
# classes referenced only from native/Dart side).

# Flutter engine + embedding.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase Cloud Messaging: the service is resolved from the manifest and
# message payloads are deserialised reflectively.
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Play Core is referenced by Flutter's deferred-components support, which we
# don't use — without this R8 fails on the missing classes.
-dontwarn com.google.android.play.core.**

# Keep annotations and generic signatures so reflective JSON handling and
# Kotlin metadata survive shrinking.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# OkHttp / Okio (transitively used by networking plugins) reference optional
# JVM-only classes that don't exist on Android.
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
