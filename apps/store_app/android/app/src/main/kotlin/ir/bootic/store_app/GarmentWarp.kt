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
    private val neckFloor:Float by lazy {
        val mid=(pixel(11)+pixel(12))*.5f;val down=targetHem-mid
        val axis=down*(1f/down.length.coerceAtLeast(1f))
        var floor=-.08f
        if(listOf(9,10).all { points[it].finite&&points[it].visibility>=.6f&&points[it].presence>=.6f }) {
            val mouth=(pixel(9)+pixel(10))*.5f-mid
            val depth=mouth.x*axis.x+mouth.y*axis.y
            val faceFloor=(depth+(pixel(11)-pixel(12)).length*.12f)/down.length.coerceAtLeast(1f)
            if(depth in -(pixel(11)-pixel(12)).length..down.length*.3f && faceFloor<.65f)floor=max(floor,faceFloor)
        }
        floor
    }
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
    private fun referenceAt(local:GPoint):GPoint {
        // Source collars above their shoulder anchors must not extrapolate an
        // arbitrary distance up the face. This is monotonic, with unit slope at 0.
        val bounded=if(local.y<0f).08f*local.y/(.08f-local.y) else local.y
        // Face protection belongs in the safe reference, so topology fallback
        // cannot undo it. Both maps are monotonic in v, and the hem stays fixed.
        // Only the central neck/chest moves for a bowed head; shoulders stay pinned.
        val central=1f-smoothUnit((abs(local.x)-.35f)/.15f)
        val v=bounded+(neckFloor+.08f)*((1f-bounded)/1.08f).coerceIn(0f,1f)*central
        val left=pixel(leftIndex);val right=pixel(rightIndex);val mid=(left+right)*.5f
        return mid+(right-left)*local.x+(targetHem-mid)*v
    }
    fun referenceTorso(source:GPoint)=referenceAt(photoSurface.torsoLocal(source))
    private fun rawTorso(local:GPoint):GPoint {
        // A silhouette correction belongs at the outer shoulder. Translating the
        // whole affine frame by it used to lift the neck and resize the chest.
        val weight=smoothUnit((abs(local.x)-.35f)/.15f)*(1f-smoothUnit(max(local.y,0f)/.3f))
        val correction=if(local.x<0f)targetLeft-pixel(leftIndex) else targetRight-pixel(rightIndex)
        return referenceAt(local)+correction*weight
    }
    fun torso(source: GPoint): GPoint {
        val local=photoSurface.torsoLocal(source)
        return rawTorso(local)
    }
    /** One continuous field for the entire photo grid. A shared source vertex
     * has exactly one destination on either side of an armhole. */
    fun surface(source: GPoint): GPoint = surface(photoSurface.sample(source))

    private fun strength()=if(volumeStrength.isFinite())volumeStrength.coerceIn(0f,.25f) else 0f
    fun bodySurface(sample:PhotoSurface.Sample):GPoint {
        val base=torso(sample.source)
        return base+fitDelta(sample.torsoLocal,0)+(torso(sample.source+sample.torsoRoll)-base)*strength()
    }
    fun surface(sample: PhotoSurface.Sample,torso:GPoint=bodySurface(sample)): GPoint {
        var result=torso
        for((i,part) in spec.sleeves.withIndex()) {
            val weight=sample.weights[i]
            if(weight>0f) {
                val partIndex=if(part.side=="left")leftIndex else rightIndex
                val mapped=sleeve(sample.source,part)
                val fitted=mapped+fitDelta(sample.sleeveLocal[i],partIndex)*sleeveBlend(sample.source,part)+
                    (sleeve(sample.source+sample.sleeveRoll[i],part)-mapped)*strength()
                result+=(fitted-torso)*weight
            }
        }
        return result
    }

    private data class FitRow(val fraction:Float,val negative:GPoint,val positive:GPoint)
    private val fittedRows:Map<Int,List<FitRow>> by lazy {
        bodyEdges?.sections.orEmpty().groupBy { it.part }.mapValues { (index,rows) ->
            val part=spec.sleeves.find { (if(it.side=="left")leftIndex else rightIndex)==index }
            rows.mapNotNull { row ->
                if(index!=0 && part==null)return@mapNotNull null
                val fraction=if(part==null)row.fraction else row.fraction*
                    (pixel(index+2)-(bodyEdges?.shoulder(index)?:pixel(index))).length/sleeveLength(part,index).coerceAtLeast(1f)
                if(fraction<=.01f || fraction>=.99f)return@mapNotNull null
                val cross=if(part==null)photoSurface.torsoCross(fraction) else photoSurface.sleeveCross(part,fraction)
                cross ?: return@mapNotNull null
                fun correction(q:GPoint):GPoint {
                    val mapped=(if(part==null)torso(q) else sleeve(q,part))-row.center
                    val signed=mapped.x*row.normal.x+mapped.y*row.normal.y
                    val observed=(if(signed<0f)row.negative else row.positive)?:return GPoint(0f,0f)
                    val x=if(part==null)photoSurface.torsoLocal(q).x else photoSurface.sleeveLocal(q,part).x
                    if(abs(x)<.01f || abs(signed)<1f)return GPoint(0f,0f)
                    val limit=(targetRight-targetLeft).length*(if(part==null).10f else .05f)
                    val delta=(observed-abs(signed)).coerceIn(-limit,limit)*(if(signed<0f)-1f else 1f)
                    return row.normal*(delta/abs(x))
                }
                FitRow(fraction,correction(cross.negative),correction(cross.positive))
            }.sortedBy { it.fraction }
        }
    }
    private fun fitDelta(local:GPoint,index:Int):GPoint {
        val rows=fittedRows[index].orEmpty()
        if(rows.isEmpty() || local.y<=0f || local.y>=1f)return GPoint(0f,0f)
        val zero=GPoint(0f,0f)
        var a=FitRow(0f,zero,zero);var b=FitRow(1f,zero,zero)
        for(row in rows) { if(row.fraction<=local.y)a=row else { b=row;break } }
        val t=smoothUnit((local.y-a.fraction)/(b.fraction-a.fraction).coerceAtLeast(.001f))
        val da=if(local.x<0f)a.negative else a.positive
        val db=if(local.x<0f)b.negative else b.positive
        return (da*(1f-t)+db*t)*abs(local.x)
    }
    private fun sleeveLength(part:SleeveSpec,index:Int):Float {
        val start=bodyEdges?.shoulder(index)?:pixel(index)
        val arm=pixel(index+2)-start
        val wrist=points[index+4]
        val forearm=if(wrist.finite&&wrist.visibility>=.3f&&wrist.presence>=.5f)pixel(index+4)-pixel(index+2) else arm
        val scale=(targetRight-targetLeft).length/max(1f,(spec.rightShoulder-spec.leftShoulder).length)
        return minOf((part.hem-part.shoulder).length*scale,arm.length+forearm.length)
    }
    private fun sleeveBlend(source:GPoint,part:SleeveSpec):Float {
        val seam=part.armpit-part.shoulder
        val determinant=seam.cross(part.hem-part.shoulder)
        return if(abs(determinant)<1f)0f else smoothUnit(seam.cross(source-part.shoulder)/determinant)
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
        val targetLength = sleeveLength(sleeve,shoulderIndex)
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
        val weight=sleeveBlend(source,sleeve)
        return base * (1f - weight) + articulated * weight
    }
}
