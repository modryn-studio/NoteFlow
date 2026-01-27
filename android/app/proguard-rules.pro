# NoteFlow ProGuard Rules
# Prevents code shrinking from breaking the app in release builds

# Keep Supabase classes
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }

# Keep models (adjust package name if different)
-keep class com.modrynnstudio.noteflow.models.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exception

# Keep serialization annotations
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Speech to text
-keep class com.google.android.gms.** { *; }

# Play Core (fixes R8 missing classes error)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# General Flutter recommendations
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
