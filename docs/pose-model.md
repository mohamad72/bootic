# مدل محلی تشخیص بدن

`apps/store_app/android/app/src/main/assets/pose_landmarker_lite.task` مدل Pose Landmarker Lite با دقت float16 است. فایل از [نشانی رسمی مدل MediaPipe](https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task) دریافت شد. راهنمای استفادهٔ Android در [مستندات MediaPipe](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker/android) است.

- اندازه: ۵٬۷۷۷٬۷۴۶ بایت
- SHA-256: `59929E1D1EE95287735DDD833B19CF4AC46D29BC7AFDDBBF6753C459690D574A`
- اجرا: فقط روی دستگاه، با delegate پردازندهٔ مرکزی؛ تصویر مشتری ارسال یا ذخیره نمی‌شود.

وجود فایل و هش آن بررسی شده است. اجرای مدل در اپ هنوز به‌دلیل نبود NDK لازم کامپایل و روی دستگاه آزمایش نشده است.

برای رأی بدون لمس، فایل `gesture_recognizer.task` کنار مدل بالا قرار دارد. [مستندات Android تشخیص ژست MediaPipe](https://developers.google.com/edge/mediapipe/solutions/vision/gesture_recognizer/android) برچسب‌های `Thumb_Up` و `Thumb_Down` را تعریف می‌کند. دریافت مستقیم از مخزن مدل گوگل در شبکهٔ این میزبان با خطای محدودیت مکانی مواجه شد؛ کپی فایل از [آینهٔ عمومی Hugging Face](https://huggingface.co/spaces/pollen-robotics/reachy_mini_greetings/blob/8642c979e24dcac00d3818d37b9a5c2604dd774a/reachy_mini_greetings/model/gesture_recognizer.task) گرفته شد.

- اندازه: ۸٬۳۷۳٬۴۴۰ بایت
- SHA-256: `97952348CF6A6A4915C2EA1496B4B37EBABC50CBBF80571435643C455F2B0482`
- فقط برچسب تشخیص‌داده‌شده به Flutter منتقل می‌شود؛ فریم مشتری محلی و گذرا است.

هش فایل با مقدار منتشرشدهٔ آینه برابر است. سازگاری و دقت آن روی گوشی هنوز بررسی نشده است.
