# Flutter ve eklentiler kendi kurallarını getiriyor; burada yalnızca
# yansımayla (reflection) erişilen sınıflar korunur.
-keep class io.flutter.** { *; }
-keep class com.izban.izban_nereye_gider.** { *; }

# Flutter'ın ertelenmiş bileşen (deferred components) desteği Play Core'a
# başvuruyor ama biz o özelliği kullanmıyoruz ve kütüphane pakette yok.
# R8 eksik sınıfları hata sayıp derlemeyi düşürüyordu:
#   Missing class com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
