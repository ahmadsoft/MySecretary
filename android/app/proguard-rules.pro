# قواعد R8 لتطبيق سكرتيري.
# Flutter وأغلب الإضافات توفر قواعدها تلقائياً؛ هذه احتياطات للإضافات التي تُستدعى بالانعكاس أو في الخلفية.

# الإشعارات المجدولة والمنبه (flutter_local_notifications يحفظ الإشعارات المجدولة عبر Gson)
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# قراءة الرسائل في الخلفية (another_telephony)
-keep class com.shounakmulay.telephony.** { *; }

# مشغل صوت المنبه
-keep class xyz.luan.audioplayers.** { *; }

-dontwarn com.google.android.play.core.**
