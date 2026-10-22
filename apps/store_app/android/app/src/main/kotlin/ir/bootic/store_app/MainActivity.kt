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
    @Volatile private var cameraGeneration = 0
    @Volatile private var mirror = true
    private var frontCamera = true
    private var votingEnabled = false
    private val voteGate = GestureVoteGate()
    private var garment: Bitmap? = null
    private var placement = Placement()
    private var sceneEffect = EffectMode.NONE
    private var phoneEffects: TryonEffectsView? = null
    @Volatile private var autoPlacement = false
    private var autoGeneration = 0
    private var poseVisible = false
    private val debugVersion by lazy {
        val info = packageManager.getPackageInfo(packageName, 0)
        "${info.versionName}+${info.longVersionCode}"
    }
    private var poseDebugEnabled = false
    private var latestPose: PoseObservation? = null
    private var lastDebugMs = 0L
    private var poseLatencyMs = 0L
    private var poseFps = 0.0
    private var fpsWindowMs = 0L
    private var fpsCount = 0
    private var acceptedPoses = 0
    private var rejectedPoses = 0
    private var lastGestureLabel = "none"
    private var poseFailure = ""
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
    private var priceText = ""
    private var feedbackText = ""
    private val staleHandler = Handler(Looper.getMainLooper())
    private val staleCheck = object : Runnable {
        override fun run() {
            if (!autoPlacement || !running) return
            if (SystemClock.uptimeMillis() - lastPoseMs > 700) hidePose()
            emitPoseDebug()
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
        phoneEffects?.let { (it.parent as? android.view.ViewGroup)?.removeView(it) }
        phoneEffects = null
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
                        scaleX = if (mirror == frontCamera) 1f else -1f
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
            "setCameraFacing" -> setCameraFacing(call, result)
            "setSceneEffect" -> {
                val effect = EffectMode.entries.firstOrNull { it.wireName == call.argument<String>("effect") }
                if (effect == null) result.error("BAD_EFFECT", "افکت نامعتبر است", null)
                else {
                    applySceneEffect(effect)
                    result.success(effect.durationMs)
                }
            }
            "removeGarmentBackground" -> GarmentCutout(this, cameraExecutor)
                .process(call.argument<String>("path"), result)
            "setVotingEnabled" -> {
                votingEnabled = call.argument<Boolean>("enabled") == true
                result.success(null)
            }
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
                            it.setSceneEffect(sceneEffect)
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
            "setPoseDebugEnabled" -> {
                poseDebugEnabled = call.argument<Boolean>("enabled") == true
                lastDebugMs = 0L
                emitPoseDebug()
                result.success(null)
            }
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
                    previewView?.scaleX = if (mirror == frontCamera) 1f else -1f
                    presentation?.setMirror(mirror)
                    result.success(null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun applySceneEffect(effect: EffectMode) {
        sceneEffect = effect
        if (effect != EffectMode.NONE && phoneEffects == null) {
            val decor = window.decorView as? android.view.ViewGroup
            if (decor != null) {
                phoneEffects = TryonEffectsView(this).also {
                    decor.addView(it, android.view.ViewGroup.LayoutParams(-1, -1))
                }
            }
        }
        phoneEffects?.setEffect(effect)
        presentation?.setSceneEffect(effect)
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
                            poseFailure = "tracker_error"
                            latestPose = null
                            lastPoseResultTs = -1L
                            lastDebugMs = 0L
                            emitPoseDebug()
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
        latestPose = null
        poseFailure = ""
        acceptedPoses = 0
        rejectedPoses = 0
        fpsCount = 0
        poseFps = 0.0
        fpsWindowMs = lastPoseMs
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
        voteGate.reset()
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
        lastGestureLabel = label ?: "none"
        val vote = voteGate.update(label, timestamp, votingEnabled) ?: return
        // Do not consume gestures while Flutter is loading a garment or showing feedback.
        votingEnabled = false
        eventSink?.success(mapOf("type" to "gestureVote", "liked" to (vote == "Thumb_Up")))
    }

    private fun hidePose() {
        phoneEffects?.setPerson(null, 1, 1, previewView)
        if (!autoPlacement) return
        presentation?.setPoseVisible(false)
        if (poseVisible) {
            poseVisible = false
            eventSink?.success(mapOf("type" to "placement", "visible" to false))
        }
    }

    private fun onPoseResult(observation: PoseObservation, timestamp: Long) {
        if (!autoPlacement || !running || timestamp < validPoseAfterMs || timestamp <= lastPoseResultTs) return
        lastPoseResultTs = timestamp
        latestPose = observation
        poseFailure = ""
        val now = SystemClock.uptimeMillis()
        poseLatencyMs = (now - timestamp).coerceAtLeast(0)
        fpsCount++
        if (now - fpsWindowMs >= 1000) {
            poseFps = fpsCount * 1000.0 / (now - fpsWindowMs)
            fpsCount = 0
            fpsWindowMs = now
        }
        val box = observation.box
        if (box == null) {
            rejectedPoses++
            emitPoseDebug()
            return
        }
        acceptedPoses++
        val phone = previewView ?: return
        if (phone.width <= 0 || phone.height <= 0) return
        val phonePlacement = box.forViewport(phone.width, phone.height)
        lastPoseMs = SystemClock.uptimeMillis()
        poseVisible = true
        phoneEffects?.setPerson(box.personFrame, box.imageWidth, box.imageHeight, phone)
        presentation?.setPose(box)
        eventSink?.success(mapOf(
            "type" to "placement",
            "centerX" to phonePlacement.centerX.toDouble(),
            "centerY" to phonePlacement.centerY.toDouble(),
            "width" to phonePlacement.width.toDouble(),
            "height" to phonePlacement.height.toDouble(),
            "rotationDegrees" to phonePlacement.rotationDegrees.toDouble(),
            "visible" to true,
        ))
        emitPoseDebug()
    }

    /** Four updates/second, only when requested. Raw rejected points stay available
     * so a screenshot can distinguish model loss from our geometry rejection. */
    private fun emitPoseDebug() {
        if (!poseDebugEnabled) return
        val now = SystemClock.uptimeMillis()
        if (now - lastDebugMs < 250) return
        lastDebugMs = now
        val observation = latestPose
        val phone = previewView
        val frame = observation?.personFrame
        eventSink?.success(mapOf(
            "type" to "poseDebug", "revision" to "pose-v2",
            "version" to debugVersion,
            "reason" to (if (poseFailure.isNotEmpty()) poseFailure else observation?.reason ?: "waiting"),
            "points" to observation?.points?.map { point -> mapOf(
                "x" to point.x.toDouble(), "y" to point.y.toDouble(),
                "visibility" to point.visibility.toDouble(), "presence" to point.presence.toDouble(),
            ) }.orEmpty(),
            "bounds" to frame?.let { listOf(it.left.toDouble(), it.top.toDouble(), it.right.toDouble(), it.bottom.toDouble()) },
            "imageWidth" to (observation?.imageWidth ?: 0), "imageHeight" to (observation?.imageHeight ?: 0),
            "viewWidth" to (phone?.width ?: 0), "viewHeight" to (phone?.height ?: 0),
            "shoulderPx" to (observation?.shoulderPx?.toDouble() ?: 0.0),
            "torsoPx" to (observation?.torsoPx?.toDouble() ?: 0.0),
            "widthFactor" to PoseGeometry.WIDTH_FACTOR.toDouble(),
            "heightFactor" to PoseGeometry.HEIGHT_FACTOR.toDouble(),
            "modelConfidence" to PoseGeometry.MODEL_CONFIDENCE.toDouble(),
            "fps" to (if (lastPoseResultTs < 0 || now - lastPoseResultTs > 1500) 0.0 else poseFps),
            "latencyMs" to poseLatencyMs,
            "resultAgeMs" to (if (lastPoseResultTs < 0) -1L else now - lastPoseResultTs),
            "poseAgeMs" to (now - lastPoseMs),
            "accepted" to acceptedPoses, "rejected" to rejectedPoses,
            "front" to frontCamera, "mirror" to mirror, "poseVisible" to poseVisible,
            "effect" to sceneEffect.wireName, "gesture" to lastGestureLabel,
            "voting" to votingEnabled,
            "garmentWidth" to (garment?.width ?: 0), "garmentHeight" to (garment?.height ?: 0),
        ))
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
                file.extension.lowercase() !in setOf("jpg", "jpeg", "png") ||
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
        if (running && provider != null) { result.success(mapOf("available" to true, "front" to frontCamera)); return }
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

    private fun setCameraFacing(call: MethodCall, result: MethodChannel.Result) {
        val requested = call.argument<Boolean>("front")
        val current = provider
        if (requested == null || !running || current == null) {
            result.error("CAMERA_STOPPED", "ابتدا دوربین را باز کنید", null)
            return
        }
        if (pendingStart != null) { result.error("BUSY", "دوربین در حال آماده‌سازی است", null); return }
        val selector = if (requested) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
        try {
            if (!current.hasCamera(selector)) {
                result.error("CAMERA_UNAVAILABLE", "دوربین انتخاب‌شده در دسترس نیست", null)
                return
            }
        } catch (_: Exception) {
            result.error("CAMERA_UNAVAILABLE", "بررسی دوربین ممکن نشد", null)
            return
        }
        frontCamera = requested
        mirror = requested
        latestPose = null
        poseFailure = ""
        votingEnabled = false
        validPoseAfterMs = SystemClock.uptimeMillis()
        lastPoseResultTs = -1L
        resetGestureState()
        hidePose()
        presentation?.clearFrame()
        presentation?.setMirror(mirror)
        previewView?.scaleX = 1f // CameraX mirrors only its front-camera preview.
        pendingStart = result
        bindCamera()
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
                var selector = if (frontCamera) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
                if (!current.hasCamera(selector)) {
                    selector = if (frontCamera) CameraSelector.DEFAULT_BACK_CAMERA else CameraSelector.DEFAULT_FRONT_CAMERA
                    if (!current.hasCamera(selector)) {
                        failStart("CAMERA_UNAVAILABLE", "هیچ دوربینی در دسترس نیست")
                        return@addListener
                    }
                    frontCamera = !frontCamera
                    mirror = frontCamera
                    preview.scaleX = 1f
                    presentation?.setMirror(mirror)
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
                analysis.setAnalyzer(cameraExecutor) { image -> renderForPresentation(image, generation) }
                current.bindToLifecycle(this, selector, cameraPreview, analysis)
                staleHandler.removeCallbacks(staleCheck)
                if (autoPlacement) staleHandler.postDelayed(staleCheck, 200)
                pendingStart?.success(mapOf("available" to true, "front" to frontCamera))
                pendingStart = null
            } catch (_: Exception) {
                failStart("CAMERA_FAILED", "راه‌اندازی دوربین ممکن نشد")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun renderForPresentation(image: ImageProxy, generation: Int) {
        var queuedFrame = false
        try {
            if (!running || generation != cameraGeneration || (presentation == null && !autoPlacement && !gestureEnabled)) return
            val plane = image.planes[0]
            if (plane.pixelStride != 4 || plane.rowStride < image.width * 4) return
            val now = SystemClock.uptimeMillis()
            val infer = autoPlacement && poseTracker != null && now - lastDetectMs >= 100
            val inferGesture = gestureEnabled && gestureTracker != null &&
                now - lastGestureDetectMs >= 120
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
            if (!running || generation != cameraGeneration) {
                if (project) framePending.set(false)
                return
            }
            if (infer) {
                lastDetectMs = now
                try { poseTracker?.detect(frame, now) } catch (_: Exception) {
                    runOnUiThread {
                        poseFailure = "inference_error"
                        hidePose()
                        emitPoseDebug()
                    }
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
                    if (running && generation == cameraGeneration) presentation?.showFrame(frame)
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
        applySceneEffect(EffectMode.NONE)
        running = false
        poseDebugEnabled = false
        latestPose = null
        votingEnabled = false
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

/** A separate customer-only window, never the operator controls. */
private class CustomerPresentation(context: Context, display: Display) : android.app.Presentation(context, display) {
    private lateinit var scene: FrameLayout
    private lateinit var camera: ImageView
    private lateinit var overlay: ImageView
    private lateinit var price: android.widget.TextView
    private lateinit var feedback: android.widget.TextView
    private var placement = Placement()
    private var poseBox: TorsoBox? = null
    private var poseAvailable = true
    private lateinit var effects: TryonEffectsView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        scene = FrameLayout(context).apply { setBackgroundColor(android.graphics.Color.BLACK) }
        camera = ImageView(context).apply { scaleType = ImageView.ScaleType.CENTER_CROP }
        scene.addView(camera, FrameLayout.LayoutParams(-1, -1))
        overlay = ImageView(context).apply {
            scaleType = ImageView.ScaleType.FIT_XY
            alpha = 1f
        }
        scene.addView(overlay)
        effects = TryonEffectsView(context)
        scene.addView(effects, FrameLayout.LayoutParams(-1, -1))
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
        price.visibility = if (text.isEmpty() || effects.mode.blocksGarment) View.GONE else View.VISIBLE
    } }
    fun setFeedback(text: String) { if (::feedback.isInitialized) {
        feedback.text = text
        feedback.visibility = if (text.isEmpty()) View.GONE else View.VISIBLE
    } }
    fun setPlacement(value: Placement) { poseBox = null; placement = value; updatePlacement() }
    fun setMirror(value: Boolean) { if (::overlay.isInitialized) overlay.scaleX = if (value) -1f else 1f }
    fun setPose(value: TorsoBox) {
        poseBox = value
        effects.setPerson(value.personFrame, value.imageWidth, value.imageHeight, camera)
        setPoseVisible(true)
        updatePlacement()
    }
    fun setPoseVisible(value: Boolean) {
        poseAvailable = value
        if (::overlay.isInitialized) overlay.visibility =
            if (value && !effects.mode.blocksGarment) View.VISIBLE else View.INVISIBLE
        if (!value && ::effects.isInitialized) effects.setPerson(null, 1, 1, camera)
    }
    fun setSceneEffect(value: EffectMode) {
        if (!::effects.isInitialized) return
        effects.setEffect(value)
        setPoseVisible(poseAvailable)
        if (::price.isInitialized) price.visibility =
            if (price.text.isEmpty() || value.blocksGarment) View.GONE else View.VISIBLE
    }

    private fun updatePlacement() {
        if (!::scene.isInitialized || !::overlay.isInitialized || scene.width == 0 || scene.height == 0) return
        val adjusted = poseBox?.forViewport(scene.width, scene.height) ?: placement
        overlay.rotation = adjusted.rotationDegrees
        val width = (scene.width * adjusted.width).toInt()
        val height = (scene.height * adjusted.height).toInt()
        overlay.layoutParams = FrameLayout.LayoutParams(width, height).apply {
            leftMargin = (scene.width * adjusted.centerX - width / 2f).toInt()
            topMargin = (scene.height * adjusted.centerY - height / 2f).toInt()
        }
    }
}
