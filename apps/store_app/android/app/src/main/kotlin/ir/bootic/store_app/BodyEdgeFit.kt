package ir.bootic.store_app

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.abs

/** Distances along a local cross-section normal, in pose-image pixels. A null
 * side has no trustworthy exterior boundary (e.g. an arm touching the torso). */
internal data class BodySection(
    val part:Int, val fraction:Float, val center:GPoint, val normal:GPoint,
    val negative:Float?, val positive:Float?,
)

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
    val sections: List<BodySection> = emptyList(),
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
            contour, if (a!=null && b!=null) "both" else if (a!=null || b!=null) "partial" else "no_boundary", mask.width, mask.height,
            sections(pose,mask,maskPixel))
    }

    private fun sections(pose:PoseObservation,mask:BodyMask,maskPixel:Float):List<BodySection> {
        fun p(i:Int)=GPoint(pose.points[i].x*pose.imageWidth,pose.points[i].y*pose.imageHeight)
        fun reliable(i:Int)=pose.points[i].finite && pose.points[i].visibility>=.65f && pose.points[i].presence>=.65f
        fun confidence(q:GPoint)=mask.at(q.x/pose.imageWidth,q.y/pose.imageHeight)
        val span=(p(11)-p(12)).length
        fun boundary(center:GPoint,axis:GPoint,normal:GPoint,limit:Float):Float? {
            if(limit<maskPixel*3)return null
            val hits=ArrayList<Float>(3)
            for(ray in -1..1) {
                val origin=center+axis*(ray*max(maskPixel,span*.012f))
                if(confidence(origin)<.7f || !confidence(origin).isFinite())continue
                var crossing:Float?=null
                for(step in 1..48) {
                    val d=limit*step/48
                    val value=confidence(origin+normal*d)
                    if(!value.isFinite())break
                    if(crossing==null && value<=.5f)crossing=d
                    if(crossing!=null && value>=.7f)break
                    if(crossing!=null && value<=.25f) {
                        if(confidence(origin+normal*(d+maskPixel*2))<=.25f)hits.add(crossing)
                        break
                    }
                }
            }
            if(hits.size<3)return null
            hits.sort()
            return hits[1].takeIf { hits[2]-hits[0]<=max(maskPixel*2,span*.035f) && it>=maskPixel*2 }
        }
        val rows=ArrayList<BodySection>(7)
        fun add(part:Int,start:GPoint,end:GPoint,fractions:List<Float>,limit:Float) {
            val direction=end-start
            if(direction.length<span*.15f)return
            val axis=direction*(1f/direction.length)
            val normal=GPoint(axis.y,-axis.x)
            for(t in fractions) {
                val center=start+direction*t
                fun side(sign:Float):Float? {
                    val n=normal*sign
                    val hit=boundary(center,axis,n,limit) ?: return null
                    if(part==0) {
                        // A nearby upper arm can merge with the person silhouette.
                        // Such a boundary is not evidence for the side of the torso.
                        val q=center+n*hit
                        for(i in listOf(11,12,13,14)) if(reliable(i)&&reliable(i+2)) {
                            val a=p(i);val b=p(i+2);val arm=b-a;val ray=q-center
                            val determinant=ray.cross(arm)
                            if(abs(determinant)>.001f) {
                                val t=(a-center).cross(arm)/determinant
                                val u=(a-center).cross(ray)/determinant
                                if(t in 0f..1f && u in 0f..1f)return null
                            }
                            val distance=minOf(PhotoSurface.distanceToSegment(a,center,q),
                                PhotoSurface.distanceToSegment(b,center,q),PhotoSurface.distanceToSegment(center,a,b),
                                PhotoSurface.distanceToSegment(q,a,b))
                            if(distance<span*.13f)return null
                        }
                    }
                    return hit
                }
                val negative=side(-1f);val positive=side(1f)
                if(negative!=null || positive!=null)rows.add(BodySection(part,t,center,normal,negative,positive))
            }
        }
        add(0,(p(11)+p(12))*.5f,(p(23)+p(24))*.5f,listOf(.25f,.5f,.75f),span*.85f)
        for(i in listOf(11,12))if(reliable(i)&&reliable(i+2))
            add(i,p(i),p(i+2),listOf(.35f,.65f),span*.35f)
        return rows
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

/** Filter distances/corrections relative to the CURRENT body, so translation
 * does not drag yesterday's contour behind the person. Missing sides reset. */
internal class BodyEdgeFilter {
    private var previous:BodyEdges?=null
    private var lastTime=0L
    private var lastSpan=0f
    private var lastCenter:GPoint?=null
    private var dimensions=Pair(0,0)
    fun update(pose:PoseObservation,edges:BodyEdges,now:Long):BodyEdges {
        val span=pose.shoulderPx.coerceAtLeast(1f)
        fun pixel(i:Int)=GPoint(pose.points[i].x*pose.imageWidth,pose.points[i].y*pose.imageHeight)
        if(pose.box==null || pose.points.size<25) { previous=null;lastCenter=null;return edges.copy(sections=emptyList(),shoulder11=null,shoulder12=null) }
        val center=(pixel(11)+pixel(12))*.5f
        val dt=now-lastTime
        val before=previous.takeIf { dt in 1..300 && dimensions==Pair(pose.imageWidth,pose.imageHeight) &&
            lastSpan/span in .7f..1.4f && lastCenter?.let { (it-center).length<span*.5f }==true }
        val alpha=(1f-kotlin.math.exp(-dt.coerceAtLeast(1)/90f)).coerceIn(.08f,1f)
        fun blend(current:Float?,old:Float?):Float? {
            if(current==null)return null
            if(old==null || before==null)return current
            val prior=old/lastSpan*span
            return prior+(current-prior).coerceIn(-span*.04f,span*.04f)*alpha
        }
        val rows=edges.sections.map { row ->
            val old=before?.sections?.find { it.part==row.part && it.fraction==row.fraction }
            row.copy(negative=blend(row.negative,old?.negative),positive=blend(row.positive,old?.positive))
        }
        // Shoulder correction is along this frame's torso axis, never a stale XY point.
        val down=(pixel(23)+pixel(24))*.5f-center
        val up=down*(-1f/down.length.coerceAtLeast(1f))
        val lift11=blend(edges.lift11.takeIf { edges.shoulder11!=null },before?.lift11?.takeIf { before.shoulder11!=null })
        val lift12=blend(edges.lift12.takeIf { edges.shoulder12!=null },before?.lift12?.takeIf { before.shoulder12!=null })
        val result=edges.copy(sections=rows,lift11=lift11?:0f,lift12=lift12?:0f,
            shoulder11=lift11?.let { pixel(11)+up*it },shoulder12=lift12?.let { pixel(12)+up*it })
        previous=result;lastTime=now;lastSpan=span;lastCenter=center;dimensions=Pair(pose.imageWidth,pose.imageHeight)
        return result
    }
}
