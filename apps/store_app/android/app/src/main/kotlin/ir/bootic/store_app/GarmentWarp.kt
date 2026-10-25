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
    val torsoPolygon: List<GPoint> = emptyList(),
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
            return GarmentRenderSpec(width, height, polygon(map["outer"]), holes, left, right, hem, sleeves, map["mirrorTexture"] == true,
                map["torso"]?.let(::polygon) ?: emptyList())
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
    private val photoSurface: PhotoSurface = PhotoSurface(spec),
    private val volumeStrength: Float = .16f,
) {
    private val leftIndex: Int
    private val rightIndex: Int
    private fun pixel(index: Int) = GPoint(points[index].x * imageWidth, points[index].y * imageHeight)
    private val targetLeft: GPoint
    private val targetRight: GPoint
    private val targetHem: GPoint
    private val sectionRows=bodyEdges?.sections?.groupBy { it.part }.orEmpty()
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
    fun surface(source: GPoint): GPoint = surface(photoSurface.sample(source))

    fun surface(sample: PhotoSurface.Sample): GPoint {
        val base=torso(sample.source)
        val torso=fitCrossSection(base,sample.torsoCross,0)
        var result=torso
        var sleeveWeight=0f
        for((i,part) in spec.sleeves.withIndex()) {
            val weight=sample.weights[i]
            if(weight>0f) {
                val partIndex=if(part.side=="left")leftIndex else rightIndex
                val mapped=sleeve(sample.source,part)
                val fitted=fitCrossSection(mapped,sample.sleeveCross[i],partIndex,part)
                result+=(fitted-torso)*weight
                sleeveWeight+=weight
            }
        }
        val strength=if(volumeStrength.isFinite())volumeStrength.coerceIn(0f,.25f) else 0f
        if(strength==0f)return result
        // Volume changes only transverse interior coordinates, after boundary fit.
        var curve=curveDelta(sample.torsoCross,null)*((1f-sleeveWeight)*sample.torsoFade)
        for((i,part) in spec.sleeves.withIndex())if(sample.weights[i]>0f)
            curve+=curveDelta(sample.sleeveCross[i],part)*sample.weights[i]
        return result+curve*strength
    }

    private fun curveDelta(cross:PhotoSurface.Cross?,part:SleeveSpec?):GPoint {
        cross ?: return GPoint(0f,0f)
        val s=cross.unit.coerceIn(-1f,1f)
        val sourceDelta=(cross.positive-cross.negative)*(.25f*s*(1f-s*s))
        if(part==null)return torso(cross.center+sourceDelta)-torso(cross.center)
        return sleeve(cross.center+sourceDelta,part)-sleeve(cross.center,part)
    }

    private fun fitCrossSection(base:GPoint,cross:PhotoSurface.Cross?,partIndex:Int,part:SleeveSpec?=null):GPoint {
        cross ?: return base
        val rows=sectionRows[partIndex].orEmpty()
        if(rows.isEmpty())return base
        val sourceNegative=cross.unit<0f
        fun map(q:GPoint)=if(part==null)torso(q) else sleeve(q,part)
        val edge=map(if(sourceNegative)cross.negative else cross.positive)
        // Interpolate corrections; fade outside observed rows instead of extending
        // an uncertain mask measurement to collar, cuff or hem.
        var weighted=GPoint(0f,0f);var total=0f
        for(row in rows) {
            val offset=edge-row.center
            val negative=offset.x*row.normal.x+offset.y*row.normal.y<0f
            val observed=(if(negative)row.negative else row.positive) ?: continue
            val normal=row.normal*(if(negative)-1f else 1f)
            val fromCenter=edge-row.center
            val expected=fromCenter.x*normal.x+fromCenter.y*normal.y
            if(expected<1f)continue
            val target=observed
            // Preserve product proportions: this is a bounded refinement, not
            // stretching the virtual garment to cover every pixel of old clothes.
            val limit=(targetRight-targetLeft).length*(if(part==null).12f else .06f)
            val correction=(target-expected).coerceIn(-limit,limit)
            val fraction=if(part==null)cross.fraction else {
                val shoulder=if(partIndex==leftIndex)targetLeft else targetRight
                (map(cross.center)-shoulder).length/(pixel(partIndex+2)-shoulder).length.coerceAtLeast(1f)
            }
            val weight=smoothUnit(1f-abs(fraction-row.fraction)/.30f)
            weighted+=normal*(correction*weight);total+=weight
        }
        if(total==0f)return base
        val pin=if(part==null)smoothUnit(cross.fraction/.20f)*(1f-smoothUnit((cross.fraction-.8f)/.2f)) else 1f
        return base+weighted*(minOf(1f,total)/total*abs(cross.unit).coerceIn(0f,1f)*pin)
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
