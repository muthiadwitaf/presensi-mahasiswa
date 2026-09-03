# tflite_flutter mereferensikan GPU delegate TensorFlow Lite secara opsional
# (kelas dari artefak terpisah org.tensorflow:tensorflow-lite-gpu yang
# sengaja tidak kita include karena app ini cuma jalankan inferensi CPU,
# 4 thread, sesuai spesifikasi proposal). R8 tetap menyorot referensi itu
# saat minify - aman untuk diabaikan karena jalur kode itu tidak dipakai.
-dontwarn org.tensorflow.lite.gpu.**
-keep class org.tensorflow.lite.** { *; }

# ML Kit face detection - hindari R8 menghapus kelas model yang diakses via
# reflection oleh Google Play Services.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
