# نسخه ابزار و وابستگی

انتخاب‌های اجرا در ۲۰۲۶/۱۰/۲۱:

- Flutter 3.44.1 و Dart 3.12.1.
- Android Gradle Plugin 9.0.1 و Kotlin 2.3.20 طبق اسکلت تولیدی Flutter؛ Gradle 9.1.0 در wrapper.
- Android minSdk 29؛ compileSdk فعلی مقدار Flutter SDK است که به API 36 نیاز دارد.
- `apps/store_app/pubspec.lock` نسخه دقیق تمام بسته‌های Dart را قفل می‌کند؛ `pubspec.yaml` قرارداد نسخه‌های مجاز است.
- SQLite از Drift و drift_flutter استفاده می‌کند؛ تولید `app_database.g.dart` با `dart run build_runner build` انجام شد.
- Vazirmatn Regular/Bold و مجوز OFL داخل `assets/fonts` بسته می‌شوند.
- Node و Docker در نسخه فقط‌محلی dependency محصول نیستند.

دستور بررسی تکرارپذیر از پوشه `apps/store_app`: `flutter pub get`, `dart run build_runner build`, `flutter analyze --no-pub`, `flutter test --no-pub`, `flutter build apk --debug --no-pub`.
