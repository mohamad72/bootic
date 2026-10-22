package ir.bootic.store_app

import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max

internal data class PosePoint(val x: Float, val y: Float, val visibility: Float, val presence: Float) {
    val finite: Boolean get() = x.isFinite() && y.isFinite() && visibility.isFinite() && presence.isFinite()
}

internal data class TorsoBox(
    val centerX: Float, val centerY: Float, val width: Float, val height: Float,
    val imageWidth: Int, val imageHeight: Int,
    val personFrame: PersonFrame? = null,
    val rotationDegrees: Float = 0f,
)

internal data class Placement(
    val centerX: Float = 0.5f, val centerY: Float = 0.45f,
    val width: Float = 0.45f, val height: Float = 0.5f,
    val rotationDegrees: Float = 0f,
)

/** Same FILL_CENTER transform for the garment, debug landmarks and projector.
 * Do not clamp each component: that stretches/recentres a partially cropped body. */
internal fun TorsoBox.forViewport(viewWidth: Int, viewHeight: Int): Placement {
    val scale = max(viewWidth.toFloat() / imageWidth, viewHeight.toFloat() / imageHeight)
    val sx = imageWidth * scale / viewWidth
    val sy = imageHeight * scale / viewHeight
    return Placement((centerX - 0.5f) * sx + 0.5f, (centerY - 0.5f) * sy + 0.5f,
        width * sx, height * sy, rotationDegrees)
}

internal data class PoseObservation(
    val box: TorsoBox?, val points: List<PosePoint>, val reason: String,
    val imageWidth: Int, val imageHeight: Int,
    val personFrame: PersonFrame? = null,
    val shoulderPx: Float = 0f, val torsoPx: Float = 0f,
    val bodyEdges: BodyEdges? = null, val edgeMs: Long = 0,
)

internal object PoseGeometry {
    const val MODEL_CONFIDENCE = 0.5f
    const val WIDTH_FACTOR = 1.15f
    const val HEIGHT_FACTOR = 1.15f

    fun torso(points: List<PosePoint>, width: Int, height: Int): TorsoBox? = evaluate(points, width, height).box

    fun evaluate(points: List<PosePoint>, width: Int, height: Int): PoseObservation {
        val frame = PersonFrame.enclose(points.map {
            BodyPoint(it.x, it.y, it.finite && it.visibility >= 0.5f && it.presence >= 0.5f)
        }, headPadding = 0.025f)
        fun reject(reason: String, shoulder: Float = 0f, torso: Float = 0f) =
            PoseObservation(null, points, reason, width, height, frame, shoulder, torso)
        if (points.size <= 24 || width <= 0 || height <= 0) return reject("no_pose")
        val ls = points[11]; val rs = points[12]; val lh = points[23]; val rh = points[24]
        val core = listOf(ls, rs, lh, rh)
        if (core.any { !it.finite }) return reject("invalid_landmarks")
        val shoulderPx = hypot((ls.x - rs.x) * width, (ls.y - rs.y) * height)
        val sx = (ls.x + rs.x) / 2f; val sy = (ls.y + rs.y) / 2f
        val hx = (lh.x + rh.x) / 2f; val hy = (lh.y + rh.y) / 2f
        val torsoPx = hypot((hx - sx) * width, (hy - sy) * height)
        // Permit a partially occluded far-side joint during a turn, but require
        // presence for all torso joints and a clearly visible joint on each row.
        if (core.any { it.presence < 0.5f || it.visibility < 0.3f } ||
            max(ls.visibility, rs.visibility) < 0.5f || max(lh.visibility, rh.visibility) < 0.5f)
            return reject("low_confidence", shoulderPx, torsoPx)
        if (core.any { it.x !in -0.05f..1.05f || it.y !in -0.05f..1.05f })
            return reject("torso_out_of_frame", shoulderPx, torsoPx)
        if (shoulderPx < width * 0.02f || shoulderPx > width * 0.8f)
            return reject("shoulder_span", shoulderPx, torsoPx)
        if (hy - sy < 0.08f || torsoPx > height * 0.8f)
            return reject("torso_length", shoulderPx, torsoPx)
        if (abs(hx - sx) * width > max(shoulderPx, torsoPx * 0.6f))
            return reject("torso_alignment", shoulderPx, torsoPx)
        val left = if (ls.x <= rs.x) ls else rs
        val right = if (ls.x <= rs.x) rs else ls
        val angle = Math.toDegrees(atan2(((right.y - left.y) * height).toDouble(),
            ((right.x - left.x) * width).toDouble())).toFloat().coerceIn(-45f, 45f)
        val box = TorsoBox((sx + hx) / 2f, (sy + hy) / 2f,
            shoulderPx / width * WIDTH_FACTOR, torsoPx / height * HEIGHT_FACTOR,
            width, height, frame, angle)
        return PoseObservation(box, points, "accepted", width, height, frame, shoulderPx, torsoPx)
    }
}
