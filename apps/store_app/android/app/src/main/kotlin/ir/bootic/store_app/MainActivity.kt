package ir.bootic.store_app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Size
import android.view.Display
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

/** One CameraX session feeds the phone preview and the customer display. */
class MainActivity : FlutterActivity() {
    private val cameraExecutor = Executors.newSingleThreadExecutor()
    private val framePending = AtomicBoolean(false)
    private lateinit var displayManager: DisplayManager
    private var channel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var previewView: PreviewView? = null
    private var provider: ProcessCameraProvider? = null
    @Volatile private var presentation: CustomerPresentation? = null
    private var pendingStart: MethodChannel.Result? = null
    private var pendingCapture: MethodChannel.Result? = null
    @Volatile private var running = false
    private var cameraGeneration = 0
    @Volatile private var mirror = true
    private var garment: Bitmap? = null
    private var placement = Placement()
    @Volatile private var autoPlacement = false
    private var autoGeneration = 0
    private var poseVisible = false
    private var pendingAuto: MethodChannel.Result? = null
    @Volatile private var poseTracker: PoseTracker? = null
    private var lastPoseMs = 0L
    private var lastPoseResultTs = -1L
    private var lastDetectMs = 0L
    private var validPoseAfterMs = 0L
    @Volatile private var gestureEnabled = false
    @Volatile private var gestureTracker: GestureTracker? = null
    private var pendingGesture: MethodChannel.Result? = null
    private var gestureGeneration = 0
    private var lastGestureDetectMs = 0L
    private var lastGestureResultTs = -1L
    private var validGestureAfterMs = 0L
    private var gestureCandidate: String? = null
    private var gestureCount = 0
    private var neutralCount = 0
    private var gestureArmed = true
    private var lastVoteMs = 0L
    private var priceText = ""
    private var feedbackText = ""
    private val staleHandler = Handler(Looper.getMainLooper())
    private val staleCheck = object : Runnable {
        override fun run() {
            if (!autoPlacement || !running) return
            if (SystemClock.uptimeMillis() - lastPoseMs > 700) hidePose()
            staleHandler.postDelayed(this, 200)
        }
    }

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = Unit
        override fun onDisplayChanged(displayId: Int) = Unit
        override fun onDisplayRemoved(displayId: Int) {
            if (presentation?.display?.displayId == displayId) detachDisplay()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        displayManager = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        displayManager.registerDisplayListener(displayListener, null)
    }

    override fun onResume() {
        super.onResume()
        if (pendingStart != null && !running &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            bindCamera()
        }
    }

    override fun onStop() {
        stopCamera()
        detachDisplay()
        super.onStop()
    }

    override fun onDestroy() {
        autoPlacement = false
        autoGeneration++
        gestureEnabled = false
        gestureGeneration++
        stopCamera()
        detachDisplay()
        if (::displayManager.isInitialized) displayManager.unregisterDisplayListener(displayListener)
        pendingAuto?.error("STOPPED", "تشخیص بدن متوقف شد", null)
        pendingAuto = null
        pendingGesture?.error("STOPPED", "تشخیص علامت دست متوقف شد", null)
        pendingGesture = null
        staleHandler.removeCallbacks(staleCheck)
        try { cameraExecutor.execute {
            poseTracker?.close(); poseTracker = null
            gestureTracker?.close(); gestureTracker = null
        } } catch (_: Exception) { }
        cameraExecutor.shutdown()
        pendingCapture?.success(null)
        pendingCapture = null
        channel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "ir.bootic.store_app/live_scene",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    val view = PreviewView(context).apply {
                        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                        scaleType = PreviewView.ScaleType.FILL_CENTER
                        scaleX = if (mirror) 1f else -1f
                    }
                    previewView = view
                    if (running) bindCamera()
                    return object : PlatformView {
                        override fun getView(): View = view
                        override fun dispose() {
                            if (previewView === view) {
                                previewView = null
                                stopCamera()
                            }
                        }
                    }
                }
            },
        )
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ir.bootic.store_app/live_tryon")
        channel?.setMethodCallHandler(::handleCall)
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "ir.bootic.store_app/live_tryon_events")
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { eventSink = events }
            override fun onCancel(arguments: Any?) { eventSink = null }
        })
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> startCamera(result)
            "stop" -> { stopCamera(); result.success(null) }
            "captureGarment" -> {
                if (pendingCapture != null) {
                    result.error("BUSY", "عکس‌برداری در حال انجام است", null)
                } else {
                    stopCamera()
                    detachDisplay()
                    pendingCapture = result
                    try {
                        startActivityForResult(Intent(this, GarmentCaptureActivity::class.java), CAPTURE_REQUEST)
                    } catch (_: Exception) {
                        pendingCapture = null
                        result.error("CAPTURE_FAILED", "باز کردن دوربین عکس‌برداری ممکن نشد", null)
                    }
                }
            }
            "listDisplays" -> result.success(presentationDisplays().map {
                mapOf("id" to it.displayId, "name" to it.name)
            })
            "attachDisplay" -> {
                val id = (call.argument<Number>("id"))?.toInt()
                val target = presentationDisplays().firstOrNull { it.displayId == id }
                if (target == null) {
                    result.error("NO_DISPLAY", "نمایشگر دوم در دسترس نیست", null)
                } else {
                    try {
                        detachDisplay()
                        presentation = CustomerPresentation(this, target).also {
                            it.show()
                            it.setGarment(garment)
                            it.setPrice(priceText)
                            it.setFeedback(feedbackText)
                            it.setPlacement(placement)
                            it.setMirror(mirror)
                            it.setPoseVisible(!autoPlacement)
                        }
                        result.success(null)
                    } catch (_: Exception) {
                        detachDisplay()
                        result.error("DISPLAY_FAILED", "اتصال به نمایشگر دوم ممکن نشد", null)
                    }
                }
            }
            "detachDisplay" -> { detachDisplay(); result.success(null) }
            "setGarment" -> setGarment(call, result)
            "setAutoPlacement" -> setAutoPlacement(call, result)
            "setGestureControl" -> setGestureControl(call, result)
            "setPrice" -> {
                priceText = call.argument<String>("text")?.take(80) ?: ""
                presentation?.setPrice(priceText)
                result.success(null)
            }
            "setFeedback" -> {
                feedbackText = call.argument<String>("text")?.take(80) ?: ""
                presentation?.setFeedback(feedbackText)
                result.success(null)
            }
            "setPlacement" -> {
                val x = call.number("centerX")
                val y = call.number("centerY")
                val width = call.number("width")
                val height = call.number("height")
                if (x == null || y == null || width == null || height == null ||
                    listOf(x, y, width, height).any { !it.isFinite() } ||
                    x !in 0.0..1.0 || y !in 0.0..1.0 || width !in 0.0..1.0 || height !in 0.0..1.0 ||
                    width == 0.0 || height == 0.0) {
                    result.error("BAD_PLACEMENT", "جای لباس نامعتبر است", null)
                } else {
                    placement = Placement(x.toFloat(), y.toFloat(), width.toFloat(), height.toFloat())
                    if (!autoPlacement) presentation?.setPlacement(placement)
                    result.success(null)
                }
            }
            "setMirror" -> {
                val requested = call.argument<Boolean>("mirror")
                if (requested == null) result.error("BAD_MIRROR", "حالت آینه نامعتبر است", null)
                else {
                    mirror = requested
                    validPoseAfterMs = SystemClock.uptimeMillis()
                    lastPoseResultTs = -1L
                    hidePose()
                    previewView?.scaleX = if (mirror) 1f else -1f
                    presentation?.setMirror(mirror)
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun MethodCall.number(key: String): Double? = (argument<Number>(key))?.toDouble()

    private fun setAutoPlacement(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled")
        if (enabled == null) { result.error("BAD_AUTO", "حالت خودکار نامعتبر است", null); return }
        if (!enabled) {
            autoGeneration++
            pendingAuto?.error("CANCELLED", "تشخیص خودکار لغو شد", null)
            pendingAuto = null
            autoPlacement = false
            staleHandler.removeCallbacks(staleCheck)
            poseVisible = false
            presentation?.setPlacement(placement)
            presentation?.setPoseVisible(true)
            result.success(null)
            return
        }
        if (pendingAuto != null) { result.error("BUSY", "مدل در حال آماده‌سازی است", null); return }
        if (poseTracker != null) {
            enableAuto()
            result.success(null)
            return
        }
        val generation = ++autoGeneration
        pendingAuto = result
        cameraExecutor.execute {
            try {
                val tracker = PoseTracker(this, { box, timestamp ->
                    runOnUiThread { onPoseResult(box, timestamp) }
                }, {
                    runOnUiThread {
                        if (autoPlacement) {
                            autoPlacement = false
                            val failed = poseTracker
                            poseTracker = null
                            try { cameraExecutor.execute { failed?.close() } } catch (_: Exception) { failed?.close() }
                            staleHandler.removeCallbacks(staleCheck)
                            poseVisible = false
                            presentation?.setPlacement(placement)
                            presentation?.setPoseVisible(true)
                            eventSink?.success(mapOf("type" to "error", "message" to "تشخیص بدن متوقف شد؛ جای لباس دستی است"))
                        }
                    }
                })
                runOnUiThread {
                    if (generation != autoGeneration || isDestroyed) {
                        try { cameraExecutor.execute { tracker.close() } } catch (_: Exception) { tracker.close() }
                    } else {
                        poseTracker = tracker
                        enableAuto()
                        pendingAuto?.success(null)
                        pendingAuto = null
                    }
                }
            } catch (_: Exception) {
                runOnUiThread {
                    if (generation == autoGeneration) {
                        pendingAuto?.error("POSE_UNAVAILABLE", "مدل تشخیص بدن آماده نشد؛ جای لباس را دستی تنظیم کنید", null)
                        pendingAuto = null
                    }
                }
            } catch (_: LinkageError) {
                runOnUiThread {
                    if (generation == autoGeneration) {
                        pendingAuto?.error("POSE_UNAVAILABLE", "مدل تشخیص بدن در این دستگاه اجرا نشد", null)
                        pendingAuto = null
                    }
                }
            }
        }
    }

    private fun enableAuto() {
        autoPlacement = true
        poseVisible = false
        lastPoseMs = SystemClock.uptimeMillis()
        lastPoseResultTs = -1L
        validPoseAfterMs = lastPoseMs
        presentation?.setPoseVisible(false)
        eventSink?.success(mapOf("type" to "placement", "visible" to false))
        staleHandler.removeCallbacks(staleCheck)
        if (running) staleHandler.postDelayed(staleCheck, 200)
    }

    private fun setGestureControl(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled")
        if (enabled == null) { result.error("BAD_GESTURE", "حالت علامت دست نامعتبر است", null); return }
        if (!enabled) {
            gestureGeneration++
            pendingGesture?.error("CANCELLED", "تشخیص علامت دست لغو شد", null)
            pendingGesture = null
            gestureEnabled = false
            resetGestureState()
            result.success(null)
            return
        }
        if (pendingGesture != null) { result.error("BUSY", "مدل دست در حال آماده‌سازی است", null); return }
        if (gestureTracker != null) {
            enableGestures()
            result.success(null)
            return
        }
        val generation = ++gestureGeneration
        pendingGesture = result
        cameraExecutor.execute {
            try {
                val tracker = GestureTracker(this, { label, timestamp ->
                    runOnUiThread { onGestureResult(label, timestamp) }
                }, {
                    runOnUiThread { failGestures("تشخیص علامت دست متوقف شد؛ از دکمه‌ها استفاده کنید") }
                })
                runOnUiThread {
                    if (generation != gestureGeneration || isDestroyed) {
                        try { cameraExecutor.execute { tracker.close() } } catch (_: Exception) { tracker.close() }
                    } else {
                        gestureTracker = tracker
                        enableGestures()
                        pendingGesture?.success(null)
                        pendingGesture = null
                    }
                }
            } catch (_: Exception) {
                runOnUiThread {
                    if (generation == gestureGeneration) {
                        pendingGesture?.error("GESTURE_UNAVAILABLE", "مدل علامت دست آماده نشد؛ از دکمه‌ها استفاده کنید", null)
                        pendingGesture = null
                    }
                }
            } catch (_: LinkageError) {
                runOnUiThread {
                    if (generation == gestureGeneration) {
                        pendingGesture?.error("GESTURE_UNAVAILABLE", "مدل علامت دست روی این دستگاه اجرا نشد", null)
                        pendingGesture = null
                    }
                }
            }
        }
    }

    private fun resetGestureState() {
        gestureCandidate = null
        gestureCount = 0
        neutralCount = 0
        gestureArmed = true
        lastGestureResultTs = -1L
        validGestureAfterMs = SystemClock.uptimeMillis()
    }

    private fun enableGestures() {
        resetGestureState()
        gestureEnabled = true
    }

    private fun failGestures(message: String) {
        if (!gestureEnabled) return
        gestureEnabled = false
        gestureGeneration++
        resetGestureState()
        val failed = gestureTracker
        gestureTracker = null
        try { cameraExecutor.execute { failed?.close() } } catch (_: Exception) { failed?.close() }
        eventSink?.success(mapOf("type" to "gestureError", "message" to message))
    }

    private fun onGestureResult(label: String?, timestamp: Long) {
        if (!running || !gestureEnabled || timestamp < validGestureAfterMs ||
            timestamp <= lastGestureResultTs) return
        lastGestureResultTs = timestamp
        if (label == null) {
            gestureCandidate = null
            gestureCount = 0
            neutralCount++
            if (neutralCount >= 4 && SystemClock.uptimeMillis() - lastVoteMs >= 1600) {
                gestureArmed = true
            }
            return
        }
        if (!gestureArmed && neutralCount >= 4 &&
            SystemClock.uptimeMillis() - lastVoteMs >= 1600) gestureArmed = true
        neutralCount = 0
        if (!gestureArmed || SystemClock.uptimeMillis() - lastVoteMs < 1600) return
        if (gestureCandidate == label) gestureCount++ else {
            gestureCandidate = label
            gestureCount = 1
        }
        if (gestureCount < 3) return
        gestureArmed = false
        lastVoteMs = SystemClock.uptimeMillis()
        gestureCandidate = null
        gestureCount = 0
        eventSink?.success(mapOf("type" to "gestureVote", "liked" to (label == "Thumb_Up")))
    }

    private fun hidePose() {
        if (!autoPlacement) return
        presentation?.setPoseVisible(false)
        if (poseVisible) {
            poseVisible = false
            eventSink?.success(mapOf("type" to "placement", "visible" to false))
        }
    }

    private fun onPoseResult(box: TorsoBox?, timestamp: Long) {
        if (!autoPlacement || !running || timestamp < validPoseAfterMs || timestamp <= lastPoseResultTs) return
        lastPoseResultTs = timestamp
        if (box == null) return
        val phone = previewView ?: return
        if (phone.width <= 0 || phone.height <= 0) return
        val phonePlacement = box.forViewport(phone.width, phone.height)
        lastPoseMs = SystemClock.uptimeMillis()
        poseVisible = true
        presentation?.setPose(box)
        eventSink?.success(mapOf(
            "type" to "placement",
            "centerX" to phonePlacement.centerX.toDouble(),
            "centerY" to phonePlacement.centerY.toDouble(),
            "width" to phonePlacement.width.toDouble(),
            "height" to phonePlacement.height.toDouble(),
            "visible" to true,
        ))
    }

    private fun TorsoBox.forViewport(viewWidth: Int, viewHeight: Int): Placement {
        val scale = max(viewWidth.toFloat() / imageWidth, viewHeight.toFloat() / imageHeight)
        val widthFactor = imageWidth * scale / viewWidth
        val heightFactor = imageHeight * scale / viewHeight
        return Placement(
            ((centerX - 0.5f) * widthFactor + 0.5f).coerceIn(0f, 1f),
            ((centerY - 0.5f) * heightFactor + 0.5f).coerceIn(0f, 1f),
            (width * widthFactor).coerceIn(0.01f, 1f),
            (height * heightFactor).coerceIn(0.01f, 1f),
        )
    }

    private fun presentationDisplays(): Array<Display> =
        displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            .filter { it.displayId != windowManager.defaultDisplay.displayId }
            .toTypedArray()

    private fun detachDisplay() {
        try { presentation?.dismiss() } catch (_: Exception) { }
        presentation = null
    }

    private fun setGarment(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            garment = null
            presentation?.setGarment(null)
            result.success(null)
            return
        }
        try {
            val root = filesDir.canonicalFile
            val file = File(path).canonicalFile
            if (!file.path.startsWith(root.path + File.separator) ||
                !file.name.endsWith(".jpg", ignoreCase = true) ||
                !file.isFile || file.length() > 15L * 1024 * 1024) {
                throw IllegalArgumentException()
            }
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, options)
            if (options.outWidth !in 64..6000 || options.outHeight !in 64..6000) {
                throw IllegalArgumentException()
            }
            var sample = 1
            while (options.outWidth / sample > 1600 || options.outHeight / sample > 1600) {
                sample *= 2
            }
            options.inJustDecodeBounds = false
            options.inSampleSize = sample
            options.inPreferredConfig = Bitmap.Config.ARGB_8888
            val decoded = BitmapFactory.decodeFile(file.path, options)
                ?: throw IllegalArgumentException()
            garment = decoded
            presentation?.setGarment(decoded)
            result.success(null)
        } catch (_: Exception) {
            result.error("BAD_GARMENT", "فایل لباس معتبر یا در دسترس نیست", null)
        }
    }

    private fun startCamera(result: MethodChannel.Result) {
        if (running && provider != null) { result.success(mapOf("available" to true)); return }
        if (pendingStart != null) { result.error("BUSY", "دوربین در حال آماده‌سازی است", null); return }
        if (previewView == null) { result.error("NO_PREVIEW", "پیش‌نمایش دوربین آماده نیست", null); return }
        pendingStart = result
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION_REQUEST)
            return
        }
        bindCamera()
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_PERMISSION_REQUEST || pendingStart == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            if (!running && lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) bindCamera()
        }
        else failStart("CAMERA_DENIED", "اجازه دوربین داده نشد")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == CAPTURE_REQUEST) {
            pendingCapture?.success(if (resultCode == RESULT_OK) data?.getStringExtra("path") else null)
            pendingCapture = null
        }
    }

    private fun bindCamera() {
        val preview = previewView ?: run { failStart("NO_PREVIEW", "پیش‌نمایش دوربین آماده نیست"); return }
        running = true
        val generation = ++cameraGeneration
        val future = ProcessCameraProvider.getInstance(this)
        future.addListener({
            if (!running || generation != cameraGeneration || isFinishing || isDestroyed) return@addListener
            try {
                val current = future.get()
                if (!current.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) {
                    failStart("NO_FRONT_CAMERA", "دوربین جلو در دسترس نیست")
                    return@addListener
                }
                current.unbindAll()
                provider = current
                val cameraPreview = Preview.Builder().build().also {
                    it.setSurfaceProvider(preview.surfaceProvider)
                }
                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setTargetResolution(Size(640, 480))
                    .build()
                analysis.setAnalyzer(cameraExecutor) { image -> renderForPresentation(image) }
                current.bindToLifecycle(this, CameraSelector.DEFAULT_FRONT_CAMERA, cameraPreview, analysis)
                staleHandler.removeCallbacks(staleCheck)
                if (autoPlacement) staleHandler.postDelayed(staleCheck, 200)
                pendingStart?.success(mapOf("available" to true))
                pendingStart = null
            } catch (_: Exception) {
                failStart("CAMERA_FAILED", "راه‌اندازی دوربین ممکن نشد")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun renderForPresentation(image: ImageProxy) {
        var queuedFrame = false
        try {
            if (!running || (presentation == null && !autoPlacement && !gestureEnabled)) return
            val plane = image.planes[0]
            if (plane.pixelStride != 4 || plane.rowStride < image.width * 4) return
            val now = SystemClock.uptimeMillis()
            val infer = autoPlacement && poseTracker != null && now - lastDetectMs >= 100
            val inferGesture = gestureEnabled && gestureTracker != null &&
                now - lastGestureDetectMs >= 180
            val project = presentation != null && framePending.compareAndSet(false, true)
            if (!infer && !inferGesture && !project) return
            queuedFrame = project
            val row = ByteArray(image.width * 4)
            val packed = ByteArray(image.width * image.height * 4)
            val buffer = plane.buffer
            for (y in 0 until image.height) {
                buffer.position(y * plane.rowStride)
                buffer.get(row)
                System.arraycopy(row, 0, packed, y * row.size, row.size)
            }
            val raw = Bitmap.createBitmap(image.width, image.height, Bitmap.Config.ARGB_8888)
            raw.copyPixelsFromBuffer(ByteBuffer.wrap(packed))
            val transform = Matrix().apply {
                postRotate(image.imageInfo.rotationDegrees.toFloat())
                if (mirror) postScale(-1f, 1f)
            }
            val frame = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, transform, true)
            if (frame !== raw) raw.recycle()
            if (infer) {
                lastDetectMs = now
                try { poseTracker?.detect(frame, now) } catch (_: Exception) {
                    runOnUiThread { hidePose() }
                }
            }
            if (inferGesture) {
                lastGestureDetectMs = now
                try { gestureTracker?.detect(frame, now) } catch (_: Exception) {
                    runOnUiThread { failGestures("تشخیص علامت دست متوقف شد؛ از دکمه‌ها استفاده کنید") }
                }
            }
            if (project) {
                runOnUiThread {
                    if (running) presentation?.showFrame(frame)
                    // ImageView drops its previous bitmap after replacement; Android's
                    // rendering pipeline/GC releases it when drawing is finished.
                    framePending.set(false)
                }
            }
        } catch (_: Exception) {
            if (queuedFrame) framePending.set(false)
        } finally {
            image.close()
        }
    }

    private fun failStart(code: String, message: String) {
        val awaiting = pendingStart
        pendingStart = null
        stopCamera()
        awaiting?.error(code, message, null)
    }

    private fun stopCamera() {
        running = false
        gestureEnabled = false
        gestureGeneration++
        pendingGesture?.error("STOPPED", "دوربین متوقف شد", null)
        pendingGesture = null
        resetGestureState()
        staleHandler.removeCallbacks(staleCheck)
        hidePose()
        cameraGeneration++
        provider?.unbindAll()
        provider = null
        pendingStart?.error("STOPPED", "دوربین متوقف شد", null)
        pendingStart = null
        presentation?.clearFrame()
    }

    companion object {
        private const val CAMERA_PERMISSION_REQUEST = 7144
        private const val CAPTURE_REQUEST = 7145
    }
}

private data class Placement(
    val centerX: Float = 0.5f,
    val centerY: Float = 0.45f,
    val width: Float = 0.45f,
    val height: Float = 0.5f,
)

/** A separate customer-only window, never the operator controls. */
private class CustomerPresentation(context: Context, display: Display) : android.app.Presentation(context, display) {
    private lateinit var scene: FrameLayout
    private lateinit var camera: ImageView
    private lateinit var overlay: ImageView
    private lateinit var price: android.widget.TextView
    private lateinit var feedback: android.widget.TextView
    private var placement = Placement()
    private var poseBox: TorsoBox? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        scene = FrameLayout(context).apply { setBackgroundColor(android.graphics.Color.BLACK) }
        camera = ImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
        scene.addView(camera, FrameLayout.LayoutParams(-1, -1))
        overlay = ImageView(context).apply {
            scaleType = ImageView.ScaleType.FIT_XY
            alpha = 0.78f
        }
        scene.addView(overlay)
        price = android.widget.TextView(context).apply {
            setTextColor(android.graphics.Color.WHITE)
            setBackgroundColor(0xBB10131A.toInt())
            textSize = 22f
            textDirection = View.TEXT_DIRECTION_RTL
            setPadding(20, 12, 20, 12)
        }
        scene.addView(price, FrameLayout.LayoutParams(-2, -2, android.view.Gravity.TOP or android.view.Gravity.END).apply {
            setMargins(16, 16, 16, 16)
        })
        feedback = android.widget.TextView(context).apply {
            setTextColor(android.graphics.Color.WHITE)
            setBackgroundColor(0xBB10131A.toInt())
            textSize = 26f
            textDirection = View.TEXT_DIRECTION_RTL
            setPadding(22, 14, 22, 14)
            visibility = View.GONE
        }
        scene.addView(feedback, FrameLayout.LayoutParams(-2, -2,
            android.view.Gravity.CENTER))
        val hint = android.widget.TextView(context).apply {
            text = "شست بالا: می‌پسندم | شست پایین: نمی‌پسندم"
            setTextColor(android.graphics.Color.WHITE)
            setBackgroundColor(0x99000000.toInt())
            textSize = 18f
            textDirection = View.TEXT_DIRECTION_RTL
            setPadding(18, 12, 18, 12)
        }
        scene.addView(hint, FrameLayout.LayoutParams(-2, -2, android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL))
        scene.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> updatePlacement() }
        setContentView(scene)
    }

    fun showFrame(frame: Bitmap) { if (::camera.isInitialized) camera.setImageBitmap(frame) }
    fun clearFrame() { if (::camera.isInitialized) camera.setImageDrawable(null) }
    fun setGarment(bitmap: Bitmap?) { if (::overlay.isInitialized) overlay.setImageBitmap(bitmap) }
    fun setPrice(text: String) { if (::price.isInitialized) {
        price.text = text
        price.visibility = if (text.isEmpty()) View.GONE else View.VISIBLE
    } }
    fun setFeedback(text: String) { if (::feedback.isInitialized) {
        feedback.text = text
        feedback.visibility = if (text.isEmpty()) View.GONE else View.VISIBLE
    } }
    fun setPlacement(value: Placement) { poseBox = null; placement = value; updatePlacement() }
    fun setMirror(value: Boolean) { if (::overlay.isInitialized) overlay.scaleX = if (value) -1f else 1f }
    fun setPose(value: TorsoBox) { poseBox = value; setPoseVisible(true); updatePlacement() }
    fun setPoseVisible(value: Boolean) { if (::overlay.isInitialized) overlay.visibility = if (value) View.VISIBLE else View.INVISIBLE }

    private fun updatePlacement() {
        if (!::scene.isInitialized || !::overlay.isInitialized || scene.width == 0 || scene.height == 0) return
        val adjusted = poseBox?.let { box ->
            val scale = max(scene.width.toFloat() / box.imageWidth, scene.height.toFloat() / box.imageHeight)
            val sx = box.imageWidth * scale / scene.width
            val sy = box.imageHeight * scale / scene.height
            Placement(
                ((box.centerX - 0.5f) * sx + 0.5f).coerceIn(0f, 1f),
                ((box.centerY - 0.5f) * sy + 0.5f).coerceIn(0f, 1f),
                (box.width * sx).coerceIn(0.01f, 1f),
                (box.height * sy).coerceIn(0.01f, 1f),
            )
        } ?: placement
        val width = (scene.width * adjusted.width).toInt()
        val height = (scene.height * adjusted.height).toInt()
        overlay.layoutParams = FrameLayout.LayoutParams(width, height).apply {
            leftMargin = (scene.width * adjusted.centerX - width / 2f).toInt()
            topMargin = (scene.height * adjusted.centerY - height / 2f).toInt()
        }
    }
}
