# ماتریس سخت‌افزار و ابزار

تاریخ بررسی: ۲۰۲۶/۱۰/۲۱. میزبان Windows 10 Enterprise LTSC 64-bit. گوشی Android یا نمایشگر خارجی به `adb` متصل نبود.

| ابزار یا دروازه | یافته واقعی | نتیجه |
|---|---|---|
| Flutter/Dart | Flutter stable 3.44.1، Dart 3.12.1 | نصب‌شده؛ `flutter doctor -v` اجرا شد |
| Android SDK | `C:/Users/m.maghsoodi/AppData/Local/Android/Sdk`، platformها تا API 35؛ SDK 36 و Build Tools 28.0.3 مورد نیاز doctor | ناقص برای toolchain حاضر؛ نصب با sdkmanager به دریافت manifest نرسید |
| Java | PATH: Java 8؛ Android Studio JBR: Java 21.0.7 | ساخت Android با JBR 21 اجرا می‌شود |
| Node | v22.23.1 | نصب‌شده؛ در اپ محلی کاربرد اجرایی ندارد |
| Docker | client/server 27.4.0 | daemon بیرون sandbox پاسخ داد؛ اپ محلی نیازی به کانتینر ندارد |
| adb | daemon اجرا شد، فهرست دستگاه‌ها خالی بود | آزمون دوربین و نصب APK ممکن نشد |
| دوربین/USB-C/پروژکتور | هیچ دستگاه یا خروجی خارجی متصل نبود | سه دروازه سند «آزموده‌نشده» |
| مدل segmentation/pose | provider و مدل انتخاب نشده‌اند | کیفیت رندر و ژست قابل ادعا نیست |

تلاش `sdkmanager` ابتدا خطای گواهی Java داشت. پس از ساخت truststore محلی از ریشه‌ای که خود Windows برای شبکه سازمانی معتبر می‌داند، manifestهای SDK همچنان دریافت نشدند. هیچ کنترل TLS سراسری خاموش نشد.
