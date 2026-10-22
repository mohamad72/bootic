package ir.bootic.store_app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import android.graphics.SweepGradient
import android.os.SystemClock
import android.view.View
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Decorative Android overlay: stays above the preview and never intercepts taps.
 * The phone version lives in the window decor, so the glow wraps the entire screen,
 * including the customer navigation bar. No full-screen blur or camera copies. */
internal class TryonEffectsView(context: Context) : View(context) {
    var mode = EffectMode.NONE
        private set
    private var startedMs = 0L
    private var frame: PersonFrame? = null
    private var imageWidth = 1
    private var imageHeight = 1
    private var viewport: View? = null
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val path = Path()
    private val segment = Path()
    private val measure = PathMeasure()
    private val matrix = Matrix()
    private val ownLocation = IntArray(2)
    private val cameraLocation = IntArray(2)
    private val density = resources.displayMetrics.density
    private val colors = intArrayOf(
        0xFF45CFFF.toInt(), 0xFF517AFF.toInt(), 0xFFA65BFF.toInt(),
        0xFFFF51BD.toInt(), 0xFFFF725D.toInt(), 0xFFFFCE85.toInt(), 0xFF45CFFF.toInt(),
    )
    private var edgeShader: SweepGradient? = null
    private val animatedFrame = RectF()
    private var frameInitialized = false

    init {
        isClickable = false
        isFocusable = false
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        visibility = INVISIBLE
        setWillNotDraw(false)
    }

    fun setEffect(value: EffectMode) {
        mode = value
        startedMs = SystemClock.uptimeMillis()
        frameInitialized = false
        visibility = if (value == EffectMode.NONE) INVISIBLE else VISIBLE
        invalidate()
    }

    fun setPerson(value: PersonFrame?, sourceWidth: Int, sourceHeight: Int, cameraViewport: View?) {
        frame = value
        if (value == null) frameInitialized = false
        imageWidth = max(1, sourceWidth)
        imageHeight = max(1, sourceHeight)
        viewport = cameraViewport
        if (mode == EffectMode.LOADING) invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        edgeShader = SweepGradient(w / 2f, h / 2f, colors, null)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (mode == EffectMode.NONE || width == 0 || height == 0) return
        val elapsed = SystemClock.uptimeMillis() - startedMs
        val phase = mode.phaseAt(elapsed)
        when (mode) {
            EffectMode.DETECTION -> drawEdgeGlow(canvas, phase)
            EffectMode.LOADING -> drawPersonTrail(canvas, phase)
            EffectMode.NONE -> Unit
        }
        // A completed detection fades to zero. Loading loops only while a person
        // is visible; a new pose invalidates the view after reacquisition.
        if ((mode == EffectMode.DETECTION && phase < 1f) ||
            (mode == EffectMode.LOADING && frame != null)) postInvalidateOnAnimation()
    }

    private fun drawEdgeGlow(canvas: Canvas, phase: Float) {
        val fadeIn = (phase / 0.15f).coerceIn(0f, 1f)
        val fadeOut = ((1f - phase) / 0.22f).coerceIn(0f, 1f)
        val envelope = min(fadeIn, fadeOut)
        val pulse = 0.92f + 0.08f * sin(phase * PI * 3).toFloat()
        val shader = edgeShader ?: return
        matrix.setRotate(-35f + phase * 80f + 6f * sin(phase * PI * 2).toFloat(), width / 2f, height / 2f)
        shader.setLocalMatrix(matrix)
        path.reset()
        val inset = 1.5f * density
        val radius = min(36f * density, min(width, height) * 0.12f)
        path.addRoundRect(RectF(inset, inset, width - inset, height - inset), radius, radius, Path.Direction.CW)
        paint.shader = shader
        // Layered translucent strokes give a soft inward halo on the hardware
        // canvas. The clear centre keeps the live camera fully visible.
        for (layer in 12 downTo 1) {
            paint.strokeWidth = (3f + layer * layer * 0.38f) * density * pulse
            paint.alpha = (envelope * (4 + (12 - layer) * 1.2f)).toInt().coerceIn(0, 255)
            canvas.drawPath(path, paint)
        }
        paint.strokeWidth = 3f * density
        paint.alpha = (235 * envelope).toInt()
        canvas.drawPath(path, paint)
        paint.shader = null
        paint.color = Color.WHITE
        paint.strokeWidth = 0.8f * density
        paint.alpha = (100 * envelope).toInt()
        canvas.drawPath(path, paint)
    }

    private fun personRect(): RectF? {
        val person = frame ?: return null
        val camera = viewport ?: return null
        if (camera.width <= 0 || camera.height <= 0) return null
        camera.getLocationOnScreen(cameraLocation)
        getLocationOnScreen(ownLocation)
        val x = (cameraLocation[0] - ownLocation[0]).toFloat()
        val y = (cameraLocation[1] - ownLocation[1]).toFloat()
        val scale = max(camera.width.toFloat() / imageWidth, camera.height.toFloat() / imageHeight)
        val scaledWidth = imageWidth * scale
        val scaledHeight = imageHeight * scale
        val offsetX = x + (camera.width - scaledWidth) / 2f
        val offsetY = y + (camera.height - scaledHeight) / 2f
        val rect = RectF(
            offsetX + person.left * scaledWidth, offsetY + person.top * scaledHeight,
            offsetX + person.right * scaledWidth, offsetY + person.bottom * scaledHeight,
        )
        val padding = 8f * density
        if (!rect.intersect(x + padding, y + padding, x + camera.width - padding, y + camera.height - padding)) return null
        return rect.takeIf { it.width() > padding && it.height() > padding }
    }

    private fun drawPersonTrail(canvas: Canvas, phase: Float) {
        val target = personRect() ?: return
        if (!frameInitialized) {
            animatedFrame.set(target)
            frameInitialized = true
        } else {
            // Smooth inference updates so the travelling line does not jump
            // when a hand is lowered after voting.
            animatedFrame.set(
                animatedFrame.left + (target.left - animatedFrame.left) * 0.22f,
                animatedFrame.top + (target.top - animatedFrame.top) * 0.22f,
                animatedFrame.right + (target.right - animatedFrame.right) * 0.22f,
                animatedFrame.bottom + (target.bottom - animatedFrame.bottom) * 0.22f,
            )
        }
        val rect = animatedFrame
        path.reset()
        val radius = min(36f * density, rect.width() * 0.18f)
        path.addRoundRect(rect, radius, radius, Path.Direction.CW)
        measure.setPath(path, true)
        val length = measure.length
        if (length <= 0f) return
        paint.shader = null
        paint.color = 0xFF8BDFFF.toInt()
        // One luminous line travels clockwise around the person's bounds.
        val tail = 0.22f
        for (i in 0 until 24) {
            val fraction = (i + 1) / 24f
            val head = phase - tail + tail * fraction
            for (range in movingTrail(head, tail / 24f)) {
                segment.reset()
                measure.getSegment(range.start * length, range.end * length, segment, true)
                paint.strokeWidth = 11f * density
                paint.alpha = (35 * fraction).toInt()
                canvas.drawPath(segment, paint)
                paint.strokeWidth = 2.8f * density
                paint.alpha = (255 * fraction * fraction).toInt()
                canvas.drawPath(segment, paint)
            }
        }
        paint.color = Color.WHITE
        paint.strokeWidth = 2.8f * density
        paint.alpha = 255
        for (range in movingTrail(phase, 0.012f)) {
            segment.reset()
            measure.getSegment(range.start * length, range.end * length, segment, true)
            canvas.drawPath(segment, paint)
        }
    }

    override fun onDetachedFromWindow() {
        mode = EffectMode.NONE
        super.onDetachedFromWindow()
    }
}
