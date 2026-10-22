package ir.bootic.store_app

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/** Confidence mask in the SAME rotated/mirrored image coordinates as the pose.
 * The sampler is consumed synchronously; no image/buffer escapes the callback. */
internal class BodyMask(val width: Int, val height: Int, private val sample: (Int, Int) -> Float) {
    fun at(x: Float, y: Float): Float {
        if (!x.isFinite() || !y.isFinite() || x !in 0f..1f || y !in 0f..1f || width < 2 || height < 2) return Float.NaN
        val px = (x * width - .5f).coerceIn(0f, width - 1f)
        val py = (y * height - .5f).coerceIn(0f, height - 1f)
        val ix = floor(px).toInt(); val iy = floor(py).toInt()
        val dx = px-ix; val dy = py-iy
        val a = sample(ix, iy); val b = sample(min(ix+1, width-1), iy)
        val c = sample(ix, min(iy+1, height-1)); val d = sample(min(ix+1, width-1), min(iy+1, height-1))
        return (a*(1-dx)+b*dx)*(1-dy)+(c*(1-dx)+d*dx)*dy
    }
}

internal data class BodyEdges(
    val shoulder11: GPoint? = null, val shoulder12: GPoint? = null,
    val lift11: Float = 0f, val lift12: Float = 0f,
    // Unconnected normalized boundary samples, NOT an invented body polygon.
    val contour: List<GPoint> = emptyList(), val status: String = "no_boundary",
    val maskWidth: Int = 0, val maskHeight: Int = 0,
) {
    fun shoulder(index: Int): GPoint? = if (index == 11) shoulder11 else shoulder12
}

/** Locate a surface seam above each joint, using image evidence, never a fixed
 * centimetre/pixel offset. Raw landmarks remain unchanged for tracking/voting.
 * Missing, occluded, ambiguous and out-of-frame boundaries fall back to joints. */
internal object BodyEdgeFit {
    fun refine(pose: PoseObservation, mask: BodyMask, includeContour: Boolean = true): BodyEdges {
        val contour = if (includeContour) contour(mask) else emptyList()
        fun result(status: String) = BodyEdges(contour=contour, status=status, maskWidth=mask.width, maskHeight=mask.height)
        if (pose.box == null || pose.points.size <= 24) return result("pose_rejected")
        fun pixel(i: Int) = GPoint(pose.points[i].x*pose.imageWidth, pose.points[i].y*pose.imageHeight)
        val shoulderMid = (pixel(11)+pixel(12))*.5f
        val hipMid = (pixel(23)+pixel(24))*.5f
        val axis = hipMid-shoulderMid
        val length = axis.length
        if (!length.isFinite() || length < 1f) return result("pose_rejected")
        val up = axis*(-1f/length)
        val across = GPoint(-up.y, up.x)
        val span = (pixel(11)-pixel(12)).length
        // Less than three mask pixels across the search band is insufficient evidence.
        val maskPixel = max(pose.imageWidth.toFloat()/mask.width, pose.imageHeight.toFloat()/mask.height)
        val limit = length*.20f
        if (limit < maskPixel*3) return result("too_small")
        fun confidence(p: GPoint) = mask.at(p.x/pose.imageWidth, p.y/pose.imageHeight)
        fun lift(index: Int): Float? {
            val joint = pose.points[index]
            if (!joint.finite || joint.visibility < .65f || joint.presence < .65f) return null
            val origin = pixel(index)
            val hits = mutableListOf<Float>()
            for (ray in -2..2) {
                val start = origin + across*(ray*span*.02f)
                if (!(confidence(start) >= .7f)) continue
                var crossing: Float? = null
                var background = false
                // Fixed sample count bounds work, while distances scale with torso size.
                for (step in 1..40) {
                    val distance = limit*step/40
                    val value = confidence(start+up*distance)
                    if (!value.isFinite()) break
                    if (crossing == null && value <= .5f) crossing = distance
                    if (crossing != null && value >= .7f) break // hole/noise rather than outer boundary
                    if (crossing != null && value <= .25f) {
                        // Require background beyond the crossing as well.
                        background = confidence(start+up*(distance+maskPixel)) <= .25f
                        break
                    }
                }
                if (background && crossing != null) hits.add(crossing)
            }
            if (hits.size < 3) return null
            hits.sort()
            if (hits.last()-hits.first() > max(length*.045f, maskPixel*2)) return null
            return hits[hits.size/2]
        }
        val a = lift(11); val b = lift(12)
        return BodyEdges(a?.let { pixel(11)+up*it }, b?.let { pixel(12)+up*it }, a?:0f, b?:0f,
            contour, if (a!=null && b!=null) "both" else if (a!=null || b!=null) "partial" else "no_boundary", mask.width, mask.height)
    }

    private fun contour(mask: BodyMask): List<GPoint> {
        // Bounded diagnostic payload; no full mask crosses the Flutter channel.
        val n=96
        val values=Array(n+1) { y -> FloatArray(n+1) { x -> mask.at(x.toFloat()/n,y.toFloat()/n) } }
        val points=ArrayList<GPoint>()
        for(y in 0 until n) for(x in 0 until n) {
            val a=values[y][x]; val b=values[y][x+1]; val c=values[y+1][x]
            if (!a.isFinite()) continue
            if (b.isFinite() && (a>=.5f)!=(b>=.5f)) points.add(GPoint((x+.5f)/n,y.toFloat()/n))
            if (c.isFinite() && (a>=.5f)!=(c>=.5f)) points.add(GPoint(x.toFloat()/n,(y+.5f)/n))
            if(points.size>=1200) return points
        }
        return points
    }
}
