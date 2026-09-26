# The AdMob SDK starts WorkManager, whose Room database classes are created
# by reflection. Without these rules R8 removed WorkDatabase_Impl and the
# app crashed on launch ("Failed to create an instance of WorkDatabase").
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.** { *; }
-keep class androidx.startup.** { *; }
