# ML Kit — prevent R8 from stripping these classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Hive
-keep class * extends com.google.flatbuffers.Table { *; }
-keepclassmembers class * {
    @com.google.flatbuffers.Table *;
}

# Supabase / Ktor
-dontwarn org.slf4j.**
-dontwarn okhttp3.**

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }
