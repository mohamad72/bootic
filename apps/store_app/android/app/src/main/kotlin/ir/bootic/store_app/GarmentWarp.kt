package ir.bootic.store_app

import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max

internal data class GPoint(val x: Float, val y: Float) {
    operator fun plus(p: GPoint) = GPoint(x + p.x, y + p.y)
    operator fun minus(p: GPoint) = GPoint(x - p.x, y - p.y)
    operator fun times(s: Float) = GPoint(x * s, y * s)
    fun cross(p: GPoint) = x * p.y - y * p.x
    val length get() = hypot(x, y)
}
internal data class SleeveSpec(val side: String, val polygon: List<GPoint>, val shoulder: GPoint, val armpit: GPoint, val hem: GPoint)
internal data class GarmentRenderSpec(
    val width: Float, val height: Float,
    val outer: List<GPoint>, val holes: List<List<GPoint>>,
    val leftShoulder: GPoint, val rightShoulder: GPoint, val hem: GPoint,
    val sleeves: List<SleeveSpec>, val mirrorTexture: Boolean,
) {
    companion object {
        fun fromMap(map: Map<*, *>): GarmentRenderSpec {
            require(map["schema"] == "bootic.garment-metadata/0.1")
            val width = (map["width"] as Number).toFloat()
            val height = (map["height"] as Number).toFloat()
            require(width in 64f..6000f && height in 64f..6000f)
            fun point(value: Any?): GPoint {
                val a = value as List<*>
                require(a.size == 2)
                return GPoint((a[0] as Number).toFloat(), (a[1] as Number).toFloat()).also {
                    require(it.x.isFinite() && it.y.isFinite() && it.x in 0f..width && it.y in 0f..height)
                }
            }
            fun polygon(value: Any?): List<GPoint> = (value as List<*>).also { require(it.size in 3..1024) }.map(::point)
            val anchors = map["anchors"] as Map<*, *>
            val left = point(anchors["shoulder_image_left"])
            val right = point(anchors["shoulder_image_right"])
            val hem = point(anchors["hem_center"])
            require(abs((right - left).cross(hem - left)) >= 1f)
            val sleeves = (map["sleeves"] as List<*>).also { require(it.size <= 2) }.map {
                val s = it as Map<*, *>
                val side = s["side"] as String
                require(side == "left" || side == "right")
                SleeveSpec(side, polygon(s["polygon"]), point(s["shoulder"]), point(s["armpit"]), point(s["hem"]))
            }
            val holes = (map["holes"] as List<*>).also { require(it.size <= 16) }.map(::polygon)
            return GarmentRenderSpec(width, height, polygon(map["outer"]), holes, left, right, hem, sleeves, map["mirrorTexture"] == true)
        }
    }
}

/** Source-pixel anchors, never the image rectangle's centre, define the fit.
 * Targets are already rotated/mirrored pose pixels. Only texture-side swapping
 * is applied here when the front-camera texture is requested to be mirrored. */
internal class GarmentWarp(
    private val spec: GarmentRenderSpec, private val points: List<PosePoint>,
    private val imageWidth: Int, private val imageHeight: Int, mirror: Boolean,
) {
    private val leftIndex: Int
    private val rightIndex: Int
    private fun pixel(index: Int) = GPoint(points[index].x * imageWidth, points[index].y * imageHeight)
    private val targetLeft: GPoint
    private val targetRight: GPoint
    private val targetHem: GPoint
    init {
        require(points.size > 24 && imageWidth > 0 && imageHeight > 0)
        val screenLeft = if (points[11].x <= points[12].x) 11 else 12
        val screenRight = if (screenLeft == 11) 12 else 11
        val swap = mirror && spec.mirrorTexture
        leftIndex = if (swap) screenRight else screenLeft
        rightIndex = if (swap) screenLeft else screenRight
        targetLeft = pixel(leftIndex)
        targetRight = pixel(rightIndex)
        targetHem = (pixel(23) + pixel(24)) * 0.5f
    }
    fun torso(source: GPoint): GPoint {
        val a = spec.rightShoulder - spec.leftShoulder
        val b = spec.hem - spec.leftShoulder
        val q = source - spec.leftShoulder
        val determinant = a.cross(b)
        val u = q.cross(b) / determinant
        val v = a.cross(q) / determinant
        return targetLeft + (targetRight - targetLeft) * u + (targetHem - targetLeft) * v
    }
    fun sleeve(source: GPoint, sleeve: SleeveSpec): GPoint {
        val base = torso(source)
        val shoulderIndex = if (sleeve.side == "left") leftIndex else rightIndex
        val elbowIndex = shoulderIndex + 2
        val elbow = points[elbowIndex]
        if (!elbow.finite || elbow.visibility < 0.3f || elbow.presence < 0.5f) return base
        val start = pixel(shoulderIndex)
        val arm = pixel(elbowIndex) - start
        val sourceArm = sleeve.hem - sleeve.shoulder
        if (arm.length < 1f || sourceArm.length < 1f) return base
        val shoulderScale = (targetRight - targetLeft).length / max(1f, (spec.rightShoulder - spec.leftShoulder).length)
        val targetLength = minOf(sourceArm.length * shoulderScale, arm.length * 0.75f)
        val destinationArm = arm * (targetLength / arm.length)
        val denominator = sourceArm.x * sourceArm.x + sourceArm.y * sourceArm.y
        val q = source - sleeve.shoulder
        val u = (sourceArm.x*q.x + sourceArm.y*q.y)/denominator
        val v = sourceArm.cross(q)/denominator
        val orientation = if ((targetRight-targetLeft).cross(targetHem-targetLeft) *
            (spec.rightShoulder-spec.leftShoulder).cross(spec.hem-spec.leftShoulder) < 0f) -1f else 1f
        val articulated = start + destinationArm*u + GPoint(-destinationArm.y, destinationArm.x)*(v*orientation)
        // The shoulder-to-underarm seam stays exactly attached to the torso.
        val seam = sleeve.armpit - sleeve.shoulder
        val seamDistance = seam.cross(sourceArm)
        if (abs(seamDistance) < 1f) return base
        val weight = (seam.cross(q) / seamDistance).coerceIn(0f, 1f)
        return base * (1f - weight) + articulated * weight
    }
}
