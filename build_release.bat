@echo off
REM ============================================================
REM  سكربت بناء نسخة الإنتاج النهائية - PharmaOS
REM  شغّله من داخل مجلد المشروع (بجانب pubspec.yaml) عبر النقر
REM  المزدوج، أو من Command Prompt.
REM ============================================================

echo.
echo === تنظيف أي بناء سابق ===
call flutter clean
if errorlevel 1 goto :error

echo.
echo === تحميل الحزم ===
call flutter pub get
if errorlevel 1 goto :error

echo.
echo === توليد الأكواد التلقائية (Drift / Riverpod) ===
call dart run build_runner build --delete-conflicting-outputs
if errorlevel 1 goto :error

echo.
echo === بناء نسخة Windows النهائية (مع تشويه الكود Obfuscation) ===
call flutter build windows --release --obfuscate --split-debug-info=build\debug_info
if errorlevel 1 goto :error

echo.
echo ============================================================
echo تم البناء بنجاح.
echo الملف التنفيذي وكل ما يحتاجه موجود في:
echo   build\windows\x64\runner\Release\
echo.
echo انسخ محتوى هذا المجلد بالكامل (وليس ملف exe وحده) إلى جهاز
echo الصيدلية - كل الملفات المجاورة (DLLs وغيرها) مطلوبة للتشغيل.
echo ============================================================
echo.
pause
goto :eof

:error
echo.
echo !! حدث خطأ أثناء البناء - راجع الرسالة أعلاه وانسخها لطلب المساعدة !!
echo.
pause
