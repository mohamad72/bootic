package ir.bootic.store_app

import kotlin.math.abs
import kotlin.math.max

internal fun smoothUnit(value: Float): Float {
    val t=value.coerceIn(0f,1f)
    return t*t*(3f-2f*t)
}

/** Shared cached grid for phone/projector. If articulation would turn a visible
 * triangle inside out, reduce the deformation toward the fitted affine pose.
 * This conservative fallback trades extreme arm rotation for a valid surface. */
internal class PhotoMesh(spec:GarmentRenderSpec,val columns:Int=48,val rows:Int=64) {
    val surface=PhotoSurface(spec)
    val samples:List<PhotoSurface.Sample>
    val triangles:IntArray
    val boundIndices:IntArray
    private val base:FloatArray
    private val result:FloatArray
    private var lastFrameKey:Any?=null
    private var lastMirror=false
    var deformationScale=1f
        private set
    init {
        require(columns>0 && rows>0)
        samples=(0..rows).flatMap { y -> (0..columns).map { x ->
            surface.sample(GPoint(spec.width*x/columns,spec.height*y/rows))
        } }
        val visible=samples.map { PhotoSurface.contains(it.source,spec.outer) && spec.holes.none { hole -> PhotoSurface.contains(it.source,hole) } }
        val indices=ArrayList<Int>()
        fun add(a:Int,b:Int,c:Int) {
            val center=(samples[a].source+samples[b].source+samples[c].source)*(1f/3f)
            if(visible[a] || visible[b] || visible[c] || PhotoSurface.contains(center,spec.outer) && spec.holes.none { PhotoSurface.contains(center,it) }) {
                indices.add(a);indices.add(b);indices.add(c)
            }
        }
        for(y in 0 until rows)for(x in 0 until columns) {
            val a=y*(columns+1)+x;val b=a+1;val c=a+columns+1;val d=c+1
            add(a,b,c);add(b,d,c)
        }
        triangles=indices.toIntArray()
        boundIndices=indices.distinct().toIntArray()
        base=FloatArray(samples.size*2);result=FloatArray(samples.size*2)
    }
    fun project(warp:GarmentWarp,frameKey:Any?=null,mirror:Boolean=false):FloatArray {
        if(frameKey!=null && frameKey===lastFrameKey && mirror==lastMirror)return result
        for((i,sample) in samples.withIndex()) {
            val a=warp.torso(sample.source);val b=warp.surface(sample)
            base[i*2]=a.x;base[i*2+1]=a.y;result[i*2]=b.x;result[i*2+1]=b.y
        }
        fun safe(amount:Float):Boolean {
            fun x(i:Int)=base[i*2]+(result[i*2]-base[i*2])*amount
            fun y(i:Int)=base[i*2+1]+(result[i*2+1]-base[i*2+1])*amount
            for(i in triangles.indices step 3) {
                val a=triangles[i];val b=triangles[i+1];val c=triangles[i+2]
                val original=(base[b*2]-base[a*2])*(base[c*2+1]-base[a*2+1])-(base[b*2+1]-base[a*2+1])*(base[c*2]-base[a*2])
                val actual=(x(b)-x(a))*(y(c)-y(a))-(y(b)-y(a))*(x(c)-x(a))
                if(!actual.isFinite() || actual*original<=original*original*.025f)return false
            }
            return true
        }
        var amount=1f
        while(amount>.015625f && !safe(amount))amount*=.5f
        if(!safe(amount))amount=0f
        deformationScale=amount
        if(amount<1f)for(i in result.indices)result[i]=if(amount==0f)base[i] else base[i]+(result[i]-base[i])*amount
        lastFrameKey=frameKey;lastMirror=mirror
        return result
    }
}

/** Source-space geometry is prepared on garment selection, never from live pixels. */
internal class PhotoSurface(private val spec: GarmentRenderSpec) {
    data class Cross(val negative:GPoint,val positive:GPoint,val center:GPoint,val unit:Float,val fraction:Float)
    data class Sample(val source:GPoint, val weights:FloatArray,
        val torsoCross:Cross?,val sleeveCross:List<Cross?>,val torsoFade:Float)
    private val span=(spec.rightShoulder-spec.leftShoulder).length.coerceAtLeast(1f)
    private val shoulderMid=(spec.leftShoulder+spec.rightShoulder)*.5f
    private val down=spec.hem-shoulderMid
    private val across=spec.rightShoulder-spec.leftShoulder

    private fun cross(q:GPoint,polygon:List<GPoint>,origin:GPoint,xAxis:GPoint,yAxis:GPoint):Cross? {
        val determinant=xAxis.cross(yAxis)
        if(abs(determinant)<1f || polygon.size<3)return null
        fun coordinates(p:GPoint):GPoint {
            val d=p-origin
            return GPoint(d.cross(yAxis)/determinant,xAxis.cross(d)/determinant)
        }
        val local=coordinates(q)
        val hits=ArrayList<Float>()
        var a=coordinates(polygon.last())
        for(point in polygon) {
            val b=coordinates(point)
            if((a.y>local.y)!=(b.y>local.y))hits.add(a.x+(b.x-a.x)*(local.y-a.y)/(b.y-a.y))
            a=b
        }
        hits.sort()
        for(i in 0 until hits.size-1 step 2) {
            val l=hits[i];val r=hits[i+1]
            if(local.x<l-.0001f || local.x>r+.0001f || r-l<.0001f)continue
            val center=origin+yAxis*local.y+xAxis*((l+r)*.5f)
            return Cross(origin+yAxis*local.y+xAxis*l,origin+yAxis*local.y+xAxis*r,center,
                (2*local.x-l-r)/(r-l),local.y)
        }
        return null
    }

    fun sample(source:GPoint):Sample {
        val weights=FloatArray(spec.sleeves.size) { i ->
            val part=spec.sleeves[i]
            val seam=part.armpit-part.shoulder
            val determinant=seam.cross(part.hem-part.shoulder)
            if(abs(determinant)<1f) 0f else {
                val along=seam.cross(source-part.shoulder)/determinant
                val distance=distanceToPolygon(source,part.polygon)
                // Only a narrow exterior feather affects grid cells straddling the
                // silhouette. The infinite seam half-plane must never move the torso.
                val region=if(contains(source,part.polygon)) 1f else 1f-smoothUnit(distance/(span*.025f))
                smoothUnit(along)*region
            }
        }
        val total=weights.sum()
        if(total>1f) for(i in weights.indices) weights[i]/=total
        val torso=cross(source,spec.torsoPolygon.ifEmpty { spec.outer },shoulderMid,across,down)
        val sleeves=spec.sleeves.map { part ->
            val axis=part.hem-part.shoulder
            cross(source,part.polygon,part.shoulder,GPoint(-axis.y,axis.x),axis)
        }
        val fraction=torso?.fraction ?: 0f
        var fade=smoothUnit((fraction-.12f)/.18f)*(1f-smoothUnit((fraction-.72f)/.28f))
        for(hole in spec.holes)fade*=smoothUnit(distanceToPolygon(source,hole)/(span*.08f))
        for(part in spec.sleeves)fade*=smoothUnit(distanceToSegment(source,part.shoulder,part.armpit)/(span*.08f))
        return Sample(source,weights,torso,sleeves,fade)
    }

    companion object {
        fun distanceToSegment(q:GPoint,a:GPoint,b:GPoint):Float {
            val d=b-a
            val t=(((q-a).x*d.x+(q-a).y*d.y)/max(.0001f,d.x*d.x+d.y*d.y)).coerceIn(0f,1f)
            return (q-(a+d*t)).length
        }
        fun contains(q:GPoint,polygon:List<GPoint>):Boolean {
            if(polygon.size<3)return false
            if(distanceToPolygon(q,polygon)<.001f)return true
            var inside=false
            var a=polygon.last()
            for(b in polygon) {
                if((a.y>q.y)!=(b.y>q.y) && q.x<(b.x-a.x)*(q.y-a.y)/(b.y-a.y)+a.x)inside=!inside
                a=b
            }
            return inside
        }

        fun distanceToPolygon(q:GPoint,polygon:List<GPoint>):Float {
            var distance=Float.POSITIVE_INFINITY
            if(polygon.isEmpty())return distance
            var a=polygon.last()
            for(b in polygon) {
                distance=minOf(distance,distanceToSegment(q,a,b))
                a=b
            }
            return distance
        }
    }
}
