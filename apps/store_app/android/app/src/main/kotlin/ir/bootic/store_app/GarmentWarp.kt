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
    private val bodyEdges: BodyEdges? = null,
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
        targetLeft = bodyEdges?.shoulder(leftIndex) ?: pixel(leftIndex)
        targetRight = bodyEdges?.shoulder(rightIndex) ?: pixel(rightIndex)
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
    /** One continuous field for the entire photo grid. A shared source vertex
     * has exactly one destination on either side of an armhole. */
    fun surface(source: GPoint, lag: GPoint = GPoint(0f, 0f)): GPoint {
        var result = torso(source)
        for (part in spec.sleeves) result += sleeve(source, part) - torso(source)
        val a = spec.rightShoulder - spec.leftShoulder
        val b = spec.hem - spec.leftShoulder
        val v = (a.cross(source-spec.leftShoulder)/a.cross(b)).coerceIn(0f,1f)
        // A lifted arm pulls the surrounding underarm cloth continuously. The
        // influence fades before collar/hem and is relative to this body's axes.
        val down=targetHem-(targetLeft+targetRight)*.5f
        val sourceWidth=(spec.rightShoulder-spec.leftShoulder).length
        val pin=minOf((source-spec.leftShoulder).length,(source-spec.rightShoulder).length)
            .div(max(1f,sourceWidth*.12f)).coerceIn(0f,1f)
        for(part in spec.sleeves) {
            val i=if(part.side=="left")leftIndex else rightIndex
            val elbow=points[i+2]
            if(!elbow.finite || elbow.visibility<.5f || elbow.presence<.5f)continue
            val arm=pixel(i+2)-pixel(i)
            val dot=(arm.x*down.x+arm.y*down.y)/max(1f,arm.length*down.length)
            val lift=((.8f-dot)/1.8f).coerceIn(0f,1f)
            val radius=max(1f,sourceWidth*.24f)
            val distance=(source-part.armpit).length/radius
            val falloff=kotlin.math.exp(-distance*distance*2f)*pin*(1f-v*v)
            result-=down*(.06f*lift*falloff)
        }
        // Neck/shoulders are pinned; lower cloth follows with bounded inertia.
        return result + lag * (v*v)
    }
    fun sleeve(source: GPoint, sleeve: SleeveSpec): GPoint {
        val base = torso(source)
        val shoulderIndex = if (sleeve.side == "left") leftIndex else rightIndex
        val elbowIndex = shoulderIndex + 2
        val elbow = points[elbowIndex]
        if (!elbow.finite || elbow.visibility < 0.3f || elbow.presence < 0.5f) return base
        val start = bodyEdges?.shoulder(shoulderIndex) ?: pixel(shoulderIndex)
        val arm = pixel(elbowIndex) - start
        val sourceArm = sleeve.hem - sleeve.shoulder
        if (arm.length < 1f || sourceArm.length < 1f) return base
        val shoulderScale = (targetRight - targetLeft).length / max(1f, (spec.rightShoulder - spec.leftShoulder).length)
        val wrist = points[shoulderIndex+4]
        val forearm = if(wrist.finite && wrist.visibility>=.3f && wrist.presence>=.5f)
            pixel(shoulderIndex+4)-pixel(elbowIndex) else arm
        val targetLength = minOf(sourceArm.length * shoulderScale, arm.length+forearm.length)
        val denominator = sourceArm.x * sourceArm.x + sourceArm.y * sourceArm.y
        val q = source - sleeve.shoulder
        val u = (sourceArm.x*q.x + sourceArm.y*q.y)/denominator
        val v = sourceArm.cross(q)/denominator
        val orientation = if ((targetRight-targetLeft).cross(targetHem-targetLeft) *
            (spec.rightShoulder-spec.leftShoulder).cross(spec.hem-spec.leftShoulder) < 0f) -1f else 1f
        val distance=(u*targetLength).coerceAtLeast(0f)
        val along=if(distance<=arm.length)arm else forearm
        val axis=along*(1f/max(1f,along.length))
        val center=if(distance<=arm.length)start+axis*distance
            else pixel(elbowIndex)+axis*(distance-arm.length)
        val articulated = center + GPoint(-axis.y,axis.x)*(v*sourceArm.length*shoulderScale*orientation)
        // The shoulder-to-underarm seam stays exactly attached to the torso.
        val seam = sleeve.armpit - sleeve.shoulder
        val seamDistance = seam.cross(sourceArm)
        if (abs(seamDistance) < 1f) return base
        val t = (seam.cross(q) / seamDistance).coerceIn(0f, 1f)
        val weight = t*t*(3f-2f*t)
        return base * (1f - weight) + articulated * weight
    }
}
