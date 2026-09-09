# دليل البناء (Build) - PharmaOS

الأوامر الأساسية:
flutter pub get
flutter packages pub run build_runner build --delete-conflicting-outputs
flutter build windows --release --obfuscate --split-debug-info=build/debug_info

الناتج النهائي: ملف .exe قابل للتثبيت المباشر على أجهزة الصيدليات دون الحاجة لأي بيئة تطوير.
