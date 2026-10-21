# وضعیت پیاده‌سازی بوتیک

آخرین بررسی: ۲۰۲۶/۱۰/۲۱ — شاخه `feat/local-boutique`، مبنای سند `implementation-spec-fa.md` و تغییر دامنه در `docs/implementation-plan.md`.

وضعیت زیر به کل قرارداد بسته اشاره دارد، نه تعداد فایل‌های نوشته‌شده. حالت `verified` فقط پس از ساخت موفق و آزمون‌های لازم استفاده می‌شود. کد ورود ثابت `22222` قفل محلی ساده است؛ ادعای احراز هویت سرور یا ضدکپی ندارد. فقط اپ بوتیک ساخته می‌شود.

| packageId | status | completedContracts | changedFiles | commandsRun | testResults | hardwareUsed | knownLimitations | nextPackage |
|---|---|---|---|---|---|---|---|---|
| 00 | blocked | شناسایی Flutter 3.44.1/Dart 3.12.1، Android SDK، Java 8 و JBR 21، Node 22.23.1، Docker 27.4.0؛ ثبت تصمیم دامنه | `docs/hardware-matrix.md`, `docs/dependency-lock.md`, `docs/implementation-plan.md` | `flutter doctor -v`, `adb devices`, `docker info`, `sdkmanager` | SDK 36 و NDK 28.2 موجود نیست؛ adb بدون دستگاه | Windows میزبان | سه دروازه دوربین/رندر/پروژکتور آزموده‌نشده؛ دریافت manifestهای SDK از این شبکه ناموفق است | 01 |
| 01 | implemented_unverified | مدل لباس و فیلدهای نوع‌دار، نرمال‌سازی فارسی، اعتبارسنجی مقادیر، codegen Drift | `apps/store_app/lib/domain/*`, `lib/data/app_database.*` | `dart run build_runner build`, `flutter test` | تست منطق پاس؛ APK هنوز ساخته نشده | میزبان Windows | JSON Schema و OpenAPI سرویس ابری خارج از محدوده نسخه محلی | 02 |
| 02 | implemented_unverified | پوسته Android، فونت Vazirmatn محلی، تم، مسیرها، `fa_IR` و RTL | `apps/store_app/lib/app/*`, `assets/fonts/*`, `android/*` | `flutter create`, `flutter analyze --no-pub`, `flutter test --no-pub` | تست widget روی ۳۶۰dp با مقیاس متن ۱٫۵ پاس؛ تحلیل‌گر بدون خطا | رندر تست Flutter | سخت‌افزار واقعی و پوشش کامل همه صفحه‌ها هنوز بررسی نشده | 06 |
| 03–05 | not_started | — | — | — | — | — | ادمین، backend، مجوز و OTP سرور به درخواست کارفرما حذف از این نسخه | 06 |
| 06 | implemented_unverified | ثبت نام بوتیک روی دستگاه؛ کد محلی ثابت با ارقام فارسی/عربی/لاتین؛ قفل دستی | `lib/presentation/login_screen.dart`, `lib/app/providers.dart` | `flutter test` | ورود غلط/درست در تست widget پاس | رندر تست Flutter | قفل محلی امنیت ضدکرک ندارد؛ آزمون نصب روی دستگاه باقی است | 07 |
| 07 | implemented_unverified | SQLite، CRUD لباس، revision conflict، جست‌وجو، آرشیو، قیمت و موجودی، ذخیره فایل تصویر خصوصی | `lib/data/*`, `lib/presentation/dashboard_screen.dart`, `garment_detail_screen.dart` | `flutter test` | بازگشایی دیتابیس و رد نوشتن قدیمی پاس | Windows SQLite native | بازگشت از crash میانی ذخیره تصویر و پاک‌سازی orphan هنوز آزموده‌نشده؛ backup/export ندارد | 08 |
| 08 | in_progress | چهار جایگاه عکس واقعی لباس از گالری، کنترل نوع/ابعاد و پاک‌کردن EXIF؛ اندازه دستی؛ اصلاح ذخیره هم‌زمان و خروج بدون ذخیره | `lib/data/local_asset_store.dart`, `lib/presentation/garment_editor_screen.dart`, `test/editor_hardening_test.dart` | `flutter test --no-pub` | import و رد فایل نامعتبر؛ آزمون‌های ذخیره، خروج و تغییر حین نوشتن پاس | عکس fixture و رندر تست Flutter | دوربین CameraX، سنجش blur/نور/marker/اندازه خودکار و آزمون گوشی انجام نشده | 09 |
| 09 | in_progress | تعریف محلی فیلد سفارشی نوع‌دار و غیرفعال‌سازی بدون حذف مقدار قدیمی؛ جلوگیری از کرش تاریخ خارج از بازه | `lib/domain/field_definition.dart`, `lib/presentation/dynamic_field.dart`, `settings_screen.dart`, `test/editor_hardening_test.dart` | `flutter test --no-pub` | اعتبارسنجی چند نوع، حفظ مقدار پس از disable و تاریخ نامعتبر پاس | تست Flutter | schema version/migration، همه فیلدهای پایه و فرم گروهی سند هنوز پیاده نشده | 10 |
| 10 | blocked | خطای صریح «سرویس متصل نیست»؛ هیچ HTTP/کلید/خروجی جعلی | `lib/application/processing_service.dart` | `flutter test` | رد درخواست بدون نتیجه ساختگی پاس | — | اتصال AI طبق درخواست کارفرما معوق است | 11 |
| 11–13 | blocked | مرور دستی کاتالوگ مشتری جدا از پرو زنده | `lib/presentation/customer_screen.dart` | `flutter test` | فقط منطق UI محدود بررسی شده | دستگاه ندارد | CameraX/MediaPipe/OpenGL/ژست/پروژکتور و کیفیت پرو زنده ساخته یا آزموده نشده‌اند | 14 |
| 14 | blocked | suite تست، بازبینی کد و ساخت bundle دیباگ | `apps/store_app/test/*`, `lib/presentation/garment_editor_screen.dart`, `dynamic_field.dart` | `flutter analyze --no-pub`, `flutter test --no-pub`, `flutter build bundle --debug --no-pub`, `flutter build apk --debug --no-pub` | ۱۸ تست پاس؛ تحلیل‌گر بدون ایراد؛ Flutter bundle ساخته شد؛ APK ساخته نشد | Windows | Gradle برای پروژه `:jni` نیازمند NDK 28.2 است؛ افزونه‌های Android SDK 36 می‌خواهند؛ دسترسی مخازن SDK محدود و دستگاه متصل نیست؛ APK انتشار و soak test انجام نشده | — |

## محدودیت‌های کلیدی و قرارداد تغییرکرده

- مجوز سروری، OTP، پنل ادمین و backend این نسخه کنار گذاشته شدند و ثبت بوتیک محلی با کد `22222` جای آن‌ها را گرفت.
- عکس‌ها و اطلاعات لباس خصوصی دستگاه هستند؛ حذف داده اپ یا حذف نصب، آن‌ها را از بین می‌برد. سرویس بک‌آپ وجود ندارد.
- دکمه تحلیل خطای قابل‌فهم نشان می‌دهد. هیچ مدل AI، ماسک، asset پرو یا نتیجه آماده‌نمایی نمی‌شود.
- مرور دستی کاتالوگ مشتری پرو مجازی نیست؛ تصویر مشتری نه ثبت و نه ذخیره می‌شود.
- بازبینی کد چهار ایراد در ویرایشگر پیدا کرد و Sol آن‌ها را همراه آزمون‌های رگرسیون اصلاح کرد. آخرین اجرای تست: ۱۸ پاس؛ `flutter analyze --no-pub`: بدون ایراد.
- `flutter build bundle --debug --no-pub` موفق بود. این خروجی APK نصب‌شدنی نیست. ساخت APK ابتدا با نصب ناقص NDK 27 و سپس با محدودیت مخزن Maven روبه‌رو شد؛ پس از تنظیم مخزن داخلی، پیکربندی در `:jni` به علت نبود NDK 28.2 متوقف شد. SDK 36 نیز نصب نیست و `adb devices` دستگاهی نشان نداد. تا نصب ابزارها و آزمون روی گوشی، اپ «آماده نصب/انتشار» نیست.
