# نصب و دیباگ بی‌سیم Android

## دستگاه آزمایشی فعلی

- مدل: `SM-T295`
- شناسهٔ ADB: `R9WN90HRHWJ`
- نشانی اتصال بی‌سیم فعلی: `192.168.1.180:45187`
- نام بسته: `com.example.hooshup`
- APK دیباگ: `SourceProject/HooshUp.apk`

## اتصال دوباره

1. رایانه و تبلت را به یک Wi-Fi مشترک وصل کنید و در تبلت، **Wireless debugging** را روشن کنید.
2. در تبلت، **Pair device with pairing code** را باز کنید. آدرس `IP:port` و کد شش‌رقمی فقط برای همان نوبت معتبرند؛ آن‌ها را ثبت نکنید.
3. با ADB داخل Android SDK جفت‌سازی کنید:

   ```powershell
   & 'C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe' pair 'IP:PAIRING_PORT' 'PAIRING_CODE'
   ```

4. از صفحهٔ اصلی Wireless debugging، مقدار جداگانهٔ **IP address & Port** را بگیرید و وصل شوید:

   ```powershell
   & 'C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe' connect 'IP:CONNECT_PORT'
   & 'C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe' devices -l
   ```

5. وقتی وضعیت دستگاه `device` شد، APK را نصب کنید:

   ```powershell
   & 'C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe' install -r '.\SourceProject\HooshUp.apk'
   ```

## نکات رفع اشکال

- در این رایانه mDNS ممکن است دستگاه را کشف نکند؛ اتصال دستی با IP و پورت انجام شود.
- اگر Pairing خطا داد، Wireless debugging را یک‌بار خاموش/روشن کنید و کد و پورت تازه بگیرید؛ کدهای قبلی سریع منقضی می‌شوند.
- `adb devices -l` باید بعد از `connect` وضعیت `device` را نشان دهد.
- برای انتقال صرفِ APK، بدون ADB می‌توان از Quick Share یا LocalSend استفاده کرد.
