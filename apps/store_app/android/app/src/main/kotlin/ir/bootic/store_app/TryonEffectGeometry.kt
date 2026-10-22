package ir.bootic.store_app

import kotlin.math.max
import kotlin.math.min

internal data class BodyPoint(val x: Float, val y: Float, val visible: Boolean = true)

/** Bounds of the visible person, separate from the garment's torso placement. */
internal data class PersonFrame(val left: Float, val top: Float, val right: Float, val bottom: Float) {
    companion object {
        fun enclose(points: List<BodyPoint>, headPadding: Float): PersonFrame? {
            val valid = points.filter {
                it.visible && it.x.isFinite() && it.y.isFinite() &&
                    it.x in -0.05f..1.05f && it.y in -0.05f..1.05f
            }
            if (valid.size < 2) return null
            val left = valid.minOf { it.x }
            val right = valid.maxOf { it.x }
            val top = valid.minOf { it.y }
            val bottom = valid.maxOf { it.y }
            val paddingX = max(0.012f, (right - left) * 0.08f)
            val paddingY = max(0.012f, (bottom - top) * 0.025f)
            return PersonFrame(
                max(0f, left - paddingX), max(0f, top - max(headPadding, paddingY)),
                min(1f, right + paddingX), min(1f, bottom + paddingY),
            )
        }
    }
}

internal enum class EffectMode(val wireName: String, val durationMs: Long) {
    NONE("none", 0), DETECTION("detection", 1200), LOADING("loading", 2000);

    val blocksGarment: Boolean get() = this == LOADING

    fun phaseAt(elapsedMs: Long): Float = when (this) {
        NONE -> 0f
        DETECTION -> (elapsedMs.toFloat() / durationMs).coerceIn(0f, 1f)
        LOADING -> (max(0L, elapsedMs) % durationMs).toFloat() / durationMs
    }
}

internal data class TrailRange(val start: Float, val end: Float)

/** Clockwise path interval with a trailing tail, split correctly at the seam. */
internal fun movingTrail(progress: Float, fraction: Float): List<TrailRange> {
    val end = ((progress % 1f) + 1f) % 1f
    val length = fraction.coerceIn(0f, 1f)
    if (length == 0f) return emptyList()
    val start = end - length
    return if (start < 0f) listOf(TrailRange(start + 1f, 1f), TrailRange(0f, end)).filter { it.end > it.start }
        else listOf(TrailRange(start, end))
}
