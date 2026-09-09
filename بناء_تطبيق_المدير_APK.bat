@echo off
chcp 65001 > nul
echo ===================================================
echo   بناء تطبيق مدير الصيدلية المحمول PharmaOS Owner APK
echo ===================================================
echo.

cd /d "%~dp0mobile\pharmaos_owner_app"

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
    echo 📱 تم حفظ ملف الـ APK بنجاح في مجلد الإصدارات وعلى سطح المكتب!
) else (
    echo.
    echo ⚠️ حدث خطأ أثناء بناء ملف الـ APK.
)

pause
