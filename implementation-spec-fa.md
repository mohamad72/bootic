# سند اجرایی آینه پرو مجازی فروشگاهی

نسخه سند: ۱٫۰ — تاریخ: ۲۰۲۶/۱۰/۱۵ — مخاطب: توسعه‌دهنده و مدل کدنویسی سبک‌تر

این سند قرارداد پیشنهادی پیاده‌سازی کل محصول است؛ ادعای ساخته‌شدن، آزمایش سخت‌افزاری یا تضمین کیفیت پرو ندارد. مشخصات ۱۴۱‌بندی کارفرما مبناست. تصمیم‌های تکمیلی این سند، پیش‌فرض اجرایی‌اند. موارد وابسته به دستگاه یا مدل بینایی با دروازه آزمون مشخص شده‌اند. زبان همه رابط‌ها فارسی است؛ نام کد، مسیر، enum و قرارداد شبکه انگلیسی می‌ماند.

## ۱. حدود محصول و تصمیم‌های قطعی پیشنهادی

محصول سه جزء قابل استقرار دارد: اپ فروشگاهی Android، اپ مدیریتی Android و بک‌اند. یک پلاگین محلی Kotlin پردازش زنده، دوربین، کلید دستگاه و نمایشگر را ارائه می‌کند. اپ مدیریتی هیچ کلید امضای سرور یا راز تولید OTP ندارد؛ فقط فرمان مجاز به سرور می‌فرستد.

| موضوع | تصمیم اجرایی |
|---|---|
| رابط اپ‌ها | Flutter؛ فقط `fa_IR`، راست‌به‌چپ، فونت محلی Vazirmatn |
| مدیریت وضعیت و تزریق وابستگی | Riverpod؛ بدون ترکیب Bloc/GetX/Service Locator دیگر |
| مسیریابی | go_router؛ نگهبان مسیر لازم است اما مرز امنیتی به‌تنهایی نیست |
| داده محلی | Drift/SQLite؛ فایل تصویر بیرون DB در فضای خصوصی اپ |
| شبکه | Dio؛ DTOهای تولیدشده از OpenAPI، خطای دامنه مستقل |
| مدل‌های Dart | immutable؛ Freezed و json_serializable برای داده، نه برای هر کلاس سرویس |
| ارتباط بومی | Pigeon برای فرمان/پاسخ تایپ‌شده؛ کانال رویداد برای داده کم‌حجم |
| دوربین | CameraX با مالکیت انحصاری پلاگین؛ اپ Flutter دوربین دوم باز نکند |
| پردازش زنده | MediaPipe Tasks و OpenGL ES؛ بدون عبور فریم خام از Dart |
| بک‌اند | NestJS/TypeScript، PostgreSQL، Prisma، Redis/BullMQ |
| پردازش سنگین تصاویر | worker پایتون مستقل؛ قرارداد JSON و فایل، بدون دسترسی مستقیم به DB اصلی |
| ذخیره ابری | فضای خصوصی سازگار با S3؛ URL امضاشده کوتاه‌عمر |
| صف کارها | بک‌اند مالک صف؛ worker پل پردازش؛ وضعیت job در PostgreSQL |
| معماری استقرار | modular monolith به‌همراه worker؛ فعلاً microserviceهای متعدد نسازید |
| مقدار پول | عدد صحیح تومان؛ `currency=IRR`, `unit=TOMAN` برای رفع ابهام؛ بدون float |
| زمان | UTC در داده؛ Asia/Tehran و تقویم شمسی در نمایش؛ امنیت مستقل از تقویم UI |
| اندروید هدف اولیه | حداقل API 29 به‌عنوان تصمیم محصول؛ target/compile بر اساس SDK معتبر زمان ساخت |
| نسخه وابستگی‌ها | انتخاب مجموعه سازگار در مرحله صفر و قفل دقیق؛ این سند شماره «آخرین نسخه» حدس نمی‌زند |
| انتشار اولیه | APK امضاشده با کلید انتشار ثابت؛ بسته و کلید بین آپدیت‌ها تغییر نکند |

سه رویکرد ممکن بود: اجرای همه‌چیز در Flutter ساده‌تر اما برای مسیر زنده محدودکننده است؛ اجرای کامل Kotlin کنترل بیشتری ولی توسعه رابط دو اپ پرهزینه‌تر دارد؛ روش ترکیبی انتخاب این سند است. برای تیم کوچک، یک بک‌اند ماژولار از چندین سرویس شبکه‌ای قابل نگهداری‌تر است.

### مرز نسخه اولیه

ثبت و تحلیل متادیتا برای پنج خانواده بالاتنه، کت، پیراهن، شلوار و دامن پشتیبانی شود. پرو زنده قابل انتشار ابتدا فقط برای **بالاتنه روبه‌رو** است؛ لباس خانواده دیگر در فهرست متصدی قابل ثبت است ولی تا تأیید پروفایل رندر آن، `tryOnEligible=false` دارد. این کاهش دامنه پیشنهادی برای قابل‌تحویل بودن نسخه اول است؛ مدل حق ندارد برای همه خانواده‌ها کیفیت پرو را بدون آزمون یکسان اعلام کند.

چهار عکس همچنان گرفته می‌شود. در نسخه اول فقط عکس جلو برای پرو زنده استفاده می‌شود؛ پشت و زاویه‌ها برای تحلیل و توسعه آینده‌اند. تولید mesh، depth map و تغییر واقعی پشت/جلو در نسخه اول اجرا نمی‌شود. نمایش دوبعدی جای اندازه‌گیری سایز، تضمین اندازه‌بودن یا شبیه‌سازی فیزیکی پارچه نیست. جمله فارسی «نمایش تقریبی استایل؛ اندازه و تن‌خور واقعی را بررسی کنید» در شروع تجربه و راهنمای متصدی موجود باشد.

### اصلاح ادعاهای امنیتی

کلید غیرقابل خروج و لایسنس امضاشده جلوی کپی ساده را می‌گیرند؛ تضمین نمی‌کنند APK دست‌کاری‌شده روی دستگاه روت‌شده هرگز اجرا نشود. هیچ کلاینت کاملاً آفلاین تحت کنترل مهاجم، ضدکرک مطلق نیست. کنترل جدی سرویس‌های آنلاین در سرور و سخت‌سازی بومی مکمل‌اند. «دیتابیس قفل» در نسخه اول یعنی دسترسی تجاری به repositoryها و فایل‌ها مشروط به مجوز، و ذخیره خصوصی Android؛ به‌معنای رمزگذاری کامل SQLite نیست. اگر رمزگذاری کامل الزام قراردادی شد، SQLCipher باید جداگانه انتخاب و آزمون شود.

## ۲. قواعد مالکیت و وابستگی

مسیر وابستگی: presentation → application → domain. لایه data پیاده‌کننده interfaceهای domain است. بخش domain Flutter، Drift، Dio یا CameraX import نکند. اپ فروشگاه و ادمین یکدیگر را import نکنند. هر ویژگی مالک controller و سرویس کاربردی خود است؛ feature دیگر فقط API عمومی آن را مصرف کند. یک کلاس use-case برای هر CRUD ساده نسازید؛ هماهنگ‌کننده فقط برای جریان چندمرحله‌ای لازم است.

یک منبع حقیقت برای هر داده:

- لایسنس، محدودیت دستگاه، schema فروشگاه و تأیید ادمین: سرور.
- اطلاعات تأییدشده لباس در MVP: دیتابیس همان نصب؛ بک‌آپ اختیاری و غیرهمزمان. اشتراک همزمان موجودی بین دستگاه‌ها خارج از MVP است؛ دو گوشی یک فروشگاه فعلاً کاتالوگ مستقل دارند.
- پیش‌نویس و عکس‌های ثبت: محلی؛ پردازش ابری نتیجه پیشنهادی تولید می‌کند.
- جلسه مشتری، بردار سلیقه و ژست: حافظه؛ بدون ذخیره پایدار هویت/تصویر.
- پردازش دوربین، pose، ماسک و frame timestamp: Kotlin.
- انتخاب لباس بعدی و وضعیت جلسه: Dart؛ تصمیم هر انتخاب دارای شناسه و نسخه است.
- رندر و نمایشگر خارجی: Kotlin؛ فقط داده خلاصه وضعیت به Flutter برگردد.

## ۳. نقشه کامل پوشه‌ها

مسیرهای زیر فایل‌های دست‌نویس موردنیازند. فایل‌های تولیدشده ابزارها (`*.g.dart`، DTO تولیدی، Pigeon، Prisma client و scaffolding استاندارد Flutter/Android) ثبت تفصیلی کلاس در این سند ندارند و دستی ویرایش نمی‌شوند. هر کلاس اصلی در یک فایل هم‌نام قرار گیرد. فهرست کلاس‌های بخش‌های بعد، فهرست فایل‌های لازم داخل همین پوشه‌هاست؛ ایجاد پوشه خالی برای قابلیت‌های آینده لازم نیست.

```text
virtual_tryon/
  README.md
  .gitignore
  .env.example
  melos.yaml
  analysis_options.yaml
  package.json
  pnpm-lock.yaml
  docs/
    implementation-spec-fa.md
    dependency-lock.md
    hardware-matrix.md
    security-protocol.md
    operations.md
    implementation-status.md
    decisions/
  contracts/
    openapi.yaml
    schemas/
      garment-analysis-v1.schema.json
      field-definition-v1.schema.json
      asset-manifest-v1.schema.json
      processing-job-v1.schema.json
    fixtures/
      license-valid.json
      license-invalid.json
      garment-analysis.json
      custom-fields.json
      native-events.json
  apps/
    store_app/
      pubspec.yaml
      pubspec.lock
      lib/
        main.dart
        bootstrap.dart
        app/
          store_app.dart
          app_router.dart
          app_dependencies.dart
          app_lifecycle_coordinator.dart
        core/
          config/app_config.dart
          network/device_api_client.dart
          network/device_auth_interceptor.dart
          network/error_mapper.dart
          database/app_database.dart
          database/tables/
          database/daos/
          database/migrations/
          files/local_asset_store.dart
          files/temporary_file_cleaner.dart
          diagnostics/redacting_logger.dart
          diagnostics/diagnostics_service.dart
        features/
          activation/
            domain/
            application/
            data/
            presentation/
          operator_auth/
            domain/
            application/
            data/
            presentation/
          onboarding/
            application/
            data/
            presentation/
          capture/
            domain/
            application/
            data/
            presentation/
          catalog/
            domain/
            application/
            data/
            presentation/
          metadata/
            domain/
            application/
            data/
            presentation/
          processing/
            domain/
            application/
            data/
            presentation/
          customer/
            domain/
            application/
            data/
            presentation/
          projector/
            application/
            presentation/
          settings/
            application/
            data/
            presentation/
      assets/
        tutorials/
        illustrations/
      android/
        app/src/main/AndroidManifest.xml
        app/src/main/kotlin/<applicationId>/MainActivity.kt
        app/src/main/res/xml/backup_rules.xml
        app/src/main/res/xml/data_extraction_rules.xml
        app/src/main/res/xml/network_security_config.xml
      test/
        activation/
        metadata/
        catalog/
        customer/
        migrations/
        widgets/
      integration_test/
    admin_app/
      pubspec.yaml
      pubspec.lock
      lib/
        main.dart
        bootstrap.dart
        app/admin_app.dart
        app/admin_router.dart
        app/admin_dependencies.dart
        core/network/admin_api_client.dart
        core/network/admin_auth_interceptor.dart
        core/security/admin_token_store.dart
        features/
          auth/{application,data,presentation}/
          dashboard/{application,data,presentation}/
          activations/{application,data,presentation}/
          devices/{application,data,presentation}/
          stores/{application,data,presentation}/
          licenses/{application,data,presentation}/
          audit/{application,data,presentation}/
          settings/{application,data,presentation}/
      android/
      test/
      integration_test/
  packages/
    domain_models/
      pubspec.yaml
      lib/domain_models.dart
      lib/src/{common,garment,metadata,activation,session,admin}/
      test/
    design_system/
      pubspec.yaml
      lib/design_system.dart
      lib/src/{theme,formatters,widgets,messages}/
      assets/fonts/
      assets/licenses/
      test/
    api_client/
      pubspec.yaml
      lib/api_client.dart
      lib/src/generated/
      lib/src/adapters/
    tryon_native/
      pubspec.yaml
      pigeons/tryon_api.dart
      lib/tryon_native.dart
      lib/src/{bridge,models,events}/
      android/build.gradle.kts
      android/src/main/AndroidManifest.xml
      android/src/main/kotlin/<namespace>/
        TryonNativePlugin.kt
        bridge/
        security/
        camera/
        capture/
        vision/
        rendering/
        display/
        diagnostics/
      android/src/main/assets/
        models/
        shaders/
      android/src/main/res/layout/
      android/src/main/res/font/
      android/src/test/
      android/src/androidTest/
  services/
    backend/
      package.json
      tsconfig.json
      nest-cli.json
      prisma/schema.prisma
      prisma/migrations/
      src/
        main.ts
        app.module.ts
        config/
        common/{auth,errors,validation,logging,idempotency,clock}/
        modules/
          admin-auth/
          stores/
          activations/
          devices/
          licenses/
          schemas/
          uploads/
          processing/
          audit/
          dashboard/
          settings/
          health/
      test/{unit,integration,contract}/
    vision_worker/
      pyproject.toml
      uv.lock
      src/vision_worker/
        main.py
        job_handler.py
        image_normalizer.py
        garment_segmenter.py
        anchor_extractor.py
        measurement_estimator.py
        asset_builder.py
        quality_evaluator.py
        object_store.py
        model_registry.py
      tests/
  infra/
    compose.dev.yaml
    docker/{backend.Dockerfile,worker.Dockerfile}
    reverse-proxy/
    migrations/
    backup/
    monitoring/
  scripts/
    generate-contracts.sh
    verify.sh
    seed-dev.ts
    package-release.sh
  .github/workflows/
    verify.yml
    release.yml
```

نکته مسیرها: عبارت `<namespace>` و `<applicationId>` فقط جای نام بسته انتخاب‌شده مالک است، نه متن واقعی پوشه. نام فروشگاه یا برند را در namespace سخت‌کد نکنید. آکولادها در درخت بالا، مجموعه زیرپوشه‌های هم‌سطح‌اند؛ پوشه‌ای با نام آکولاد ساخته نشود. کد native در پلاگین است؛ `MainActivity` فقط اتصال استاندارد lifecycle و Flutter را انجام می‌دهد.

## ۴. قرارداد عمومی کلاس‌ها و انواع

در جدول‌ها، `F<T>` یعنی `Future<Result<T>>` در Dart، `S<T>` یعنی `Stream<T>`، `P<T>` یعنی `Promise<T>` در TypeScript. متد خالص بدون این پیشوند synchronous است. در Kotlin عملیات IO به‌صورت `suspend` و خروجی `NativeResult<T>`؛ رویدادها `Flow<T>` هستند. `Result<T>` اجتماع بسته `Success<T>` و `Failure(AppFailure)` است. شکست‌های پیش‌بینی‌پذیر exception خام به UI ندهند.

تمام repositoryها در domain تعریف می‌شوند؛ پیاده‌سازی `...RepositoryImpl` در data، با همان متدها. mapperهای `...DtoMapper` متدهای `toDomain(dto)` و `toDto(entity)` دارند. controllerهای وضعیت، immutable state دارند؛ `build()`، `dispose()` و اتصال stream در framework انجام می‌شود. کلاس view فقط `build(context)` دارد؛ عملیات مهم UI به متد controller ارجاع داده می‌شود. getter، constructor، `copyWith`، equality و JSON serialization تولیدی عمداً جدا فهرست نشده‌اند.

| نوع پایه | فیلد/متد مهم |
|---|---|
| `AppFailure` | `code, messageKey, retryable, fieldErrors, correlationId`؛ بدون token و داده حساس |
| `Page<T>` / `PageQuery` | `items,nextCursor` / `cursor,limit,search,sort`؛ سقف ۱۰۰ |
| `Clock` | `utcNow(), monotonicNowMs()`؛ قابلیت clock جعلی برای آزمون |
| `Money` | `amountToman:int`؛ `validate(), formatFa()`؛ صفر مجاز، منفی ممنوع |
| `DateRange` / `NumberRange` | `min,max`؛ `validate()`؛ ترتیب الزامی |
| `Point2` / `Rect2` / `Matrix3` | مختصات و تبدیل؛ مختصات normalized در بازه ۰..۱ |
| `AssetRef` | `id,kind,sha256,mime,width,height,byteSize,revision`؛ مسیر محلی جزو domain ابری نیست |
| `OperationContext` | `operationId,installationId,storeId,correlationId`؛ از context معتبر ساخته شود |

## ۵. مدل‌های دامنه

### مدل لباس و متادیتا

| کلاس | فیلدهای اصلی و قواعد |
|---|---|
| `Garment` | `id,localRevision,name,sku?,barcode?,collection,category,metadata,schemaVersion,price,discountPrice?,stock,isActive,assets,measurements,anchors,renderProfile,processingStatus,createdAt,updatedAt` |
| `GarmentDraft` | `id,garmentId?,baseRevision,captureSet,metadataDraft,priceDraft,lastSavedAt,pendingJobId?`؛ crash نباید پیش‌نویس را پاک کند |
| `GarmentMetadata` | `values: Map<FieldKey,MetadataValue>`؛ یک منبع برای base و custom؛ getterهای typed برای رنگ و استایل |
| `MetadataValue` | `value:FieldValue,source,confidence?,reviewStatus,updatedAt,updatedBy?,jobId?,schemaVersion` |
| `FieldValue` | union: text, int, decimal, bool, singleOption, multiOption, date, year, yearRange, numberRange, color, score, tags, null |
| `FieldDefinition` | `id,key,labelFa,description,type,options,required,enabled,aiQuestion?,aiEnabled,recommendationRelevant,constraints,scope,version,archivedAt?` |
| `FieldOption` | `id,labelFa`؛ کلید پایدار، برچسب قابل ویرایش |
| `EffectiveSchema` | `storeId,version,fields,disabledBaseKeys,createdAt`؛ immutable snapshot |
| `SchemaChange` | union: add, renameLabel, disable, enable, updateOptions؛ تغییر نوع با migration صریح |
| `GarmentColor` | `nameFa,hexApproximation?,family,temperature?,brightness?` |
| `FashionTrend` | `era?,peakYears[],trendName?,status?,timelessness?,evidenceAsOf?,sourceRefs[]` |
| `TargetAudience` | `styleIds[],personasFa[]`؛ صرفاً سلیقه پوششی |
| `RecommendedAge` | `min?,max?,primaryRange?`؛ توصیه محصول، نه تشخیص سن مشتری |
| `StyleScores` | نگاشت شناسه ثابت استایل به نمره ۰..۱؛ بدون کلید دلخواه بی‌معنا |
| `GarmentMeasurements` | `entries:Map<MeasurementKey,MeasurementValue>` |
| `MeasurementValue` | `millimeters?,method,confidence?,calibrationId?,reviewedAt?`؛ unknown با صفر فرق دارد |
| `GarmentAnchors` | `assetRevision,points:Map<AnchorKey,Point2>,source,reviewed`؛ متعلق به تصویر نهایی پس از crop |
| `RenderProfile` | `supportedCategory,view=front,meshTemplateVersion,assetRevision,tryOnEligible,operatorApproved` |
| `GarmentVariant` | آینده: size/color/SKU مستقل؛ در MVP هر رکورد یک کالای مستقل و موجودی عددی دارد |

فیلدهای پایه schema: `category,subCategory,garmentType,primaryColor,secondaryColors,accentColors,colorFamily,pattern,material,texture,fit,styles,season,sleeveType,collarType,lengthClass,targetAudience,recommendedAge,occasions,fashionTrend,styleScores,iranSuitableOccasions`. فیلدهای گروهی با child schema ساخته شوند؛ renderer عمومی علاوه بر انواع ورودی، گروه و آرایه محدود را پشتیبانی کند. قیمت، موجودی، شناسه، امنیت و asset جزو فرم تجاری ثابت‌اند؛ الزام «هیچ فیلدی hard-coded نباشد» فقط برای مشخصات قابل توسعه لباس است، نه تمام برنامه.

### مدل عکس و پردازش

| کلاس | فیلدهای اصلی |
|---|---|
| `CaptureSet` | `front,back,left45,right45,extras[]`؛ هر مورد `CapturePhoto` |
| `CapturePhoto` | `id,angle,privatePath,width,height,rotationApplied,quality,marker?,capturedAt` |
| `QualityReport` | `blurScore,exposureScore,coverageScore,warnings[],blockingIssues[],overrideReason?` |
| `CalibrationResult` | `markerId,sideLengthMm,corners,homography?,reprojectionError,planar,valid` |
| `ProcessingJob` | `id,draftId,inputRevision,schemaVersion,status,stage,progress,result?,error?,createdAt` |
| `AnalysisResult` | `values,provider,modelVersion,promptVersion,schemaVersion,completedAt,warnings` |
| `AssetManifest` | `version,jobId,assets[],anchors,measurements,renderProfile,checksums` |

### مدل فعال‌سازی و مدیریت

| کلاس | فیلدهای اصلی |
|---|---|
| `DeviceIdentity` | `installationId,publicKeySpkiBase64,publicKeySha256,keyAlias,securityLevel`؛ هرگز privateKey |
| `ActivationRequest` | `id,requestCode,installationId,publicKeyHash,storeId?,status,createdAt,expiresAt,approvedBy?` |
| `DeviceLicense` | `licenseId,installationId,devicePublicKeyHash,storeId,status,issuedAt,entitlementExpiresAt?,features,licenseVersion` |
| `SignedLicenseLease` | `compactJws,claims`؛ داده signed immutable |
| `LeaseClaims` | `iss,aud,sub,jti,iat,nbf,exp,licenseVersion,installationId,devicePublicKeyHash,storeId,features,status,serverTime` |
| `LicenseEvaluation` | `state,reason,remainingOfflineDuration,enabledFeatures,needsSync` |
| `LicenseState` | `unactivated,checking,valid,graceWarning,expired,suspended,revoked,keyLost,clockUntrusted,invalid` |
| `Store` | `id,name,branchName?,city?,maxDevices,status,createdAt` |
| `StoreSettings` | `storeId,displayName,logoAsset?,brandPrimary,brandSecondary,captureTutorialVersion,renderCalibration` |
| `RegisteredDevice` | `id,storeId,installationId,model,androidVersion,appVersion,status,lastSeen,lastLicenseCheck` |
| `AdminUser` | `id,username,email,role,status,mfaEnabled`؛ password hash فقط سرور |
| `AuditEvent` | `id,timestamp,actorType,actorId?,deviceId?,storeId?,action,reason?,safeMetadata,correlationId` |
| `LicensePolicy` | `otpLength=6,otpTtlSeconds=300,maxAttempts=5,leaseSeconds=604800,syncSeconds=86400,maxDevicesDefault=1` |

### مدل جلسه مشتری و native

| کلاس | فیلدهای اصلی |
|---|---|
| `CustomerSession` | `id,startedAt,collection,state,currentGarmentId?,selectionVersion,shownIds,likedIds,dislikedIds,preferences` |
| `SessionState` | `idle,acquiring,starting,showing,transitioning,trackingLost,empty,ending,paused,error` |
| `PreferenceVector` | وزن محدود هر feature و شمار مشاهده؛ بدون سن/جنسیت استنباطی |
| `RecommendationCandidate` | `garmentId,score,reasonKeys,assetRevision` |
| `SessionSignal` | union: subjectAcquired,subjectLost,gesture,assetReady,transitionDone,licenseBlocked,displayLost,timeout |
| `NativeFrameSummary` | `frameId,timestampUs,subjectTrackId,poseConfidence,inArea,yawEstimate,trackingState` |
| `GestureEvent` | `eventId,sessionEpoch,frameId,handId,kind,confidence,heldMs,timestampUs` |
| `DisplayInfo` | `id,widthPx,heightPx,densityDpi,refreshRate,isPresentationCapable` |
| `PerformanceSnapshot` | `cameraFps,renderFps,poseFps,gestureFps,latencyMs,thermalLevel,droppedFrames,gpuMemoryEstimate` |

## ۶. کلاس‌های مشترک، زیرساخت و طراحی

| پوشه | کلاس | متدهای مهم و مسئولیت |
|---|---|---|
| app | `Bootstrapper` | `start():F<BootstrapResult>`؛ config، DB migration، identity، license، route |
| app | `AppRouter` | `redirect(AppState):String?`, `routes()`؛ نگهبانی activation و PIN |
| app | `AppDependencies` | تعریف providerهای concrete؛ تنها composition root |
| app | `AppLifecycleCoordinator` | `onResumed():F<void>`, `onPaused():F<void>`, `onDetached()`؛ توقف دوربین و بررسی زمان |
| core/config | `AppConfig` | `fromEnvironment(),validate()`؛ آدرس سرویس، flavor و log level؛ بدون راز |
| core/network | `DeviceApiClient` | `request<T>(ApiRequest):F<T>`, `cancel(operationId)` |
| core/network | `DeviceAuthInterceptor` | `attachAccessToken(),refreshOnce(),mapUnauthorized()`؛ refresh همزمان single-flight |
| core/network | `ErrorMapper` | `fromHttp(),fromNative(),fromStorage()` |
| core/database | `AppDatabase` | `open():F<void>`, `migrate():F<void>`, `transaction<T>(),close()` |
| core/files | `LocalAssetStore` | `stage(bytes):F<StagedAsset>`, `commit(),resolve(),verifyHash(),deleteUnreferenced()` |
| core/files | `TemporaryFileCleaner` | `cleanupExpired():F<int>`, `cleanupJob(jobId)`؛ فایل درحال استفاده حذف نشود |
| core/diagnostics | `RedactingLogger` | `info(event,fields),warn(),error()`؛ allowlist فیلدها |
| core/diagnostics | `DiagnosticsService` | `snapshot():F<DiagnosticReport>`, `exportSanitized():F<String>`؛ فقط با عمل متصدی |
| design_system/theme | `AppThemeFactory` | `operatorTheme(brand),customerTheme(brand),adminTheme()` |
| design_system/theme | `AppTokens` | رنگ، spacing، radius، typography، duration؛ constantهای typed |
| design_system/formatters | `PersianInputNormalizer` | `normalizeDigits(),normalizeSearch(),normalizeWhitespace()` |
| design_system/formatters | `PersianMoneyFormatter` | `format(Money),parse(String):Result<Money>` |
| design_system/formatters | `PersianDateFormatter` | `formatUtc(),parseLocalDate()`؛ امنیت از این کلاس استفاده نکند |
| design_system/messages | `FaMessages` | `forFailure(AppFailure),forEnum(key),forStatus(key)`؛ متن انگلیسی fallback نشود |
| design_system/widgets | `AppButton,AppTextField,AppScaffold,StatusChip,EmptyState,ErrorState,LoadingState,ConfirmSheet,PriceLabel,OfflineBanner` | `build(context)`؛ پارامترهای typed و semantics فارسی |

## ۷. کلاس‌های فعال‌سازی اپ فروشگاه

| لایه | کلاس | متدهای مهم |
|---|---|---|
| domain | `ActivationRepository` | `createRequest(identity,proof):F<ActivationRequest>`, `getStatus(id):F<ActivationRequest>`, `redeem(id,otp,proof,idempotencyKey):F<SignedLicenseLease>` |
| domain | `LicenseRepository` | `readLease():F<SignedLicenseLease?>`, `saveLease(lease):F<void>`, `renew(proof):F<SignedLicenseLease>`, `readBlock():F<LicenseBlock?>` |
| application | `ActivationService` | `ensureRequest():F<ActivationRequest>`, `submitOtp(code):F<LicenseEvaluation>`, `cancelRequest()`؛ درخواست معتبر دوباره نسازد |
| application | `LicenseService` | `evaluate():F<LicenseEvaluation>`, `syncIfDue():F<LicenseEvaluation>`, `requireFeature(feature):F<void>`, `watch():S<LicenseEvaluation>` |
| application | `LicenseSyncScheduler` | `start(),onConnectivityRestored(),onResume(),stop()`؛ retry با jitter و سقف |
| application | `DeviceSessionService` | `obtainChallenge(),exchangeProof(),refreshAccess(),clearTokens()`؛ API token کوتاه‌عمر، از license جدا |
| application | `AccessGate` | `requireOperator(),requireCustomer(),requireCatalogWrite()`؛ هر ورود حساس دوباره بررسی شود |
| data | `ActivationRepositoryImpl` | متدهای interface؛ DTO و retry فقط عملیات idempotent |
| data | `LicenseRepositoryImpl` | native secure store + API؛ token نامعتبر قبلی را پاک‌سازی کنترل‌شده کند |
| presentation | `ActivationController` | `initialize(),setOtp(),submit(),retry(),refreshStatus()` |
| presentation | `LicenseStatusController` | `refresh(),retrySync(),requestReactivation()` |
| presentation | `ActivationScreen,LicenseBlockedScreen,LicenseStatusScreen` | حالت loading، آفلاین، کد منقضی، محدودیت تلاش و موفقیت مستقل |

### پروتکل امنیتی دقیق

۱. کلید دستگاه EC P-256 با `SHA256withECDSA` در Android Keystore تولید شود. `installationId` تصادفی UUID در فضای بدون backup باشد. hash کلید عمومی، SHA-256 روی bytes استاندارد DER/SPKI است؛ روی رشته JSON یا PEM محاسبه نشود.

۲. سرور برای هر عملیات اثبات مالکیت، challenge تصادفی حداقل ۳۲ بایت با عمر ۶۰ ثانیه و مصرف اتمیک یک‌باره صادر کند. متن امضا bytes UTF-8 با قالب canonical تعریف‌شده در قرارداد است: version، purpose، challengeId، nonce، installationId، requestId اختیاری و bodySha256. ترتیب/encoding ثابت و fixture مشترک لازم است. زمان ارسالی دستگاه به‌تنهایی ضد replay نیست.

۳. ایجاد درخواست با اثبات private key همراه باشد. ادمین قبل از تأیید، فروشگاه را از رکورد واقعی انتخاب می‌کند؛ `storeId` ادعایی گوشی اختیار تخصیص نیست. کد نمایشی شش‌رقمی، در بین درخواست‌های فعال یکتا باشد؛ expiration درخواست ۲۴ ساعت، expiration کد OTP پنج دقیقه.

۴. فقط ادمین authenticated + MFA می‌تواند OTP صادر کند. سرور RNG رمزنگاری‌شده استفاده کند؛ OTP به شکل رشته با صفر ابتدایی معتبر است. فقط digest از `HMAC-SHA256(serverPepper, requestId || otpVersion || otp)` ذخیره شود؛ hash ساده روی فضای یک‌میلیونی OTP کافی نیست. pepper خارج DB و APK باشد. مقایسه constant-time انجام شود.

۵. حداکثر پنج تلاش برای درخواست، به‌صورت atomic counter؛ علاوه بر آن محدودیت IP و installation اعمال شود. رسیدن به سقف، درخواست را قفل می‌کند؛ unlock فقط ادمین یا سیاست زمان‌دار تعریف‌شده. تولید مجدد OTP قدیمی را باطل کند و شمار تلاش را بی‌قید reset نکند. OTP در پاسخ ادمین یک‌بار نمایش داده شود؛ API خواندن دوباره آن وجود نداشته باشد.

۶. redeem در transaction: بررسی status، expiration، تلاش‌ها، proof، مالکیت، محدودیت active/reserved slots، مصرف OTP و صدور رکورد license. رزرو slot در approval با انقضا؛ رقابت دو نصب برای آخرین slot باید فقط یک برنده داشته باشد. دستگاه suspended همچنان slot می‌گیرد؛ revoked آزاد می‌کند.

۷. برای گم‌شدن پاسخ redeem، `Idempotency-Key` و hash بدنه ثبت شود. تکرار همان کلید و بدنه با proof تازه، همان نتیجه قبلی را برگرداند؛ مصرف OTP دوم رخ ندهد. کلید یکسان با بدنه متفاوت خطای 409 دهد.

۸. مجوز تجاری می‌تواند دائمی باشد ولی **lease امضاشده اجرای آفلاین همیشه هفت‌روزه است**. سرور JWS استاندارد ES256 با `kid` صادر کند؛ الگوریتم مجاز allowlist، `iss/aud/nbf/exp/sub` اجباری. کلید private امضای لایسنس با کلید دستگاه متفاوت است. تفاوت encoding امضای DER دستگاه با امضای JOSE باید توسط کتابخانه معتبر مدیریت شود، نه رمزنگاری دست‌ساز.

۹. در اجرای محلی: امضای lease، claims، hash کلید جاری، و اثبات محلی مالکیت private key بررسی شود. صرف مقایسه دو hash به‌معنای داشتن private key نیست. native یک nonce تازه را امضا و با کلید مجوز verify می‌کند. نبود کلید → `keyLost` و فعال‌سازی مجدد.

۱۰. هر ۲۴ ساعت در زمان فعال‌بودن برنامه و وجود شبکه، renew اجرا شود؛ foreground الزام دقیق ۲۴ساعته پس‌زمینه را تضمین نمی‌کند. موفقیت sync مبنای زمان جدید است. پس از شش روز هشدار متصدی، پس از هفت روز توقف مود مشتری و عملیات تجاری؛ صفحه اتصال/پشتیبانی و داده‌های محلی باقی می‌مانند. مدت مجوز تجاری اگر زودتر تمام شود، همان حد اعمال شود.

۱۱. پاسخ sync باید status امضاشده داشته باشد. مشاهده revoke/suspend بلافاصله در فضای امن cache شود؛ قطع اینترنت نباید به lease فعال قدیمی برگرداند. resume از suspension فقط با پاسخ signed جدید و `licenseVersion` بالاتر. revoke نهایی است؛ فعال‌سازی تازه برای استفاده دوباره لازم است.

۱۲. مرجع زمان ترکیبی: `serverTime` آخرین پاسخ + elapsedRealtime در همان boot، و persisted high-water mark. ساعت سیستم عقب‌رفته، reboot همراه زمان نامعتبر یا انقضای نامطمئن → `clockUntrusted` و اتصال لازم. محافظت کامل در برابر rollback روی دستگاه compromise‌شده ادعا نشود. زمان OTP از سرور و countdown صرفاً نمایشی است.

۱۳. لغو روی دستگاه آفلاین حداکثر تا پایان lease تأخیر دارد. انتقال license به گوشی تازه ممکن است تا انقضای lease قبلی هم‌پوشانی آفلاین داشته باشد؛ ادمین باید این هشدار را ببیند. صفرکردن این هم‌پوشانی نیازمند آنلاین‌بودن مداوم یا تحویل فیزیکی دستگاه است.

۱۴. کلیدهای verify سرور با `kid` در برنامه باشند؛ rollover با دوره هم‌پوشانی و keyset امضاشده توسط trust anchor انجام شود. URL دلخواه `jku/x5u` از token پذیرفته نشود. همه secure stateها از Auto Backup و device-to-device backup مستثنا شوند. uninstall/clear data به‌عنوان نصب جدید مدیریت شود.

۱۵. امضای مجوز محرمانگی نمی‌دهد. رمزگذاری local token برای hygiene است؛ token اثبات امضاشده است، نه API admin credential. endpointهای پردازش/آپلود entitlement را در سرور نیز enforce کنند. `isActivated=true` در SharedPreferences هرگز معیار دسترسی نباشد.

## ۸. ورود متصدی و راه‌اندازی فروشگاه

| کلاس | متدهای مهم |
|---|---|
| `OperatorAuthRepository` | `hasPin():F<bool>`, `setPin(pin):F<void>`, `verify(pin):F<PinResult>`, `readLockout():F<Lockout>` |
| `OperatorAuthService` | `unlock(pin),lock(),changePin(old,new),requestReset(),applyReset(proof)` |
| `OperatorSessionController` | `enter(),submitPin(),onInactivity(),exitToCustomer()` |
| `OnboardingRepository` | `load():F<OnboardingState>`, `save(state):F<void>` |
| `StoreSetupService` | `saveBranding(settings),configurePin(pin),finish()` |
| `TutorialController` | `next(),previous(),complete(),reopen()` |
| `StoreSetupController` | `load(),updateName(),pickLogo(),setBrandColors(),submit()` |
| `OperatorPinScreen,StoreSetupScreen,CaptureTutorialScreen` | فقط view؛ مراحل ذخیره‌پذیر |

پین پیش‌فرض شش‌رقمی؛ ورودی فارسی و لاتین پذیرفته شود. پین خام ذخیره نشود؛ verifier با KDF استاندارد و salt تصادفی، پارامتر benchmark‌شده و یک secret وابسته به Keystore. قفل پس از پنج خطا به مدت پنج دقیقه و ادامه افزایش تأخیر؛ شمارنده از reboot جان سالم ببرد. امنیت پین روی گوشی روت‌شده محدود است. بازنشانی پین با فرمان آنلاین signed ادمین، bind به نصب و nonce و عمر ده دقیقه؛ بدون «پین مادر».

جلسه متصدی بعد از پنج دقیقه بی‌عملی قفل شود؛ هنگام capture فعال، تعامل معتبر تایمر را تمدید می‌کند. رفتن background بیش از سی ثانیه، ورود دوباره پین می‌خواهد. نمایشگر خارجی هرگز صفحه پین، OTP، تنظیمات یا پیام داخلی را نشان ندهد. آموزش با `tutorialVersion` ذخیره شود، نه فقط bool؛ آموزش مهم جدید قابل نمایش دوباره است.

## ۹. ثبت عکس، کیفیت و اندازه‌گیری

| لایه | کلاس | متدهای مهم |
|---|---|---|
| domain | `CaptureRepository` | `loadDraft(id),savePhoto(draftId,photo),removePhoto(),saveCaptureSet()` |
| application | `CaptureService` | `begin(category),capture(angle),retake(angle),validateSet(),finish()` |
| application | `CaptureQualityService` | `evaluate(photo):F<QualityReport>`, `acceptOverride(report,reason)` |
| application | `MeasurementService` | `estimate(photo,marker,anchors):F<GarmentMeasurements>`, `setManual(key,mm)` |
| application | `AnchorReviewService` | `validate(points,category),move(key,point),approve(assetRevision)` |
| data | `CaptureRepositoryImpl` | ذخیره اتمیک DB و ارجاع فایل؛ فایل ابتدا temp سپس rename |
| presentation | `CaptureController` | `initialize(),selectAngle(),takePhoto(),confirmPhoto(),retake(),continueToProcessing()` |
| presentation | `AnchorEditorController` | `load(),dragAnchor(),reset(),confirm()` |
| presentation | `MeasurementEditorController` | `setValue(),confirm(),markUnknown()` |
| presentation | `CaptureWizardScreen,PhotoReviewScreen,AnchorEditorScreen,MeasurementEditorScreen` | راهنما و review؛ بزرگنمایی تصویر و undo آخرین جابه‌جایی |

آموزش فارسی باید نور، پس‌زمینه، تمام‌قد لباس، زاویه‌ها، مارکر، و نمونه درست/نادرست داشته باشد. برای کیفیت تصویر، مانکن یا آویز کاربردی است؛ برای **اندازه‌گیری صفحه‌ای** لباس صاف روی سطح اولویت دارد. مارکر ۱۰۰×۱۰۰ میلی‌متر باید دقیق چاپ و با خط‌کش کنترل شود، در صفحه لباس باشد، چهار گوشه دیده شوند و تصویر تقریباً عمود گرفته شود.

با چهارگوش مارکر می‌توان homography صفحه را برآورد کرد؛ یک نسبت ساده pixel/cm در عکس پرسپکتیوی کافی نیست. روی مانکن، قسمت‌های لباس عمق‌های متفاوت دارند؛ ابعاد فقط تخمینی یا ناموجود. از Chest Width دوبعدی، دور سینه دقیق تولید نکنید. `flatChestWidth` با `chestCircumference` دو کلید متفاوت‌اند. `inseam` بدون دیده‌شدن مسیر داخلی پا null بماند.

انتخاب اولیه مارکر ArUco با dictionary ثابت و شناسه مشخص؛ واحد داخلی میلی‌متر و UI سانتی‌متر با یک رقم اعشار. detector و thresholds با نمونه واقعی کالیبره شوند. تشخیص گوشه‌ها، تارشدگی، نور و کامل‌بودن لباس معیارهای جدا هستند. «Override» برای هشدار ممکن است، ولی عکس خراب قابل decode، فایل مفقود یا marker نامعتبر را به اندازه معتبر تبدیل نمی‌کند. در override اندازه null و برچسب «نیازمند ورود دستی» شود.

چرخش EXIF هنگام ingest اعمال و metadata مکانی EXIF قبل از آپلود پاک شود. anchorها بعد از حذف پس‌زمینه و crop مجدد تبدیل شوند. ناحیه شفاف دور لباس باعث تغییر scale می‌شود؛ bounds تصویری و bounds محتوای لباس جدا ذخیره شوند. جنس دقیق الیاف از ظاهر قابل اثبات نیست؛ AI باید «احتمالی» یا null بدهد و برچسب کالا/ورودی متصدی اولویت دارد.

## ۱۰. فرم پویا و مدیریت schema

| کلاس | متدهای مهم |
|---|---|
| `SchemaRepository` | `getEffective(storeId):F<EffectiveSchema>`, `watch():S<EffectiveSchema>`, `submitChange(change,expectedVersion):F<EffectiveSchema>` |
| `MetadataRepository` | `load(garmentId),saveValues(id,values,expectedRevision),excludeField(id,key),restoreField(id,key)` |
| `SchemaService` | `compose(base,store),validateDefinition(),planMigration(old,new),applyServerSnapshot()` |
| `MetadataMergeService` | `mergeAiResult(current,result,jobBaseRevision):MergeProposal`, `acceptSuggestion(key),rejectSuggestion(key)` |
| `MetadataValidationService` | `validateValue(def,value),validateDocument(schema,values):List<FieldError>` |
| `DynamicFieldRegistry` | `resolve(FieldType):FieldRenderer`, `supportedTypes()`؛ ناشناخته را read-only نشان دهد |
| `DynamicFormController` | `load(),setValue(key,value),markReviewed(key),removeLocal(key),restoreLocal(key),validate(),save()` |
| `CustomFieldController` | `setDefinition(),preview(),submit(),disableGlobally(),retrySync()` |
| `SchemaRepositoryImpl,MetadataRepositoryImpl` | پیاده‌سازی قراردادها؛ cache نسخه‌دار |
| `DynamicGarmentForm,CustomFieldEditorScreen,SchemaFieldListScreen,FieldReviewBadge` | view؛ خطای همان فیلد، نمایش منبع و سطح اطمینان |
| `TextFieldRenderer,LongTextFieldRenderer,IntegerFieldRenderer,DecimalFieldRenderer,BooleanFieldRenderer,SingleSelectFieldRenderer,MultiSelectFieldRenderer,DateFieldRenderer,YearFieldRenderer,YearRangeFieldRenderer,NumberRangeFieldRenderer,ColorFieldRenderer,ScoreFieldRenderer,TagsFieldRenderer,GroupFieldRenderer` | `build(def,value,onChanged,error),parse(raw),format(value)` |

کلید پایه ثابت؛ کلید custom با namespace مانند `custom.<uuid>` تا تغییر عنوان فارسی داده را نشکند. حد اولیه: ۵۰ فیلد custom فعال، ۱۰۰ گزینه برای select، عنوان ۸۰ نویسه، شرح ۵۰۰، سؤال AI هزار، tags حداکثر ۲۰. key ساخته سرور، label کاربر. فرمول اجرایی، HTML و کد JavaScript در فیلد پشتیبانی نمی‌شود.

حذف از لباس، رکورد exclusion می‌سازد؛ تحلیل دوباره آن را زنده نکند. حذف آینده یعنی archive/disable در schema همان فروشگاه؛ اطلاعات لباس‌های قبلی باقی می‌ماند. حذف جهانی UI باید عبارت «برای لباس‌های جدید این فروشگاه» و تأیید داشته باشد؛ هیچ متصدی schema فروشگاه دیگر یا schema پایه محصول را عوض نمی‌کند. فیلد ضروری هویتی حذف‌پذیر نیست.

ویرایش type روی فیلد دارای داده ممنوع؛ فیلد تازه و migration صریح لازم است. تغییر label آزاد؛ حذف option یعنی archive با حفظ نمایش داده قدیمی. هر job snapshot schema را می‌گیرد؛ پاسخ آن به schema جدید بدون mapping معتبر اعمال نشود. آفلاین، تغییر custom در صف pending است و برای تحلیل بعدی تا sync تأییدشده استفاده نمی‌شود؛ نام فیلد و مقدار محلی قابل ذخیره می‌مانند.

اولویت مقدار بر اساس وضعیت است، نه صرفاً منشأ: `operatorConfirmed` هرگز با job بعدی overwrite نشود. نتیجه AI تازه یک پیشنهاد کنار مقدار فعلی است. CV هم اگر متصدی آن را اصلاح کرده override نمی‌کند. در response نمره اطمینان مدل «احتمال کالیبره‌شده درست‌بودن» نیست؛ UI بنویسد «اطمینان تخمینی مدل». امتیاز مدل و confidence اندازه‌گیری از هم مستقل‌اند.

## ۱۱. پردازش ابری و تحلیل لباس

| کلاس | متدهای مهم |
|---|---|
| `ProcessingRepository` | `createJob(input):F<ProcessingJob>`, `getJob(id)`, `cancelJob(id)`, `retryJob(id)` |
| `UploadService` | `prepare(files),upload(file,url),resume(uploadId),complete(uploadId,sha256)` |
| `GarmentProcessingCoordinator` | `start(draftId),resumePending(),onResult(job),applyApprovedAssets(),cancel()` |
| `AssetDownloadService` | `downloadManifest(jobId),downloadAssets(manifest),verifyAll(),activateRevision()` |
| `ProcessingController` | `start(),poll(),retryStage(),cancel(),openReview()` |
| `ProcessingRepositoryImpl` | API و durable local job reference؛ polling با backoff |
| `ProcessingProgressScreen,ProcessingFailureScreen` | stage واقعی، بدون درصد ساختگی؛ ادامه بعد از بستن اپ |

مراحل job: `queued → validating → segmenting → extractingAnchors → analyzing → packaging → succeeded`؛ شاخه‌های `failed,cancelled`. مقدار پیشرفت فقط بر اساس مراحل معلوم؛ زمان باقیمانده حدس زده نشود. اجرای دوباره idempotent و هر نتیجه دارای inputRevision و schemaVersion است. خروجی job قدیمی بعد از تعویض عکس نباید عکس جدید را overwrite کند.

تصاویر فقط لباس ارسال شوند؛ دوربین مشتری مسیر upload ندارد. عکس‌ها از نظر MIME واقعی، اندازه decode‌شده، ابعاد و سقف bytes کنترل شوند. سقف پیشنهادی هر فایل ۱۵MB، طول ضلع ۶۰۰۰px، مجموع یک job صد MB. worker فایل را decode و دوباره encode کند؛ از decompression bomb و URL دلخواه ورودی جلوگیری شود. ابتدا storage key ایجادشده توسط سرور، نه URL عمومی ارسال‌شده توسط کاربر.

پرامپت پایه کارفرما حفظ شود؛ اطلاعات فیلدهای custom در بخش داده پایین‌اولویت serialise شوند. sanitization به‌تنهایی مصونیت prompt injection نمی‌دهد: مدل ابزار، شبکه آزاد یا راز سرور در context نداشته باشد؛ پاسخ با schema allowlist، طول و type اعتبارسنجی شود. حداکثر دو تلاش اصلاح پاسخ، سپس خطای قابل review. فیلد خارج از schema حذف/رد با warning، نه اجرای آن.

سال مد از تصویر قابل اثبات نیست. در MVP بدون منبع به‌روز، `trendStatus=current` قطعی و `peakYears` حدسی ممنوع؛ `evidenceAsOf` و `sourceRefs` در صورت پژوهش واقعی پر شوند، وگرنه null یا توصیف کلی دوره. امکان حذف AI field توسط متصدی باقی بماند. دسترسی تجاری API، مجوز مدل‌ها و محل پردازش برای استقرار واقعی جدا بررسی شوند؛ provider جایگزین باید پشت interface باشد.

## ۱۲. کاتالوگ، فایل و دیتابیس محلی

| کلاس | متدهای مهم |
|---|---|
| `GarmentRepository` | `list(query):F<Page<Garment>>`, `watch(query):S<List<Garment>>`, `get(id)`, `save(draft,expectedRevision)`, `archive(id)`, `setActive(id,bool)`, `setStock(id,int)` |
| `CatalogService` | `createDraft(),publishGarment(),updatePrice(),duplicateDraft(),archiveGarment()` |
| `CatalogEligibilityPolicy` | `canPublish(garment),canTryOn(garment,capabilities),reasonForExclusion()` |
| `GarmentRepositoryImpl` | DB transaction و mapper؛ view مستقیم DAO صدا نزند |
| `CatalogController` | `load(),search(),filter(),loadMore(),toggleActive(),archive()` |
| `GarmentEditorController` | `load(),setPrice(),setDiscount(),setStock(),save(),discard()` |
| `GarmentDao` | `selectPage(),selectEligible(),insert(),updateIfRevision(),archive()` |
| `MetadataDao` | `selectValues(),upsertValues(),setExclusion()` |
| `CaptureDao` | `upsertDraft(),upsertPhoto(),findPendingDrafts()` |
| `AssetDao` | `upsertManifest(),listReferences(),markReady(),findOrphans()` |
| `SchemaDao` | `getSnapshot(),insertSnapshot(),queueChange(),markSynced()` |
| `JobDao` | `upsert(),findUnfinished(),markApplied()` |
| `SettingsDao` | `read(),write()`؛ رمز و OTP وارد این جدول نشود |
| `CatalogScreen,GarmentDetailScreen,GarmentEditorScreen` | جست‌وجو، draft badge، خطای دارایی، قیمت و موجودی |

جدول‌های محلی: `garments,metadata_values,field_exclusions,capture_drafts,capture_photos,assets,garment_asset_links,measurement_values,anchor_sets,schema_snapshots,pending_schema_changes,processing_jobs,store_settings,app_settings`. جلسه مشتری جدول دائمی ندارد. لایسنس و verifier پین در secure store جدا قرار دارند.

کلیدهای مهم: PK شناسه UUID، FK برای asset و garment؛ unique روی `(garmentId,fieldKey)` و `(storeId,schemaVersion)`؛ index روی `isActive,category,updatedAt` و barcode در صورت سیاست unique فروشگاه. JSON schema و مقادیر پیچیده در JSON versioned؛ قیمت/stock/status ستون واقعی برای query. SQLite برای مقادیر decimal معیار واحد مشخص دارد؛ پول float نیست.

ذخیره فایل دو مرحله‌ای: دانلود به temp → verify hash → rename atomic به مسیر revision → transaction ارجاع DB → پاک‌سازی قدیمی در job بعدی. crash میان فایل و DB با orphan cleanup قابل اصلاح باشد. هیچ migration جدول را به‌طور خودکار destructive reset نکند. نسخه DB جدید روی اپ قدیمی قابل بازشدن نیست؛ پیام «نیاز به به‌روزرسانی» و حفظ داده.

فایل‌ها: `files/garments/<id>/<revision>/...`؛ نام path از متن متصدی گرفته نشود. cache با محدودیت ۵۱۲MB پیش‌فرض، دارایی جاری و prefetch pin شوند. کمبود فضا قبل از capture/upload/download بررسی شود. `discountPrice` کمتر از قیمت عادی و نامنفی؛ stock صفر در پیشنهاد حذف می‌شود. نام‌گذاری `isActive` و `tryOnEligible` مستقل است.

## ۱۳. کلاس‌های جلسه مشتری و پیشنهاد

| لایه | کلاس | متدهای مهم |
|---|---|---|
| application | `CustomerSessionCoordinator` | `startEngine(),handle(signal),beginSession(),selectNext(),endSession(reason),pause(),resume(),dispose()`؛ تنها نویسنده state جلسه |
| domain | `SessionReducer` | `reduce(state,signal):SessionTransition`؛ خالص؛ side effect در coordinator |
| domain | `SubjectAdmissionPolicy` | `evaluate(summary,history):AdmissionDecision`؛ حضور پایدار و مرکز تصویر |
| domain | `RecommendationEngine` | `rank(candidates,preferences,context):List<RecommendationCandidate>`, `choose(ranked,rng):Candidate?` |
| domain | `PreferenceUpdater` | `apply(vector,garment,feedback):PreferenceVector`, `reset()` |
| domain | `RecommendationFeatureEncoder` | `encode(garment,schema):FeatureVector`, `normalize(),supportedField(def)` |
| application | `CustomerCatalogService` | `eligible(collection):F<List<Garment>>`, `refreshSnapshot(),invalidate(id)` |
| application | `AssetPrefetcher` | `schedule(nextIds),awaitReady(id):F<AssetHandle>`, `cancelExcept(ids),dispose()` |
| application | `RenderCoordinator` | `prepare(garment),show(garment,selectionVersion),transitionTo(),clear()` |
| application | `GestureFeedbackService` | `accept(event,session):bool`, `acknowledge(eventId),resetEpoch()` |
| application | `PrivacySessionCleaner` | `clearSessionMemory(),purgeTemporaryImages(),cancelPendingOperations()` |
| presentation | `CustomerModeController` | `enter(),chooseCollection(),pauseByOperator(),restart(),exit()` |
| presentation | `CustomerModeScreen,CustomerMonitorPanel,CollectionPicker,CustomerHelpScreen` | view؛ اطلاعات فنی فقط گوشی |

### ماشین حالت

| حالت فعلی | رخداد/شرط | حالت بعد | اثر |
|---|---|---|---|
| `idle` | فرد در ROI با pose قابل قبول | `acquiring` | شروع تایمر ۸۰۰ms |
| `acquiring` | همان track به‌مدت ۸۰۰ms پایدار | `starting` | epoch جدید، پاک‌کردن preferences، انتخاب مجموعه |
| `acquiring` | track گم شود/فرد دیگری وارد شود | `idle` | reset تایمر |
| `starting` | asset آماده + collection معلوم | `transitioning` | glow اولیه و فرمان show |
| `transitioning` | native transitionDone با version جاری | `showing` | بازکردن gate ژست |
| `showing` | ژست معتبر | `transitioning` | ثبت یک رأی، انتخاب بعدی، بستن gate |
| `showing` | track گم شود بیش از ۳۰۰ms | `trackingLost` | لباس مخفی، عدم نمایش روی رهگذر |
| `trackingLost` | همان track با اطمینان برگردد پیش از ۵s | `showing` | اتصال مجدد و reset ژست |
| `trackingLost` | پنج ثانیه بدون فرد معتبر | `ending` | cancel و پاک‌سازی |
| هر حالت فعال | فرد متفاوت/ابهام هویت track | `ending` | سلیقه به مشتری بعد منتقل نشود |
| `ending` | cleanup تمام شود | `idle` | صفحه دعوت |
| `starting/showing` | کاندیدای آماده وجود ندارد | `empty` | پیام پایان/عدم موجودی |
| هر حالت فعال | license blocked یا display قطع | `paused` | توقف تصویر مشتری در خروجی |
| `paused` | مجوز و نمایشگر معتبر، تأیید متصدی | `idle` | جلسه قبلی احیا نشود |

تشخیص فرد همان تشخیص چهره/هویت نیست. شماره track در جابه‌جایی ناگهانی ممکن است تغییر کند؛ وقتی تداوم نامطمئن است جلسه تازه امن‌تر از انتقال بردار ترجیح است. برای دو نفر، نزدیک‌ترین فرد به ROI انتخاب و قفل شود؛ اگر دو بدن ROI را اشغال کردند پیام «لطفاً یک نفر روی علامت بایستد» و توقف پیشنهاد. تحلیل ژست فقط دست‌های همان فرد پذیرفته شود.

### قواعد ژست

نوع native خروجی `Thumb_Up` و `Thumb_Down` به enum دامنه `like/dislike` نگاشت شود. threshold شروع پیشنهادی ۰٫۷۵ و hold برابر ۶۰۰ms است، قابل کالیبراسیون. تشخیص یک ژست نگه‌داشته‌شده فقط **یک** رأی می‌دهد. پس از رأی، دست باید حداقل ۳۰۰ms از آن ژست خارج شود؛ cooldown حداقل ۱۲۰۰ms و تا پایان transition ادامه یابد. شناسه event تکراری و epoch قدیمی رد شوند. دو دست با رأی متناقض هیچ رأی ثبت نکنند؛ پیام کوتاه «با یک دست انتخاب کنید». هنگام loading و trackingLost ژست غیرفعال است.

### پیشنهاد قابل پیاده‌سازی

ابتدا فقط کالاهای فعال، stock مثبت، خانواده رندر پشتیبانی‌شده، asset آماده و collection انتخابی فیلتر شوند. هیچ سن، جنسیت، قومیت یا وضعیت مالی از تصویر مشتری استخراج نشود. `recommendedAge` و personas در MVP فقط در فرم و فیلتر اختیاری متصدی‌اند؛ بدون دریافت صریح سن مشتری به رتبه‌بندی شخصی اضافه نشوند. collection انتخابی، جنسیت واقعی فرد تلقی نشود.

برای نسخه اول featureها: رنگ خانواده وزن ۰٫۲۵، استایل ۰٫۳۰، fit وزن ۰٫۱۰، pattern وزن ۰٫۱۰، occasions وزن ۰٫۱۰، category وزن ۰٫۱۰، season وزن ۰٫۰۵. نبود هر feature باعث بازتوزیع وزن روی داده موجود می‌شود. رنگ دقیق HEX برای distance ادراکی کافی نیست؛ شروع با family ثابت. رأی مثبت +۱ و منفی −۰٫۶، decay ترجیحات ۰٫۹۵ و clip در بازه −۳..۳. `score` مجموع وزن‌دار affinity نرمال‌شده است؛ از popularity ساختگی استفاده نشود.

تا سه بازخورد اول انتخاب متنوع و سپس ۸۰٪ انتخاب از بالاترین رتبه و ۲۰٪ exploration از گروه‌های کمتر دیده‌شده؛ RNG قابل seed برای تست. در هر جلسه تکرار خودکار لباس ممنوع. وقتی همه تمام شدند، پیام «همه مدل‌های این مجموعه را دیدید» و دو گزینه «نمایش پسندیده‌ها»/«شروع دوباره»؛ dislikeها خودکار دوباره وارد صف نشوند. قیمت پیش‌فرض feature ترجیح نیست.

فیلد سفارشی فقط با `recommendationRelevant=true` و encoder معتبر استفاده شود. select/tags/boolean قابل encode؛ عدد فقط با min/max معلوم. متن آزاد بدون مدل embedding وارد بردار نشود؛ UI روشن بگوید برای متن، این قابلیت در نسخه اول در دسترس نیست. schemaVersion encoder در snapshot جلسه قفل شود.

پیش‌بارگذاری سه لباس، حداکثر دو IO همزمان، asset جاری pinned. انتخاب بعدی که asset آن خراب است skip شود و علت در diagnostics ثبت گردد. اگر همه خراب‌اند empty با پیام متصدی، نه spinner بی‌پایان. عملیات async دارای sessionEpoch و selectionVersion است؛ نتیجه دیررس جلسه قبل نادیده گرفته شود.

## ۱۴. پلاگین بومی: کلاس‌های کامل و مرز مسئولیت

نام فایل Kotlin همان نام کلاس با پسوند `.kt`؛ نام فایل Dart به snake_case. بسته `<namespace>` از ابتدا یک‌بار انتخاب شود. موتور زنده مستقل از UI Flutter طراحی شود تا قطع widget باعث نشت دوربین نشود.

| پوشه بومی | کلاس | متدهای مهم |
|---|---|---|
| root | `TryonNativePlugin` | `onAttachedToEngine(),onDetachedFromEngine(),onAttachedToActivity(),onDetachedFromActivity()` |
| bridge | `TryonHostApiImpl` | پیاده‌سازی فرمان‌های Pigeon بخش بعد، تبدیل exception به `NativeFailure` |
| bridge | `NativeEventEmitter` | `emit(event),subscribe(),unsubscribe(),close()`؛ buffer محدود |
| security | `DeviceKeyStore` | `getOrCreateIdentity(),signChallenge(bytes),proveLocalPossession(),hasKey(),securityLevel()` |
| security | `SecureValueStore` | `write(name,bytes),read(name),delete(name)`؛ AES-GCM و nonce تازه برای هر write |
| security | `NativeLicenseVerifier` | `verifyJws(token,keyset):VerifiedClaims`, `verifyBinding(claims),evaluateTime()` |
| security | `TrustedTimeStore` | `recordServerTime(),estimateNow(),detectRollback(),requireOnlineAfterAnomaly()` |
| security | `NativeAccessGuard` | `installVerifiedLease(),assertFeature(),block(reason),clear()`؛ برای start و show نیز لازم |
| security | `OperatorPinVault` | `setPin(),verifyPin(),changePin(),applySignedReset(),getLockout()` |
| camera | `CameraSessionManager` | `startCapture(config),startCustomer(config),captureStill(),stop(),switchLens()`؛ یک مالک |
| camera | `CameraCapabilityInspector` | `inspect():CameraCapabilities`, `supportedUseCaseConfig()` |
| camera | `FrameDispatcher` | `onImage(imageProxy),dispatchLatest(),close()`؛ در تمام مسیرها close frame |
| camera | `FrameTransformResolver` | `sensorToAnalysis(),analysisToRender(),renderToDisplay(),updateRotation()` |
| capture | `CaptureQualityEvaluator` | `evaluate(bitmap):QualityReport` |
| capture | `MarkerDetector` | `detect(bitmap,markerSpec):CalibrationResult` |
| capture | `PlanarMeasurementEstimator` | `rectify(),measureAnchors(),estimateError()`؛ نامعتبر → unavailable |
| vision | `VisionEngine` | `start(config),process(frame),pause(),resume(),close()` |
| vision | `InferenceScheduler` | `shouldRun(task,timestamp),markRunning(),markComplete(),setBudget()` |
| vision | `PoseTracker` | `detectAsync(frame),onResult(),reset(),close()` |
| vision | `PersonMaskEstimator` | `segmentAsync(frame),latestMask(),close()` |
| vision | `GestureRecognizerAdapter` | `recognizeAsync(frame,subjectRoi),onResult(),close()` |
| vision | `SubjectTracker` | `selectSubject(poses,roi),update(),isSameTrack(),reset()` |
| vision | `PoseSmoother` | `filter(pose,timestamp),reset()`؛ EMA یا One Euro با پارامتر قفل‌شده |
| vision | `GestureStabilityFilter` | `update(raw,pose,timestamp),release(),reset()` |
| vision | `OcclusionEstimator` | `estimate(pose,mask):OcclusionHints`؛ در MVP دست/ساعد تقریبی |
| rendering | `TryonRenderEngine` | `initialize(),attachSurface(),detachSurface(),drawFrame(),release()` |
| rendering | `EglContextManager` | `createSharedContext(),createWindowSurface(),makeCurrent(),swap(),destroy()` |
| rendering | `CameraTextureSource` | `attach(),updateTexImage(),textureTransform(),release()` |
| rendering | `GarmentTextureCache` | `load(asset):TextureHandle`, `pin(),unpin(),evict(),clear()` |
| rendering | `GarmentWarpSolver` | `solve(anchors,pose,profile):WarpMesh`, `validate(mesh)` |
| rendering | `GarmentMeshRenderer` | `uploadMesh(),render(mesh,texture,transform)` |
| rendering | `BodyGlowRenderer` | `setMask(),render(time,style),setReducedMotion()` |
| rendering | `OcclusionComposer` | `compose(camera,garment,occlusionHints)` |
| rendering | `TransitionController` | `start(from,to,version),advance(time),cancel(),isBusy()` |
| rendering | `SceneStateStore` | `update(sceneVersion,patch),snapshot()`؛ ترتیب نسخه enforce شود |
| display | `ExternalDisplayManager` | `listDisplays(),attach(id),detach(),observeChanges()` |
| display | `CustomerPresentation` | `onCreate(),setScene(),onDisplayRemoved(),dismiss()` |
| display | `CustomerHudView` | `setPrice(),setInstructions(),setFeedback(),setCollectionOptions()`؛ متن فارسی native |
| display | `DisplayCalibrationStore` | `save(profile),load(displayFingerprint),reset()` |
| diagnostics | `PerformanceMonitor` | `recordFrame(),recordInference(),snapshot(),reset()` |
| diagnostics | `ThermalBudgetController` | `onThermalStatus(),computeBudget(),restoreGradually()` |
| diagnostics | `ResourceRegistry` | `register(),releaseAll(),assertNoActiveCamera()` |

### کلاس‌های wrapper در Dart

| کلاس | متدهای مهم |
|---|---|
| `TryonNativeBridge` | `initialize(),capabilities(),startCapture(),captureStill(),startCustomer(),stop(),dispose()` |
| `DeviceSecurityBridge` | `getIdentity(),signChallenge(),verifyLease(),storeLease(),evaluateLicense(),setPin(),verifyPin()` |
| `RenderBridge` | `loadGarment(),setScene(),transition(),setCalibration(),clear()` |
| `DisplayBridge` | `list(),attach(),detach(),setHud(),watchDisplays()` |
| `NativeEventDecoder` | `decode(envelope):NativeEvent`؛ نسخه ناسازگار خطای روشن |
| `NativeEvent` | union: tracking,gesture,transitionDone,displayChanged,performance,engineError,licenseBlocked |

### قرارداد Pigeon و رویداد

فرمان‌های تولیدشده: `initialize(EngineConfig)→EngineCapabilities`، `getDeviceIdentity()→DeviceIdentityDto`، `signChallenge(ChallengeDto)→SignatureDto`، `verifyAndInstallLease(SignedLeaseDto)→LicenseEvaluationDto`، `getLicenseEvaluation()→LicenseEvaluationDto`، `startCapture(CaptureConfig)→PreviewHandle`، `captureStill(CaptureCommand)→CapturePhotoDto`، `startCustomer(CustomerConfig)→PreviewHandle`، `stopEngine()→void`، `loadGarment(GarmentAssetDto)→AssetHandle`، `updateScene(SceneDto)→void`، `transition(TransitionDto)→void`، `listDisplays()→List<DisplayDto>`، `attachDisplay(id)→void`، `detachDisplay()→void`، `setHud(HudDto)→void`، `setCalibration(CalibrationDto)→void`، `setPin(PinCommand)→void`، `verifyPin(PinCommand)→PinResultDto`، `applyPinReset(SignedResetDto)→void`، `dispose()→void`.

هر فرمان async `commandId` داشته باشد. پاسخ شکست دارای `code,retryable,safeDetails`؛ stacktrace و path حساس در UI ظاهر نشود. `PreviewHandle` شامل textureId است، نه bitmap. native فایل capture را در فضای خصوصی مجاز می‌نویسد و مسیر whitelist‌شده می‌دهد. متد دلخواه `readAnyFile(path)` یا اجرای command سیستم وجود نداشته باشد.

پاکت رویداد: `protocolVersion=1,eventId,engineEpoch,sessionEpoch,timestampUs,type,payload`. رویداد summary حداکثر ۱۵Hz، performance یک Hz؛ ژست و خطا فوری. stream از صف نامحدود استفاده نکند: آخرین tracking جایگزین قبلی، خطا/gesture با buffer محدود و dedup. pose کامل برای هر فریم در Dart لازم نیست؛ mask یا byte array تصاویر روی کانال ارسال نشود.

## ۱۵. نکات غیر بدیهی رندر و دوربین

### مختصات و تصویر آینه‌ای

مختصات canonical پس از اعمال rotation دوربین و **پیش از mirror نمایش** تعریف شود: origin بالا-چپ، x به راست، y به پایین. sensor rotation، crop تحلیل، crop نمایش و نسبت aspect همگی matrix ثبت‌شده داشته باشند. garment anchor در تصویر asset بدون mirror است. تصویر مشتری و لباس به‌صورت یک scene باهم mirror شوند؛ فقط یکی mirror نشود. متن فارسی و قیمت **بعد از mirror** در لایه HUD قرار می‌گیرند تا برعکس نشوند.

در قرارداد pose نقطه گردن الزاماً landmark مستقلی نیست؛ از میانگین شانه‌ها و نسبت قابل‌تنظیم مشتق شود. visibility نقطه با presence کل بدن فرق دارد. لباس با شانه پنهان/نامطمئن به محل تصادفی نپرد؛ بعد از ۱۵۰ms از آخرین pose معتبر، opacity کاهش یابد و حداکثر پس از ۳۰۰ms مخفی شود. این اعداد شروع طراحی‌اند و باید با latency واقعی تنظیم شوند.

### روش پرو اولیه

برای بالاتنه یک mesh قالبی دو‌بعدی با topology ثابت برای تنه و دو آستین، و اتصال به شانه/آرنج/مچ/کمر استفاده شود. perspective warp واحد فقط برای تنه ساده مناسب است؛ آستین‌ها نیاز به قطعات مجزا یا deform mesh دارند. `GarmentWarpSolver` از anchorهای تأییدشده و pose vertexها را تولید کند. برای initial preview تنه‌محور affine کافی است ولی این نمونه معیار پذیرش نهایی نیست.

حالت دست روی سینه و چرخش شدید مشکل occlusion دارد. ماسک person شامل لباس واقعی و دست و بدن باهم است و به‌تنهایی مشخص نمی‌کند دست جلوی لباس است. نسخه اول از mask محدودشده با capsuleهای دست/ساعد مشتق از pose استفاده می‌کند و **تقریبی** برچسب می‌زند. بیش از yaw حدود ۲۵ درجه یا تداخل پیچیده → راهنمای «روبه‌روی دوربین بایستید و دست‌ها را کمی باز کنید». این راهکار بازسازی واقعی پارچه و حذف کامل لباس زیرین نیست؛ بیرون‌زدگی لباس واقعی از لبه overlay امکان دارد.

چسباندن پوستر لباس به بدن بدون preview عملی قابل قبول نیست. مرحله native با لباس‌های ساده و الگوی پس‌زمینه مختلف آزمون شود؛ اگر کیفیت قانع‌کننده نشد، توسعه باقی سامانه نباید به ادعای آماده‌بودن محصول منجر شود. قابلیت 2.5D آینده باید پشت `RenderProfile` و adapter تازه اضافه شود، نه ده‌ها شرط در `CustomerModeController`.

### زمان‌بندی و مصرف منابع

دوربین مشتری با ۷۲۰p/۳۰fps شروع شود؛ رزولوشن inference کمتر و مستقل از خروجی است. CameraX از latest-only استفاده کند تا frameهای عقب‌مانده تأخیر نسازند؛ `ImageProxy.close()` در همه مسیرها ضروری است [م۱]. inferenceهای async timestamp یکنواخت افزایشی دارند. پردازش یک فریم دوبار همزمان به model غیرthread-safe ارسال نشود.

به‌ترتیب هدف: رندر ۳۰، pose پانزده، mask ده، gesture ده fps. این‌ها هدف هستند، نه قابلیت تضمین‌شده هر گوشی. دوربین preview روان حتی اگر inference کم شد حفظ شود. بین دو pose معتبر interpolation محدود؛ پیش‌بینی بلندمدت ممنوع. همه مدل‌ها اگر GPU بخواهند می‌توانند با رندر رقابت کنند؛ در hardware probe ترکیب CPU/GPU benchmark شود.

در دمای بالا اول کیفیت blur/glow و نرخ segmentation کاهش یابد، سپس gesture/pose؛ رندر آخرین اولویت کاهش است. اگر ایمنی دستگاه/سیستم توقف خواست، session gracefully pause شود. hidden screen هیچ inference فعال نداشته باشد. در lifecycle توقف، camera، taskها، executor، textures، EGL surface و display listener آزاد شوند. refresh مجوز نباید UI thread یا render thread را بلوکه کند.

## ۱۶. نمایشگر و پروژکتور

| کلاس Dart | متدهای مهم |
|---|---|
| `ProjectorService` | `inspect(),connect(id),disconnect(),startCalibration(),saveCalibration(),watchStatus()` |
| `ProjectorController` | `refreshDisplays(),selectDisplay(),showTestPattern(),setMargins(),confirm(),retry()` |
| `ProjectorSettingsScreen,ProjectorCalibrationScreen` | الگوی تست، نسبت تصویر، حاشیه امن، mirror و تأیید |

نمایشگر مستقل از طریق `DisplayManager` و `Presentation` فقط وقتی Android واقعاً display مناسب ارائه کند [م۲]. اتصال USB-C به‌تنهایی تضمین خروجی ویدئو نیست. مدل دقیق گوشی، DisplayPort Alt Mode/خروجی پشتیبانی‌شده، آداپتور، همزمانی شارژ و پروژکتور باید **قبل از خرید و قبل از ساخت عمده پروژه** با دستگاه واقعی بررسی شوند. به‌خصوص نمونه نام Galaxy A54 در متن اولیه دلیل تأیید سخت‌افزار نیست؛ آن را در فهرست تأییدشده قرار ندهید تا تست شود.

پشتیبانی wireless در MVP «بهترین تلاش» است. mirroring ساده صفحه گوشی، خروجی مستقل نیست و نباید به‌عنوان تحقق secondary display پذیرفته شود. اگر دستگاه فقط mirror دارد، محصول به‌صورت استاندارد اجازه نمایش اپ متصدی روی پرده نمی‌دهد؛ حالت نمایشی محدود با UI مشتری روی هر دو صفحه فقط با انتخاب آگاهانه متصدی و بدون بازکردن پین/ادمین روی پرده قابل استفاده است. Bluetooth برای این مسیر ویدئو استفاده نشود.

رندر یک scene به surface گوشی و surface خارجی با EGL context مشترک؛ دو camera یا دو inference pipeline نسازید. روی گوشی monitoring کوچک و اطلاعات فنی؛ روی نمایشگر فقط صحنه مشتری. برای HUD فارسی پروژکتور از Android text layout و فونت bundled استفاده شود؛ متن را glyphبه‌glyph با shader رسم نکنید. native viewهای HUD روی surface رندر لایه‌بندی و روی سخت‌افزار تست شوند. خروجی preview داخل Flutter Texture است.

عدم اتصال نمایشگر در ورود به Customer Mode → صفحه setup و دکمه «آزمایش روی گوشی». قطع کابل حین جلسه → pause و پاک‌کردن scene، اتصال مجدد → تأیید و جلسه تازه. نمایشگر خارجی در اپ متصدی فقط صفحه خنثی برند دارد. وضوح output مستقل از inference است؛ scaling باید aspect را حفظ کند و به‌صورت پیش‌فرض fit/letterbox با حاشیه امن ۵٪ باشد.

## ۱۷. تم و تجربه فارسی

### هویت بصری پیشنهادی

ظاهر فروشگاهی آرام و مدرن؛ مود متصدی روشن برای خوانایی فرم‌ها، مود مشتری تیره برای برجسته‌کردن دوربین و لباس. تم ادمین روشن، با همان اجزای مشترک و بدون رنگ برند فروشگاه. انتخاب خودکار theme از سیستم در MVP خاموش است تا ظاهر نصب ثابت بماند. رنگ برند فروشگاه فقط accentهای مجاز را تغییر دهد، نه رنگ خطر/موفقیت و متن خوانا.

| توکن | مقدار پیشنهادی |
|---|---|
| پس‌زمینه متصدی | `#F7F7FA` |
| سطح کارت روشن | `#FFFFFF` |
| متن اصلی روشن | `#18212F` |
| متن ثانویه روشن | `#596579` |
| رنگ اصلی | `#6554C0` |
| رنگ روی primary | `#FFFFFF`؛ هنگام سفارشی‌سازی contrast دوباره کنترل شود |
| رنگ دوم | `#2DD4BF`؛ متن روی آن تیره |
| پس‌زمینه مشتری | `#10131A` |
| سطح HUD | `#161D29` با opacity قابل تنظیم برای خوانایی |
| موفقیت | `#157347` |
| هشدار | `#8A5700` |
| خطر | `#B42318` |
| فاصله‌ها | ۴، ۸، ۱۲، ۱۶، ۲۴، ۳۲، ۴۸ logical px |
| شعاع | ورودی ۱۲، کارت ۱۶، sheet بیست، chip هشت |
| ارتفاع لمس | حداقل ۴۸؛ دکمه اصلی ۵۲ |
| متن اپ | body شانزده، label چهارده، caption دوازده، title بیست، heading بیست‌وچهار |
| وزن فونت | متن ۴۰۰، label پانصد، heading هفتصد؛ فونت دارای مجوز همراه برنامه |
| انیمیشن UI | ۱۵۰–۲۲۰ms؛ transition لباس ۶۵۰ms |

نسبت کنتراست متن عادی حداقل ۴٫۵:۱ و متن بزرگ ۳:۱ هدف طراحی باشد؛ روی تصویر زنده باید backing panel داشته باشد. ظاهر نهایی روی پروژکتور واقعی، نور فروشگاه و فاصله مشتری بررسی شود. مشتری در فاصله چندمتری متن ۱۲px نمی‌خواند؛ HUD با ارتفاع تصویر scale شود: متن راهنما حدود ۳٪ ارتفاع، قیمت حدود ۴٪، سقف و کف کالیبره. رنگ و شکل/متن باهم وضعیت را منتقل کنند، صرف سبز/قرمز کافی نیست.

### فارسی، عدد و راست‌به‌چپ

- فقط `supportedLocales=[Locale('fa','IR')]`؛ بدون منوی زبان. فایل متن مرکزی فارسی برای حفظ یکدستی، نه سیستم ترجمه چندزبانه سنگین.
- همه paddings و alignment با `Directional`/`start,end`؛ آیکون بازگشت متناسب RTL. آیکون‌های camera/play/thumb صرفاً به‌دلیل RTL mirror نشوند.
- شماره درخواست، OTP، barcode، URL و شناسه‌ها در جزیره `Directionality.ltr` داخل صفحه RTL؛ cursor و ترتیب ارقام خراب نشود.
- اعداد نمایشی فارسی، ورودی فارسی/عربی/لاتین normalize شود؛ ذخیره عدد JSON واقعی یا رشته ASCII. OTP رشته است تا صفر اول حفظ شود.
- قیمت «۴٬۸۹۰٬۰۰۰ تومان»؛ `IRR` را در UI نشان ندهید. تبدیل ریال و تومان فقط هنگام اتصال به سامانه‌ای با واحد متفاوت و به‌صورت صریح.
- جست‌وجو `ی/ي` و `ک/ك` و فاصله/نیم‌فاصله را normalize کند؛ متن اصلی کاربر برای نمایش حفظ شود.
- تاریخ UI شمسی، تاریخ DB میلادی UTC؛ دو تاریخ محلی مبهم وارد API نشود. فیلد «سال مد» به‌صورت مشخص «سال میلادی» است تا ۲۰۲۶ با ۱۴۰۵ مخلوط نشود.
- label همیشه بالای ورودی باشد، نه فقط placeholder. keyboard عددی برای قیمت/OTP/PIN. متن خطا زیر همان فیلد و خلاصه خطا در submit.
- fontScale تا ۱٫۵ در فرم‌ها بدون بریدگی؛ scroll و keyboard inset رعایت شود. فرم روی عرض ۳۶۰dp قابل استفاده باشد.

### نقشه صفحات و رفتار

| صفحه | چیدمان و رفتار دقیق |
|---|---|
| شروع | لوگو و وضعیت کوتاه «در حال بررسی مجوز»؛ timeout و retry؛ spinner بی‌پایان ممنوع |
| فعال‌سازی | عنوان، کد درخواست بزرگ، دکمه کپی، مدل دستگاه، شش رقم OTP، زمان باقی‌مانده، وضعیت اینترنت |
| ورود متصدی | پین با نمایش پوشیده و پیام lockout؛ خروج سریع به مشتری |
| خانه متصدی | تعداد لباس آماده/پیش‌نویس، دکمه اصلی افزودن، شروع مشتری، وضعیت نمایشگر/مجوز |
| کاتالوگ | جست‌وجو بالا؛ دو ستون thumbnail در گوشی عادی، قیمت و badge آمادگی؛ filter sheet |
| ثبت عکس | stepper چهار زاویه، guide متناسب دسته، thumbnail کوچک عکس‌های قبلی، دکمه بزرگ شاتر |
| بررسی عکس | تمام تصویر، هشدارهای مشخص، «عکس دوباره» و «تأیید»؛ override در action ثانویه |
| بررسی AI | گروه‌های نوع و رنگ، استایل، کاربرد، مد، سفارشی؛ badge منبع؛ sticky ذخیره و شمار خطا |
| ویرایش anchor | تصویر قابل zoom، نقطه فعال با نام فارسی، undo/reset؛ تأیید قبل از انتشار |
| اطلاعات تجاری | قیمت/تخفیف/موجودی مستقل از AI؛ واحد تومان ثابت |
| وضعیت job | مرحله فعلی، امکان خروج امن و ادامه بعدی، retry مرحله شکست‌خورده |
| تنظیمات | برند، نمایشگر، آموزش، امنیت متصدی، مجوز، diagnostics؛ تنظیمات پیشرفته جمع‌شونده |
| انتظار مشتری | زمینه آرام برند، راهنمای ایستادن، اطلاع کوتاه ذخیره‌نشدن تصویر |
| نمایش لباس | بدن وسط، قیمت پایین سمت راست خارج بدن، نام کوتاه، راهنمای دو ژست پایین، feedback گذرا |
| پایان مجموعه | «همه مدل‌ها را دیدید»؛ پسندیده‌ها و شروع دوباره |
| نظارت روی گوشی | preview کوچک، لباس فعلی، اتصال، زمان جلسه و FPS با disclosure؛ pause و خروج با پین |
| ادمین | صفحه اصلی با آمار، درخواست‌ها، دستگاه‌ها، فروشگاه‌ها؛ جست‌وجو و فیلتر وضعیت |

در مود مشتری تغییر لباس تمام صفحه را flash نکند. glow کم‌نور پیرامون contour باشد؛ طی ۲۰۰ms fade-out، ۲۵۰ms glow و ۲۰۰ms fade-in؛ حالت reduced motion فقط crossfade حدود ۲۰۰ms. نمایش پسند/رد با نوشته و آیکون کوتاه، نه emoji وابسته به فونت دستگاه. صدای بازخورد پیش‌فرض خاموش، با گزینه متصدی. انتخاب مجموعه در شروع را متصدی می‌تواند از قبل تعیین کند؛ اگر مشتری باید انتخاب کند، گزینه‌ها روی گوشی قابل لمس باشند و flow ژست انتخاب مجموعه جدا تعریف شود؛ 👍/👎 را همزمان رأی لباس و انتخاب منو تلقی نکنید.

## ۱۸. کلاس‌های اپ Super Admin

هر feature دارای repository interface کوچک و `...RepositoryImpl` متصل به `AdminApiClient` است؛ domain models مشترک از package استفاده می‌شوند. صفحه‌ها فقط controller همان feature را صدا بزنند.

| کلاس | متدهای مهم |
|---|---|
| `AdminApiClient` | `request<T>(),cancel()` |
| `AdminAuthInterceptor` | `attach(),refreshOnce(),onRevoked()` |
| `AdminTokenStore` | `save(),read(),clear()`؛ refresh token در secure storage |
| `AdminAuthRepository` | `login(username,password),verifyMfa(challenge,code),refresh(),logout(),getProfile()` |
| `AdminAuthController` | `submitCredentials(),submitMfa(),unlockBiometric(),logout()` |
| `AdminDashboardRepository` | `getSummary():F<DashboardSummary>` |
| `DashboardController` | `load(),refresh()` |
| `AdminActivationRepository` | `listPending(query),get(id),approve(id,storeId),reject(id,reason),issueOtp(id),unlock(id,reason)` |
| `ActivationReviewController` | `load(),selectStore(),approve(),reject(),generateOtp(),clearOtpFromMemory()` |
| `AdminDeviceRepository` | `list(query),get(id),suspend(id,reason),resume(id),revoke(id,reason),requestPinReset(id)` |
| `DeviceListController` | `load(),filter(),search(),loadMore()` |
| `DeviceDetailController` | `load(),suspend(),resume(),revoke(),issuePinReset(),viewLogs()` |
| `AdminStoreRepository` | `list(),get(id),create(input),update(id,input,version),setLimit(id,max)` |
| `StoreAdminController` | `load(),save(),changeMaxDevices(),deactivate()` |
| `AdminLicenseRepository` | `get(id),changeExpiry(id,date?),setFeatures(id,features),prepareTransfer(oldId),confirmTransfer()` |
| `LicenseAdminController` | `load(),setExpiry(),setFeatures(),transfer()` |
| `AdminAuditRepository` | `list(filters,cursor),get(id)`؛ هیچ delete در API اپ نیست |
| `AuditLogController` | `load(),filter(),loadMore()` |
| `AdminSettingsRepository` | `getPolicy(),updatePolicy(policy,version)` |
| `AdminSettingsController` | `load(),validate(),save()` |
| `AdminLoginScreen,MfaScreen,DashboardScreen,PendingActivationsScreen,ActivationDetailScreen,OtpRevealSheet,DeviceListScreen,DeviceDetailScreen,StoreListScreen,StoreEditorScreen,LicenseEditorScreen,AuditLogScreen,AdminSettingsScreen` | view با فرم/جدول responsive و stateهای loading/error/empty |

ورود سرور با password قوی و TOTP MFA در انتشار واقعی اجباری؛ biometric صرفاً بازکردن محلی session معتبر است و جای MFA سرور نیست. access token ده دقیقه، refresh هفت روز با rotation و reuse detection؛ logout و compromise همه refreshهای session را invalidate کند. ادمین خاموش/حذف‌شده فوراً در API بررسی شود. seed رمز ثابت production ممنوع؛ bootstrap ادمین با فرمان یک‌بارمصرف محیط امن.

تولید OTP با تأیید فروشگاه، مدل، request code و بخشی از fingerprint انجام شود. OTP بعد از ۶۰ ثانیه یا background از حافظه UI پاک شود، گرچه اعتبار سرور پنج دقیقه است. کپی OTP فقط اقدام صریح؛ clipboard خودکار پر نشود. صفحه OTP/PIN screenshot مجاز نداشته باشد، با درنظرگرفتن سازگاری نمایشگر خارجی و scope window. revoke و انتقال نیاز به تأیید، دلیل و نمایش پیام تأخیر آفلاین دارند. suspend قابل برگشت، revoke قطعی.

## ۱۹. کلاس‌های بک‌اند

فایل‌ها در هر ماژول به الگوی `*.controller.ts`, `*.service.ts`, `*.repository.ts`, `dto/*.dto.ts` و `*.module.ts` تقسیم شوند. کلاس Module فقط wiring و export است. DTOهای request/response برای هر endpoint بخش ۲۱ تولید/تعریف شوند؛ validation جدا از entity Prisma. controller منطق امنیت یا SQL نداشته باشد.

| ماژول | کلاس | متدهای مهم |
|---|---|---|
| config | `EnvironmentConfig` | `load(),validate()`؛ نبود secret fail-fast |
| common/clock | `ServerClock` | `now(),unixSeconds()` |
| common/auth | `AdminAuthGuard` | `canActivate(context)`؛ JWT + وضعیت session + نقش |
| common/auth | `DeviceAuthGuard` | `canActivate(context)`؛ audience دستگاه و license فعال |
| common/auth | `StoreScopeGuard` | `assertScope(principal,resourceStoreId)` |
| common/auth | `FeatureGuard` | `assertEnabled(principal,feature)` |
| common/auth | `DeviceProofService` | `issueChallenge(),verifyAndConsume(),canonicalize()` |
| common/errors | `ApiExceptionFilter` | `catch(error)`؛ envelope ثابت |
| common/logging | `AuditRedactor` | `sanitize(event),assertNoSecrets()` |
| common/idempotency | `IdempotencyService` | `begin(scope,key,hash),complete(response),replay(),expire()` |
| admin-auth | `AdminAuthService` | `verifyPassword(),beginMfa(),completeMfa(),rotateRefresh(),logout(),revokeSessions()` |
| admin-auth | `PasswordService` | `hash(),verify(),needsRehash()`؛ Argon2id با پارامتر benchmark‌شده |
| admin-auth | `TotpService` | `enroll(),confirmEnrollment(),verify(),consumeRecoveryCode()` |
| admin-auth | `AdminAuthRepository` | `findUser(),saveSession(),rotateSessionAtomic(),invalidateSessions()` |
| stores | `StoresService` | `create(),update(),get(),list(),setMaxDevices(),disable()` |
| stores | `StoresRepository` | `find(),insert(),updateIfVersion(),lockForDeviceQuota()` |
| activations | `ActivationService` | `create(),getForDevice(),approve(),reject(),expireRequests(),redeem()` |
| activations | `ActivationOtpService` | `issue(),verifyAttemptAtomic(),invalidatePrevious(),lockRequest()` |
| activations | `ActivationRepository` | `findPending(),reserveSlot(),consumeOtpAndIssueLicense(),markExpired()` |
| activations | `ActivationRateLimiter` | `checkCreate(),checkOtp(),checkAdminIssue()`؛ Redis shared counters |
| devices | `DevicesService` | `list(),get(),suspend(),resume(),revoke(),issuePinReset(),recordSeen()` |
| devices | `DeviceRepository` | `findByInstallation(),updateStatusIfVersion(),countReservedAndActive()` |
| licenses | `LicenseService` | `issue(),renew(),evaluateEntitlement(),changeFeatures(),changeExpiry(),transfer()` |
| licenses | `LicenseSigningService` | `signLease(),signStatus(),signPinReset(),activeKeyId()`؛ KMS/secret provider |
| licenses | `LicenseRepository` | `get(),save(),incrementVersion(),findExpired()` |
| licenses | `SigningKeyProvider` | `getActiveSigner(),getPublicKeySet(),rotate()` |
| schemas | `SchemaService` | `getEffective(),addField(),updateField(),disableField(),validateChange(),snapshot()` |
| schemas | `SchemaRepository` | `getVersion(),appendVersionAtomic(),getSnapshot()` |
| schemas | `PromptBuilder` | `buildBase(),appendSchemaData(),appendCustomFieldData(),buildRequest()` |
| schemas | `AnalysisSchemaCompiler` | `compile(snapshot),validatePayload(),rejectUnknownKeys()` |
| uploads | `UploadService` | `initiate(),confirm(),validateObject(),issueReadUrl(),expireUnused()` |
| uploads | `ObjectStorageService` | `presignPut(),presignGet(),head(),delete(),copy()`؛ bucket خصوصی |
| processing | `ProcessingService` | `createJob(),getJob(),cancel(),retry(),applyStageResult()` |
| processing | `ProcessingRepository` | `insert(),claimStage(),updateIfVersion(),markComplete(),listStuck()` |
| processing | `ProcessingQueue` | `enqueue(),scheduleRetry(),cancel(),deadLetter()` |
| processing | `ProcessingOrchestrator` | `runPipeline(),runVision(),runAnalysis(),packageResult(),cleanup()` |
| processing | `VisionWorkerClient` | `process(input):P<VisionResult>`, `cancel(jobId)` |
| processing | `GarmentAiProvider` | interface: `analyze(request):P<ProviderResult>` |
| processing | `ConfiguredGarmentAiProvider` | پیاده‌سازی provider انتخاب‌شده؛ timeout/token limit/usage |
| processing | `GarmentAnalysisService` | `analyze(),validateResponse(),repairOnce(),persistProvenance()` |
| processing | `AssetManifestService` | `build(),validateHashes(),signDownloadManifest()` |
| audit | `AuditService` | `append(event),list(filter),get(id)`؛ append-only |
| audit | `AuditRepository` | `insert(),selectPage()`؛ role DB بدون update/delete عادی |
| dashboard | `DashboardService` | `counts(),recentActivity()`؛ داده aggregate واقعی |
| settings | `LicensePolicyService` | `get(),validate(),updateWithVersion()` |
| health | `HealthService` | `liveness(),readiness()`؛ readiness وابستگی DB/Redis |

کنترلرهای لازم: `AdminAuthController,StoresController,DeviceActivationController,AdminActivationController,DevicesController,DeviceLicenseController,AdminLicenseController,SchemasController,UploadsController,ProcessingController,AuditController,DashboardController,SettingsController,HealthController`. هر handler نام معنایی متناظر endpoint دارد و به سرویس هم‌نام delegate می‌کند.

کارهای زمان‌بندی سرور: انقضای درخواست/رزرو، پاک‌سازی challenge، cleanup فایل upload تأییدنشده، retry jobهای stuck، backup و انقضای refresh. اجرای چند replica نباید job دوره‌ای را دوباره انجام دهد؛ lease/lock یا queue unique key. timestamp تمام auditها از سرور باشد. audit شکست امنیتی هم باید بماند؛ transaction rollback نباید گزارش شکست را محو کند.

## ۲۰. worker پردازش تصویر

| کلاس پایتون | متدهای مهم |
|---|---|
| `JobHandler` | `process(job),validate_contract(),emit_result(),cancel()` |
| `ImageNormalizer` | `decode(),apply_orientation(),strip_metadata(),resize_for_model()` |
| `GarmentSegmenter` | `load_model(),segment(image,category),validate_mask()` |
| `AnchorExtractor` | `extract(mask,image,category),score_anchors(),map_to_output()` |
| `MeasurementEstimator` | `estimate_planar(marker,anchors),mark_unavailable(reason)` |
| `AssetBuilder` | `make_rgba(),crop_with_padding(),make_mask(),build_manifest()` |
| `QualityEvaluator` | `evaluate_mask_edges(),detect_missing_regions(),evaluate_input()` |
| `ObjectStore` | `download_allowed_key(),upload_result(),verify_checksum()` |
| `ModelRegistry` | `load(name,version),verify_sha256(),license_info(),capabilities()` |

انتخاب مدل segmentation لباس یک وابستگی تحقیقاتی واقعی است. MediaPipe person segmentation حذف پس‌زمینه لباس تنها را حل نمی‌کند. قبل از پیاده‌سازی provider، مدل یا سرویس دارای مجوز تجاری و کیفیت لباس آویز/مانکن با مجموعه عکس واقعی انتخاب و در `dependency-lock.md` ثبت شود. بدون این انتخاب، حالت production پردازش آماده نیست؛ mock فقط در dev و با برچسب واضح مجاز است. manual mask correction آینده است؛ در MVP شکست جداسازی باعث درخواست عکس دوباره یا غیرفعال‌ماندن پرو می‌شود، نه mask سفید ساختگی.

استخراج anchor ممکن است تخمینی باشد؛ review دستی در اپ اجباری است تا هر رده آزمون کافی بگیرد. worker فقط آرایه mask/anchor و فایل را تولید می‌کند؛ ساخت اندازه ناموجود یا ساخت mesh سه‌بعدی fake ممنوع. API داخلی worker با mTLS یا service credential کوتاه‌عمر، شبکه خصوصی و محدودیت concurrency. credential به client ارسال نشود. در حالت GPU، حد حافظه و زمان job مشخص باشد؛ retry خطای out-of-memory با ورودی کوچک‌تر فقط در حدود قرارداد کیفیت.

## ۲۱. قرارداد API

پیشوند تمام مسیرها `/v1`. payloadها JSON UTF-8؛ فایل با URL امضاشده. پاسخ خطا: `{error:{code,messageFa,details?,correlationId}}`. مقدار `details` تنها خطای فیلد مجاز، بدون stack/secret. statusها: 400 شکل بد، 401 احراز هویت، 403 عدم مجوز، 404 نبود/خارج scope، 409 conflict نسخه/slot، 422 اعتبارسنجی داده، 429 محدودیت، 503 وابستگی موقت. کلاینت برای 401 فقط یک refresh؛ سپس مسیر ورود/فعال‌سازی مناسب.

| روش و مسیر | دسترسی | ورودی مهم | خروجی |
|---|---|---|---|
| `POST /device/challenges` | bootstrap محدود | purpose,installationId,requestId? | challengeId,nonce,expiresAt |
| `POST /activations` | proof دستگاه | identity,deviceInfo,challenge,signature | activationRequest |
| `GET /activations/:id` | bootstrap token محدود همان درخواست | proof/session bootstrap | وضعیت بدون OTP |
| `POST /activations/:id/redeem` | proof + OTP | otp,challenge,signature؛ header idempotency | signedLease,deviceSession |
| `POST /device/sessions` | proof | challenge,signature,installationId | accessToken,expiresAt |
| `POST /device/license/renew` | device + proof | currentVersion,challenge,signature | signedLease یا signedBlock |
| `POST /admin/auth/login` | عمومی rate limited | username,password | mfaChallenge |
| `POST /admin/auth/mfa` | challenge | code | accessToken,refreshToken,user |
| `POST /admin/auth/refresh` | refresh | refreshToken | rotated tokens |
| `POST /admin/auth/logout` | admin | sessionId | 204 |
| `GET /admin/dashboard` | super admin | — | آمار |
| `GET /admin/activations` | super admin | cursor,status,search | page |
| `GET /admin/activations/:id` | super admin | — | detail |
| `POST /admin/activations/:id/approve` | super admin | storeId,expectedVersion | approved request |
| `POST /admin/activations/:id/otp` | super admin | idempotencyKey | otp یک‌بار،expiresAt |
| `POST /admin/activations/:id/reject` | super admin | reason | status |
| `POST /admin/activations/:id/unlock` | super admin | reason | status |
| `GET /admin/devices` | super admin | filters,cursor | page |
| `GET /admin/devices/:id` | super admin | — | device + license |
| `POST /admin/devices/:id/suspend` | super admin | reason,expectedVersion | status |
| `POST /admin/devices/:id/resume` | super admin | expectedVersion | status |
| `POST /admin/devices/:id/revoke` | super admin | reason,expectedVersion | status + offline delay notice |
| `POST /admin/devices/:id/pin-reset` | super admin | fresh device challenge | signedReset |
| `GET/POST /admin/stores` | super admin | query / store input | page / store |
| `GET/PATCH /admin/stores/:id` | super admin | — / fields,expectedVersion | store |
| `PATCH /admin/licenses/:id` | super admin | expiry,features,expectedVersion | license |
| `POST /admin/licenses/:id/transfer` | super admin | newActivationId,reason | old revoked + request approval |
| `GET /admin/audit` | super admin | storeId,deviceId,action,from,to,cursor | page |
| `GET/PATCH /admin/license-policy` | super admin | — / policy,expectedVersion | policy |
| `GET /store/schema` | device + operator session | — | effective schema |
| `POST /store/schema/changes` | device + operator session | change,expectedVersion | versioned schema |
| `POST /store/operator-session` | device + signed PIN-unlock proof | nonce/signature | کوتاه‌عمر operator session |
| `POST /uploads` | device + operator | file metadata,purpose | uploadId,presignedPut,key |
| `POST /uploads/:id/complete` | همان device | checksum,size | verified asset ref |
| `POST /processing/jobs` | device + operator + feature | draftId,inputRevision,schemaVersion,uploadIds | job |
| `GET /processing/jobs/:id` | همان store/device scope | — | job + result manifest |
| `POST /processing/jobs/:id/cancel` | device + operator | — | status |
| `POST /processing/jobs/:id/retry` | device + operator | expectedRevision | job |
| `GET /health/live` | زیرساخت | — | status |
| `GET /health/ready` | زیرساخت | — | status |

پروتکل operator session: native بعد از PIN صحیح، challenge مخصوص purpose=`operator-unlock` را امضا می‌کند؛ سرور token ده‌دقیقه‌ای scope محدود به همان device/store می‌دهد. این سیاست برای جلوگیری از استفاده عادی UI مشتری است؛ روی APK کاملاً دست‌کاری‌شده به‌تنهایی اثبات انسانی پین نیست. کلید دستگاه فقط برای purposeهای allowlisted sign کند؛ endpoint arbitrary signing در bridge ندهید. در حالت آفلاین ورود پین برای ویرایش محلی مجاز است؛ API نیازمند token آنلاین است.

اطلاعات فروشگاه از principal استخراج شود؛ `storeId` ورودی کاربر مرجع مجوز نیست. session مشتری endpoint ندارد. bootstrap token فقط status درخواست خود را می‌خواند، نه کاتالوگ و نه license. پاسخ ایجاد درخواست از enumeration کدهای دیگر جلوگیری کند؛ lookup عمومی با requestCode ممنوع، فقط ادمین می‌تواند با آن جست‌وجو کند.

نمونه ورودی job:

```json
{
  "draftId": "11111111-1111-4111-8111-111111111111",
  "inputRevision": 3,
  "schemaVersion": 7,
  "category": "top",
  "photos": [
    {"angle": "front", "uploadId": "uploaded-front-id"},
    {"angle": "back", "uploadId": "uploaded-back-id"},
    {"angle": "left45", "uploadId": "uploaded-left-id"},
    {"angle": "right45", "uploadId": "uploaded-right-id"}
  ],
  "measurementMode": "planar-or-unavailable"
}
```

نمونه بالا fixture توضیحی است؛ شناسه‌ها باید واقعاً از upload API به‌دست آیند. مدل حق ندارد این شناسه نمونه را در برنامه production استفاده کند.

### خطاهای دامنه ضروری

کدهای موردنیاز: `NETWORK_UNAVAILABLE,REQUEST_EXPIRED,OTP_INVALID_OR_EXPIRED,OTP_ATTEMPTS_EXCEEDED,DEVICE_LIMIT_REACHED,LICENSE_EXPIRED,LICENSE_REVOKED,LICENSE_SUSPENDED,DEVICE_KEY_MISSING,LICENSE_SIGNATURE_INVALID,CLOCK_UNTRUSTED,OPERATOR_PIN_INVALID,OPERATOR_LOCKED,SCHEMA_VERSION_CONFLICT,FIELD_VALUE_INVALID,ASSET_NOT_READY,ASSET_HASH_MISMATCH,CAMERA_PERMISSION_DENIED,CAMERA_BUSY,DISPLAY_UNAVAILABLE,UNSUPPORTED_DEVICE,TRACKING_UNRELIABLE,PROCESSING_FAILED,INSUFFICIENT_STORAGE,REVISION_CONFLICT`. هرکدام متن فارسی مرکزی، retry policy و مقصد recovery داشته باشند.

## ۲۲. پایگاه داده سرور و یکپارچگی

| جدول | ستون/قید مهم |
|---|---|
| `admin_users` | id، username/email unique، passwordHash، encryptedTotpSecret، status، role |
| `admin_sessions` | userId، refreshHash، familyId، rotatedAt، revokedAt، expiresAt |
| `admin_recovery_codes` | userId، codeHash، usedAt؛ raw فقط لحظه تولید |
| `stores` | id، name، branch، city، maxDevices، status، version |
| `activation_requests` | id، requestCode، installationId، publicKeySpki، publicKeyHash، status، storeId، version، timestamps |
| `activation_otps` | requestId، otpVersion، otpDigest، expiresAt، attempts، lockedAt، usedAt |
| `device_slot_reservations` | requestId unique، storeId، expiresAt؛ در transaction ظرفیت بررسی شود |
| `devices` | id، installationId unique، publicKeyHash، storeId، status، version، lastSeen |
| `licenses` | id، deviceId، status، entitlementExpiresAt nullable، features JSON، licenseVersion، revokeReason |
| `device_challenges` | id، nonceHash، purpose، installationId، expiresAt، consumedAt |
| `idempotency_records` | unique(scope,key)، requestHash، responseEncrypted/responseRef، expiresAt |
| `schema_versions` | unique(storeId,version)، snapshot JSON، actorId، createdAt |
| `upload_objects` | id، storeId، deviceId، objectKey unique، checksum، status، expiresAt |
| `processing_jobs` | id، ownerDeviceId، storeId، inputRevision، schemaVersion، stage، status، resultRef، version |
| `processing_stage_runs` | unique(jobId,stage,attempt)، startedAt، endedAt، safeError |
| `audit_events` | append-only، actor، action، correlationId، indexed createdAt/storeId/deviceId |
| `license_policy` | singleton versioned، policy JSON، updatedBy |

رکورد OTP و redeem با row lock یا isolation مناسب و قید unique انجام شوند. بررسی ظرفیت با count بیرون transaction race دارد؛ رکورد store قفل و ظرفیت active+reserved محاسبه شود. state transition دستگاه در سرویس کنترل شود؛ API patch دلخواه status وجود نداشته باشد. licenseVersion همیشه افزایشی و server-controlled است.

داده AI پیشنهاد است؛ رکورد تأییدشده لباس محلی سرور اصلی کاتالوگ ندارد. manifest پردازش و schema سرور ذخیره می‌شوند؛ cloud backup آینده نباید بی‌خبر به sync چنددستگاهی تبدیل شود. حذف فروشگاه با دستگاه/مجوز فعال hard delete نشود؛ deactivate با حفظ audit. retention پیشنهادی فایل خام پردازش ۳۰ روز، نتیجه ۹۰ روز، audit یک سال قابل تنظیم؛ متصدی از حذف ابری آگاه باشد و دارایی‌های محلی آماده مستقل باقی بمانند.

## ۲۳. تنظیمات و عملیات انتشار

متغیرهای محیط سرور: `DATABASE_URL,REDIS_URL,OBJECT_STORAGE_ENDPOINT,OBJECT_STORAGE_BUCKET,OBJECT_STORAGE_ACCESS_KEY,OBJECT_STORAGE_SECRET_KEY,LICENSE_SIGNING_KEY_REF,OTP_PEPPER_REF,ADMIN_JWT_KEY_REF,AI_PROVIDER,AI_API_KEY_REF,VISION_WORKER_URL,VISION_WORKER_AUTH_REF`. suffix `REF` اشاره به secret manager یا mount امن دارد. مقادیر واقعی در git، image Docker، لاگ و APK قرار نگیرند.

متغیرهای public اپ: `API_BASE_URL,ENVIRONMENT,LOG_LEVEL,APP_BUILD_CHANNEL`. key عمومی verify license راز نیست ولی integrity و نسخه آن حیاتی است. buildهای dev/staging/prod جدا با applicationId مجزا؛ test license در production پذیرفته نشود. seed mock و fake engine فقط flavor dev؛ انتخاب fake با remote setting تولیدی ممنوع.

مجوزهای Android: camera و internet و network state؛ microphone/location/contacts/storage-wide درخواست نشود. تصاویر private هستند؛ برای export مشخص از system picker استفاده شود. wake lock/keep-screen-on فقط مود فعال و با آزادسازی مناسب. ضبط ویدئو و audio از مشتری وجود ندارد. دوربین background خاموش؛ foreground service دائمی برای دورزدن lifecycle نسازید.

الزام kiosk: پین اپ فقط بخش تنظیمات را محافظت می‌کند، خروج از سیستم‌عامل را مسدود نمی‌کند. برای MVP screen pinning اختیاری و راهنمای اپراتور؛ kiosk سخت و Device Owner/MDM خارج MVP. کلید امضای APK و backup آن باید نزد مالک حفظ شود؛ گم‌شدن آن به نصب مجدد/فعال‌سازی دوباره منجر می‌شود. مجوز تجاری فونت، مدل، کتابخانه و assets ثبت شود.

مانیتورینگ: نرخ شکست activation و OTP، مدت job، هزینه AI به‌ازای job، صف dead-letter، آخرین backup موفق، license renew failures و worker GPU memory. هیچ عکس مشتری، OTP، پین، token یا prompt حاوی secret به crash report نرود. diagnostics گوشی فقط روی اقدام صریح متصدی export شود. metrics مشتری اگر بعداً فعال شد فقط شمار کل و بدون sessionId پایدار/تصویر/بردار ترجیح.

پشتیبان سرور: backup رمزگذاری‌شده DB و نسخه‌بندی object storage؛ restore واقعی در staging آزمایش شود. توقف AI نباید Customer Mode با assets موجود را متوقف کند. قطع backend فقط طبق lease روی اجرا اثر دارد. secret rotation، بازنشانی ادمین، lost-device، clock anomaly، worker stuck و کمبود فضای گوشی در `operations.md` runbook داشته باشند.

## ۲۴. دروازه‌های فنی و آزمون پذیرش

این پروژه دو عدم‌قطعیت مهم دارد: سخت‌افزار نمایش و کیفیت پرو. اجرای طولانی و معیارهای زیر روی دستگاه تأییدشده لازم است؛ emulator و mock اثبات آن نیستند. عددهای این بخش هدف قرارداد پیشنهادی‌اند، نه اندازه‌گیری انجام‌شده.

### دروازه صفر: امکان‌پذیری قبل از ساخت عمده

۱. گوشی واقعی + پروژکتور + آداپتور/دانگل + شارژ همزمان؛ نمایش مستقل و camera front همزمان کار کنند. نتیجه با مدل دقیق و نسخه OS در hardware matrix ثبت شود.

۲. دوربین → pose → overlay یک لباس → نمایشگر، یک جلسه ۳۰دقیقه‌ای. هدف FPS خروجی حداقل ۲۴ پایدار و latency تصویر تا نمایش P95 زیر ۲۰۰ms. latency دوربین تا پرده فقط از timestamp نرم‌افزار معلوم نمی‌شود؛ فیلم‌برداری مقایسه‌ای پرسرعت یا روش نوری معتبر لازم است.

۳. حداقل ۲۰ لباس واقعی با رنگ روشن/تیره، طرح، آستین و پس‌زمینه متنوع؛ mask و anchor روی نمونه‌ها بررسی شوند. ده نمونه ثبت‌شده باید پس از اصلاح دستی با کیفیت بصری مورد قبول مالک پرو شوند. شکست این دروازه نیازمند کاهش دامنه یا تغییر pipeline است، نه زیباسازی UI.

### آزمون امنیت و داده

- OTP اشتباه، منقضی، استفاده‌شده، دستگاه دیگر، request دیگر، همزمانی دو redeem و از‌دست‌رفتن پاسخ.
- دو درخواست همزمان برای آخرین slot؛ فقط یک فعال‌سازی موفق.
- token با signature خراب، `alg=none`، audience غلط، keyId ناشناخته، کلید دستگاه گم‌شده و replay challenge.
- کپی فایل‌ها به گوشی دیگر، restore backup، clear data، reinstall، آپدیت APK با کلید امضای همان نسخه.
- قطع اینترنت پس از revoke مشاهده‌شده؛ برگشت به lease فعال قبلی ممنوع.
- حالت permanent entitlement ولی lease منقضی؛ عقب/جلو بردن ساعت، reboot و clockUntrusted.
- انتقال دستگاه و هشدار overlap آفلاین؛ suspend/resume با version جدید.
- ورودی custom شامل دستور مخرب، فیلد ناشناخته، type اشتباه، پاسخ AI بیش‌ازحد بلند.
- نتیجه job قدیمی بعد از ویرایش متصدی؛ مقادیر confirmed حفظ شوند.
- migration از هر نسخه پشتیبانی‌شده، crash میان دانلود و DB، فایل خراب و کمبود فضا.
- cross-store ID access برای schema/job/upload/device؛ پاسخ باید منع شود.

### آزمون تجربه مشتری و رندر

- ورود/خروج یک نفر، عبور رهگذر، دو نفر در تصویر و تعویض مشتری؛ بردار ترجیح منتقل نشود.
- نگه‌داشتن 👍 ده ثانیه فقط یک رأی؛ دو دست متناقض رأی ندهند؛ gesture دیررس جلسه قبلی رد شود.
- نمایش هر لباس حداکثر یک‌بار تا پایان مجموعه؛ برخورد با کاتالوگ صفر/یک/سه لباس.
- front camera mirror، چرخش گوشی، aspectهای ۱۶:۹ و ۴:۳، crop و متن فارسی پروژکتور.
- کابل قطع/وصل، permission رد/لغو، background/foreground، camera busy، thermal throttling.
- هدف پاسخ transition برای asset آماده P95 زیر ۹۰۰ms؛ hold ژست در این زمان حساب نشود.
- هدف دقت ژست در محیط آزمون ≥۹۰٪ اقدام‌های عمدی و حداکثر یک رأی کاذب در ده دقیقه حرکات عادی؛ سناریو و شمار نمونه ثبت شود.
- هدف لنگر شانه در حرکت آرام، خطای میانه کمتر از ۵٪ عرض شانه در ویدئوی ارزیابی؛ اگر mask/لباس زیرین بد است قبولی عددی جای قضاوت بصری را نگیرد.
- آزمون کارکرد دو ساعت بدون crash و رشد مستمر حافظه؛ تکرار حداقل صد session و بررسی آزادشدن منابع.

### آزمون فارسی و UI

- عرض ۳۶۰dp، متن بزرگ، keyboard، عدد فارسی/عربی، قیمت طولانی، اسم لباس طولانی، رشته LTR داخل RTL.
- OTP با صفر اول، paste شش رقم، clipboard، صفحه قفل و خطاهای سمت سرور فارسی.
- متن و قیمت روی پرده از محل ایستادن مشتری خوانا؛ هیچ تنظیمات یا پین روی پرده دیده نشود.
- loading، empty، partial failure، offline و retry برای تک‌تک صفحه‌های جدول بخش ۱۷.

### تست خودکار ارزشمند

تست واحد برای reducer جلسه، gesture gating، recommendation deterministic، merge مقدار تأییدشده، schema migration، اعتبارسنجی license/time و policy ظرفیت. تست integration سرور با DB/Redis واقعی برای transaction OTP/slot/idempotency. fixture رمزنگاری مشترک بین Kotlin و بک‌اند. تست migration DB با دیتای نسخه قبل. تست widget محدود به RTL/ورودی پین/فرم پویا. screenshot همه رنگ‌های دکمه یا تستی که صرفاً getter را تکرار کند لازم نیست.

## ۲۵. بسته‌های پیاده‌سازی برای مدل سبک‌تر

کل سند یک‌باره با دستور «همه را بساز» به مدل داده نشود. هر بسته زیر خروجی مستقل و معیار خاتمه دارد. مدل باید در هر بسته ابتدا فایل‌های موجود را بخواند، فقط همان دامنه را تغییر دهد و وضعیت واقعی آزمون را گزارش کند. جدول ترتیب ساخت اولیه کارفرما را اصلاح می‌کند: آزمایش رندر/پروژکتور قبل از صرف هزینه زیاد برای سامانه مدیریتی.

| بسته | دامنه و فایل‌های اصلی | خروجی قابل قبول |
|---|---|---|
| ۰۰ | docs، hardware probe، قفل dependency | ماتریس سخت‌افزار و گزارش واقعی سه دروازه؛ نبود hardware با وضعیت «آزموده‌نشده» |
| ۰۱ | workspace، packages/domain_models، contracts | مدل‌های پایه، JSON schema و OpenAPI معتبر؛ codegen تکرارپذیر |
| ۰۲ | design_system و پوسته دو app | RTL، فونت محلی، routeها، stateهای پایه؛ بدون API جعلی پنهان |
| ۰۳ | backend config، Prisma، auth، stores، audit | راه‌اندازی local، migration و ورود ادمین MFA، scope enforcement |
| ۰۴ | device key، challenge، activation، OTP، lease | جریان کامل درخواست تا مجوز با تست replay/race/copy |
| ۰۵ | اپ ادمین activation/devices/license | approve، OTP، suspend/revoke و audit قابل استفاده |
| ۰۶ | guard اپ فروشگاه، پین و onboarding | هیچ ورود بدون lease؛ grace و clock policy؛ setup فارسی |
| ۰۷ | دیتابیس کاتالوگ و مدیریت asset | CRUD، draft، atomic storage، migration؛ قیمت و موجودی |
| ۰۸ | tutorial، capture، quality، marker، review | چهار زاویه واقعی، override معنادار، اندازه null/دستی صحیح |
| ۰۹ | schema، فرم پویا، custom fields | تمام typeها، version conflict، حذف محلی/آینده، confirmed protection |
| ۱۰ | upload/job/AI/vision worker | خروجی schema-valid، mask واقعی، anchor review و retry |
| ۱۱ | native engine production | lifecycle، transforms، smoothing، deform mesh، display و HUD |
| ۱۲ | session/gesture/recommendation/prefetch | reducer پایدار، عدم رأی تکراری، انتخاب متنوع و cleanup |
| ۱۳ | جلوه‌ها و تنظیمات نمایشگر | glow، transition، reduced motion و calibration |
| ۱۴ | امنیت انتشار، diagnostics، آزمون نهایی | signed APKها، restore drill، soak test و گزارش محدودیت‌های باقی‌مانده |

بسته ۰۰ می‌تواند spike موقتی کوچک باشد؛ خروجی throwaway آن وارد production نشود مگر پس از بازبینی. اگر استفاده از AI provider یا مدل segmentation هنوز تعیین نشده، package ۱۰ blocked واقعی است؛ مدل باید adapter و قرارداد را بسازد ولی حق ندارد با تصویر placeholder وضعیت ready اعلام کند. قابلیت cloud backup/analytics/mesh3D/QR/offline activation/roles بیشتر هیچ بسته MVP ندارند و در این چرخه اجرا نشوند.

### متن راه‌انداز برای مدل پیاده‌ساز

متن زیر را همراه همین فایل و شماره بسته موردنظر بدهید:

> این سند قرارداد اصلی پروژه است. در این نوبت فقط بسته شماره [شماره بسته] را پیاده‌سازی کن. قبل از تغییر، فایل‌های موجود و `docs/implementation-status.md` را بخوان. نام کلاس‌ها و متدهای عمومی و stateها را مطابق سند نگه دار. هر تغییر قرارداد را صریح گزارش کن؛ بی‌خبر معماری عوض نکن. منطق دامنه را از UI جدا کن. خروجی fake، TODO و متد خالی را قابلیت تکمیل‌شده اعلام نکن. برای وابستگی فاقد دسترسی یا سخت‌افزار آزمایش‌نشده، محدودیت واقعی را ثبت کن. آزمون‌های مربوط به ریسک همین بسته را اجرا کن. در پایان فایل‌های تغییرکرده، فرمان‌های اجراشده، نتایج و موارد باقی‌مانده را بنویس. رابط فقط فارسی است، نام کد انگلیسی است. اطلاعات امنیتی را log نکن و تصاویر مشتری را ذخیره/ارسال نکن.

### قالب وضعیت اجباری هر بسته

فایل وضعیت شامل `packageId,status,completedContracts,changedFiles,commandsRun,testResults,hardwareUsed,knownLimitations,nextPackage` باشد. مقدار status فقط `not_started,in_progress,blocked,implemented_unverified,verified`. اگر build اجرا نشده، «verified» ممنوع. معیارهای acceptance از این سند ارجاع داده شوند؛ تعداد فایل تولیدشده معیار پایان نیست.

## ۲۶. نگاشت نیازمندی‌های اولیه به این سند

| بندهای متن اولیه | پوشش در این سند |
|---|---|
| ۱–۴ و ۱۲۰–۱۲۴ و ۱۳۹ و ۱۴۱ | بخش‌های ۱ تا ۶، ۱۴، ۱۸ تا ۲۳ |
| ۵–۱۳، ۳۳–۳۵، ۱۳۱ و ۱۳۶ | بخش‌های ۹، ۱۱، ۱۲، ۱۵، ۲۰ و آزمون‌ها |
| ۱۴–۳۲، ۵۹–۶۰، ۱۱۹ و ۱۳۲ | بخش‌های ۵، ۱۰، ۱۱، ۱۹ و ۲۱ |
| ۳۶–۵۸، ۶۱، ۱۲۱، ۱۳۳–۱۳۴، ۱۳۷–۱۳۸ | بخش‌های ۱۳ تا ۱۷ و ۲۴ |
| ۶۲–۱۱۸، ۱۲۵–۱۲۸، ۱۳۰ و ۱۳۵ | بخش‌های ۷، ۸، ۱۸، ۱۹، ۲۱ تا ۲۴ |
| ۱۲۹ و ۱۴۰ | بخش‌های ۱ و ۲۵؛ تفکیک دامنه اولیه و ترتیب اثبات ریسک |

## ۲۷. تصمیم‌هایی که مدل نباید خودسرانه تغییر دهد

۱. فقط زبان فارسی؛ چندزبانه‌سازی، انگلیسی‌کردن UI و ترجمه با سرویس آنلاین اضافه نشود.

۲. دوربین و فریم native؛ انتقال bitmap زنده از MethodChannel برای راحتی پیاده‌سازی ممنوع.

۳. مجوز دائمی با lease محدود آفلاین؛ exp نامحدود و ادعای revoke سریع آفلاین با هم سازگار نیستند.

۴. OTP فقط یک مرحله تأیید است؛ اثبات کلید، transaction، امضا و بررسی سرور حذف نشوند.

۵. مقدار تأییدشده متصدی بر job تازه مقدم است؛ null به عدد صفر یا حدس قابل اعتماد تبدیل نشود.

۶. فرم schema-driven با هسته تجاری typed؛ همه داده‌ها در `Map<String,dynamic>` بی‌قید ریخته نشوند.

۷. مدل خام AI از frontend فراخوانی نشود؛ API key در APK قرار نگیرد.

۸. ماسک بدن با ماسک لباس/ماسک دست یکی نیست؛ pipeline هرکدام صریح باشد.

۹. پشتیبانی USB-C و کیفیت پرو با نام گوشی ثابت نمی‌شود؛ آزمون واقعی لازم است.

۱۰. private key نصب منتقل نشود؛ بازیابی کاتالوگ با بازیابی هویت امنیتی متفاوت است.

۱۱. استنباط سن/جنسیت/احساس/توان مالی مشتری جزو محصول نیست؛ فقط رفتار انتخاب لباس.

۱۲. ساخت fixture برای تست مجاز است؛ نمایش fixture به‌عنوان نتیجه واقعی بینایی، AI یا امنیت ممنوع.

## ۲۸. منابع فنی و مرز استناد

این منابع برای بررسی قابلیت پلتفرم استفاده شده‌اند؛ معماری، انتخاب مقادیر، محدودیت‌ها و سیاست‌های این سند تصمیم طراحی پیشنهادی‌اند، نه الزام تولیدکنندگان. نسخه SDK و رفتار دستگاه هنگام ساخت دوباره بررسی شود.

- منبع م۱: [راهنمای رسمی تحلیل تصویر CameraX](https://developer.android.com/media/camera/camerax/analyze) — latest-only، backpressure و بستن ImageProxy.
- منبع م۲: [مرجع رسمی Android Presentation](https://developer.android.com/reference/android/app/Presentation) — نمایش محتوا روی display ثانویه و lifecycle آن.
- منبع م۳: [راهنمای رسمی Android Keystore](https://developer.android.com/privacy-and-security/keystore) — کلیدهای غیرقابل خروج و وابستگی hardware security به قابلیت دستگاه.
- منبع م۴: [ارتباط Flutter با کد بومی](https://docs.flutter.dev/platform-integration/platform-channels) — کانال پلتفرم و استفاده از Pigeon برای قرارداد تایپ‌شده.
- منبع م۵: [کد رسمی MediaPipe Gesture Recognizer](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/tasks/cc/vision/gesture_recognizer/gesture_recognizer.h) — دسته‌های ژست و حالت live stream.

تعهد این سند مشخص‌کردن اجزای لازم و قراردادهای اجرایی است. پذیرش نهایی کیفیت تصویر، latency، امنیت دستگاه واقعی و سازگاری پروژکتور فقط با نتایج بخش ۲۴ ممکن است.

## پیوست الف. قراردادهای تکمیلی برای جلوگیری از حدس پیاده‌ساز

### تنظیمات و وضعیت‌هایی که باید فایل مستقل داشته باشند

| مسیر مالک | کلاس | فیلدها یا متدهای مهم |
|---|---|---|
| features/settings/domain | `SettingsRepository` | `load():F<StoreSettings>`, `save(settings,expectedRevision):F<void>`, `watch():S<StoreSettings>` |
| features/settings/data | `SettingsRepositoryImpl` | اتصال SettingsDao و اعتبارسنجی رنگ/لوگو؛ بدون ذخیره secret |
| features/settings/application | `SettingsService` | `updateBranding(),setMotionPreference(),setSoundPreference(),resetDisplayCalibration()` |
| features/settings/presentation | `SettingsController` | `load(),edit(),validate(),save(),discard()` |
| features/settings/presentation | `SettingsScreen,BrandingSettingsScreen,DiagnosticsScreen` | view مطابق جدول صفحات |
| packages/domain_models/common | `AppState` | `bootstrapStatus,licenseEvaluation,operatorUnlocked,onboardingComplete,customerRunning` |
| packages/domain_models/common | `BootstrapResult` | `nextRoute,migrationResult,licenseEvaluation,warnings[]` |
| packages/domain_models/activation | `LicenseBlock` | `signedStatus,licenseVersion,observedAt,reason` |
| packages/domain_models/activation | `DeviceSession` | `accessToken,expiresAt,scopes`؛ serialization به لاگ ممنوع |
| packages/domain_models/activation | `PinResult,Lockout` | `accepted,retryAfterSeconds,remainingAttempts` / `lockedUntil,failedAttempts` |
| packages/domain_models/common | `OnboardingState` | `storeSetupDone,pinConfigured,tutorialVersionSeen,currentStep` |
| packages/domain_models/common | `DiagnosticReport` | اطلاعات نسخه و خطاهای safe و performance، بدون عکس/token |
| packages/domain_models/admin | `DashboardSummary` | `activeStores,activeDevices,pendingActivations,suspendedDevices,revokedDevices` |
| packages/domain_models/session | `SessionTransition` | `nextState,effects:List<SessionEffect>` |
| packages/domain_models/session | `SessionEffect` | union: prepareAsset,showGarment,showFeedback,clearScene,endSession |
| packages/domain_models/session | `AdmissionDecision` | `accepted,reason,trackId?,stableDurationMs` |
| packages/domain_models/session | `FeatureVector,RecommendationContext` | typed features / `shownIds,collection,explorationRatio,randomSeed` |
| packages/domain_models/metadata | `MergeProposal,FieldError` | `acceptedValues,conflicts,suggestions` / `fieldKey,code,messageFa` |
| packages/tryon_native/lib/src/models | `EngineConfig` | `analysisWidth,analysisHeight,cameraTargetFps,poseTargetFps,maskTargetFps,gestureTargetFps,protocolVersion` |
| packages/tryon_native/lib/src/models | `EngineCapabilities` | `camera,display,security,gpu,modelVersions,supportedRenderProfiles` |
| packages/tryon_native/lib/src/models | `CameraCapabilities` | `frontAvailable,supportedResolutions,maxSupportedUseCases` |
| packages/tryon_native/lib/src/models | `CaptureConfig,CustomerConfig` | `lens,orientation,previewResolution` / `roi,mirror,performancePreset` |
| packages/tryon_native/lib/src/models | `PreviewHandle,AssetHandle` | `textureId,engineEpoch` / `assetId,revision,nativeHandle` |
| packages/tryon_native/lib/src/models | `SceneDto,TransitionDto` | `sessionEpoch,selectionVersion,assetHandle,visibility` / `from,to,durationMs,motionStyle` |
| packages/tryon_native/lib/src/models | `HudDto` | `titleFa,formattedPriceFa,instructionFa,feedback,showPrivacyNotice` |
| packages/tryon_native/lib/src/models | `CalibrationDto` | `displayId,contentRect,mirror,rotation,scale,offsetX,offsetY` |
| packages/tryon_native/lib/src/models | `NativeFailure` | `code,retryable,safeDetails` |
| packages/tryon_native/android/rendering | `WarpMesh,TextureHandle,OcclusionHints` | vertices/UV/indices / GL handle+revision / arm regions+confidence |

تمام controllerهای فهرست‌شده یک `...State` immutable هم‌نام در همان presentation دارند: `status,data?,error?,isSubmitting,dirty` به‌علاوه state تخصصی جریان. این قاعده برای تولید فایل‌ها قطعی است؛ لازم نیست هر state در domain عمومی منتشر شود. repositoryهای ادمین هم یک فایل interface و یک فایل `...RepositoryImpl` در data دارند. تمام DTOهای کانال از فایل Pigeon تولید می‌شوند؛ تعریف دستی موازی Kotlin/Dart نسازید.

### enumها و واحدها

مقادیر کد انگلیسی و برچسب فارسی در `FaMessages`:

- دسته لباس: `top,jacket,dress,pants,skirt,other`؛ رندر اولیه فقط top با profile تأییدشده.
- زاویه عکس: `front,back,left45,right45,leftSide,rightSide,collar,sleeve,fabric,extra`.
- مجموعه: `women,men,all`؛ فیلتر انتخابی، نه مشخصه استنباطی مشتری.
- منبع: `ai,operator,computerVision,imported`؛ بررسی: `unreviewed,operatorConfirmed,rejected`.
- وضعیت درخواست: `pending,approved,rejected,locked,redeemed,expired`؛ وضعیت OTP مستقل نیست که درخواست مصرف‌شده را زنده کند.
- وضعیت دستگاه/مجوز: `pending,active,suspended,revoked,expired`؛ pending فقط پیش از صدور.
- قابلیت‌ها: `operatorMode,customerMode,advanced2_5D,analytics,cloudBackup`؛ unknown feature پیش‌فرض خاموش.
- واحدها: زمان API ثانیه Unix یا ISO8601 مشخص، native زمان میکروثانیه monotonic، animation میلی‌ثانیه، طول میلی‌متر، نسبت normalized و پول integer تومان. تبدیل واحد در adapter و typeهای نام‌دار انجام شود.

### رفتار توقف مجوز وسط جلسه

اگر `LicenseService` به blocked تغییر کرد، coordinator بی‌درنگ gate ژست را ببندد، native scene را با صفحه خنثی جایگزین کند، دوربین/inference متوقف و session پاک شود. متصدی دلیل فارسی را روی گوشی ببیند. هیچ اطلاعات مشتری در audit این رخداد ثبت نشود. کارهای upload/job جدید لغو/متوقف شوند؛ job سرور ممکن است تا safe cancellation point ادامه دهد و نتیجه تنها با مجوز معتبر قابل دریافت باشد. restore مجوز از suspended بدون جلسه قبلی به idle برگردد.

### نکات تکمیلی قرارداد API و bootstrap

پاسخ `POST /activations` علاوه بر request، یک `bootstrapToken` محدود به همان request و زمان expiration می‌دهد. برای نصب pending، endpoint status و challenge مربوط به redeem با همین token احراز می‌شوند. bootstrapToken پس از redeem باطل شود. درخواست اولیه rate limit و proof دارد ولی هنوز مجوز تجاری نمی‌خواهد.

متد `getProfile()` ادمین از `GET /admin/auth/me` استفاده کند. برای enrolment ابتدایی MFA، endpointهای `POST /admin/auth/mfa/enrollment` و `POST /admin/auth/mfa/enrollment/confirm` فقط با bootstrap-admin token کوتاه‌عمر یا session ادمین با احراز مجدد مجاز باشند. recovery code فقط یک‌بار قابل مصرف است؛ تغییر MFA بدون احراز مجدد ممنوع.

صدور OTP برخلاف redeem نباید با replay پاسخ قدیمی، OTP خام را از DB بازیابی کند. تکرار `Idempotency-Key` صدور، فقط `alreadyIssued=true,expiresAt` می‌دهد؛ اگر پاسخ اول گم شد ادمین «صدور کد جدید» را انتخاب می‌کند و کد قبلی باطل می‌شود. در idempotency_records صدور OTP هیچ مقدار خام یا پاسخ شامل OTP ذخیره نشود. نتیجه redeem حاوی lease می‌تواند با سیاست امن replay شود.

پروتکل فراخوانی worker در MVP HTTP داخلی همزمان با timeout محدود داخل یک BullMQ job است. صف اصلی را NestJS می‌خواند؛ Python consumer مستقیم BullMQ نیست. متد داخلی `POST /internal/process` ورودی versioned و `jobId,attempt,inputObjectKeys,outputPrefix,modelVersions` می‌گیرد. زمان بیشتر از budget → retry و وضعیت stage؛ worker خروجی deterministic را در prefix همان attempt می‌نویسد و manifest را برمی‌گرداند. تایید نهایی نتیجه فقط orchestrator است. cancel به endpoint داخلی و cancellation token منتقل شود.

### فایل راه‌انداز اصلی در برابر فایل مرجع

این فایل خودِ مرجع است. در آغاز مخزن آن را به `docs/implementation-spec-fa.md` کپی کنید. فایل `docs/implementation-status.md` پیش از هر بسته به‌روز شود. تغییرهایی مانند پشتیبانی شلوار، انتخاب provider AI، تغییر lease، یا اشتراک کاتالوگ میان دستگاه‌ها باید یک decision کوتاه با دلیل و اثر روی آزمون‌ها داشته باشند. مدل اجازه ندارد صرفاً به‌دلیل آسان‌ترشدن کدنویسی، محدودیت امنیتی یا رفتار داده را حذف کند.
