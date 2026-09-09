@echo off
chcp 65001 > nul
echo ===================================================
echo   بناء تطبيق مدير الصيدلية المحمول PharmaOS Owner APK
echo ===================================================
echo.

cd /d "%~dp0"

echo 1. جلب الاعتماديات والحزم...
call flutter pub get

echo 2. بناء ملف الـ APK النهائي (Release)...
call flutter build apk --release

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    echo ✅ تم بناء تطبيق الأندرويد بنجاح!
    if not exist "..\..\releases" mkdir "..\..\releases"
    copy /y "build\app\outputs\flutter-apk\app-release.apk" "..\..\releases\PharmaOS_Owner.apk"
    if exist "C:\Users\hp\Desktop\PharmaOS_Release" (
        copy /y "build\app\outputs\flutter-apk\app-release.apk" "C:\Users\hp\Desktop\PharmaOS_Release\تطبيق_المدير_PharmaOS_Owner.apk"
    )
    echo 📱 المسار النهائي للملف: releases\PharmaOS_Owner.apk
) else (
    echo.
    echo ⚠️ حدث خطأ أثناء بناء ملف الـ APK. يرجى مراجعة سجل الأخطاء.
)

pause
