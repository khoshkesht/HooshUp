# ساخت و نصب APK روی گوشی

گوشی را با USB یا ADB بی‌سیم وصل کنید و مطمئن شوید در خروجی `adb devices` وضعیت آن `device` است. سپس از ریشهٔ مخزن اجرا کنید:

```powershell
& .\docs\build-and-install-android.ps1
```

اگر APK ساخته شده و فقط مرحلهٔ ADB خطا داده است، بدون ساخت دوباره ادامه دهید:

```powershell
& .\docs\build-and-install-android.ps1 -SkipBuild
```

اگر بیش از یک دستگاه وصل است، شناسهٔ دستگاه را مشخص کنید:

```powershell
& .\docs\build-and-install-android.ps1 -Serial 'DEVICE_SERIAL'
```

اسکریپت با پریست `Android` خروجی دیباگ را در `SourceProject/HooshUp-debug-install.apk` می‌سازد. پس از ساخت موفق، بستهٔ `com.example.hooshup` را در دستگاه انتخاب‌شده حذف و APK تازه را نصب می‌کند. حذف برنامه، داده‌های ذخیره‌شدهٔ آن روی دستگاه را نیز پاک می‌کند.

اگر شناسهٔ بسته در تنظیمات خروجی تغییر کرد، مقدار `$packageName` را در اسکریپت به‌روز کنید. برای اتصال بی‌سیم، مراحل [راهنمای ADB](android-wireless-debugging.md) را دنبال کنید.

برای تشخیص نسخهٔ نصب‌شده از `pm list packages` و تطبیق دقیق نام بسته استفاده می‌شود. نبودن برنامه طبیعی است و نباید نصب اولیه را متوقف کند؛ `pm path` در این وضعیت می‌تواند کد خروج ۱ بدهد. خطای واقعی ADB همچنان نصب را متوقف می‌کند.
