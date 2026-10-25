package ir.bootic.store_app

import kotlin.math.abs
import kotlin.math.max

internal fun smoothUnit(value: Float): Float {
    val t=value.coerceIn(0f,1f)
    return t*t*(3f-2f*t)
}

internal data class SurfaceGuide(val kind:String,val points:List<GPoint>)

/** Shared cached grid for phone/projector. If articulation would turn a visible
 * triangle inside out, reduce the deformation toward the fitted affine pose.
 * This conservative fallback trades extreme arm rotation for a valid surface. */
internal class PhotoMesh(private val spec:GarmentRenderSpec,val columns:Int=48,val rows:Int=64) {
    val surface=PhotoSurface(spec)
    val samples:List<PhotoSurface.Sample>
    val triangles:IntArray
    val boundIndices:IntArray
    private val base:FloatArray
    private val reference:FloatArray
    private val result:FloatArray
    private var lastFrameKey:Any?=null
    private var lastMirror=false
    var deformationScale=1f
        private set
    var bodyFitScale=1f
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
        base=FloatArray(samples.size*2);reference=FloatArray(samples.size*2);result=FloatArray(samples.size*2)
    }
    fun project(warp:GarmentWarp,frameKey:Any?=null,mirror:Boolean=false):FloatArray {
        if(frameKey!=null && frameKey===lastFrameKey && mirror==lastMirror)return result
        for((i,sample) in samples.withIndex()) {
            val original=warp.referenceTorso(sample.source)
            reference[i*2]=original.x;reference[i*2+1]=original.y
            val a=warp.bodySurface(sample);val b=warp.surface(sample,a)
            base[i*2]=a.x;base[i*2+1]=a.y;result[i*2]=b.x;result[i*2+1]=b.y
        }
        fun safe(from:FloatArray,to:FloatArray,amount:Float):Boolean {
            fun x(i:Int)=from[i*2]+(to[i*2]-from[i*2])*amount
            fun y(i:Int)=from[i*2+1]+(to[i*2+1]-from[i*2+1])*amount
            for(i in triangles.indices step 3) {
                val a=triangles[i];val b=triangles[i+1];val c=triangles[i+2]
                val original=(reference[b*2]-reference[a*2])*(reference[c*2+1]-reference[a*2+1])-(reference[b*2+1]-reference[a*2+1])*(reference[c*2]-reference[a*2])
                val actual=(x(b)-x(a))*(y(c)-y(a))-(y(b)-y(a))*(x(c)-x(a))
                if(!actual.isFinite() || actual*original<=original*original*.025f)return false
            }
            return true
        }
        // Preserve torso fitting when an extreme sleeve pose needs attenuation.
        // Validate the body field separately before using it as the safe baseline.
        var bodyAmount=1f
        while(bodyAmount>.015625f&&!safe(reference,base,bodyAmount))bodyAmount*=.5f
        if(!safe(reference,base,bodyAmount))bodyAmount=0f
        bodyFitScale=bodyAmount
        if(bodyAmount<1f)for(i in base.indices)base[i]=reference[i]+(base[i]-reference[i])*bodyAmount
        var amount=1f
        while(amount>.015625f && !safe(base,result,amount))amount*=.5f
        if(!safe(base,result,amount))amount=0f
        deformationScale=amount
        if(amount<1f)for(i in result.indices)result[i]=if(amount==0f)base[i] else base[i]+(result[i]-base[i])*amount
        lastFrameKey=frameKey;lastMirror=mirror
        return result
    }

    /** Interpolate the final triangles, including topology fallback, for diagnostics. */
    fun projectedPoint(source:GPoint,projected:FloatArray):GPoint {
        val x=(source.x/spec.width*columns).coerceIn(0f,columns.toFloat())
        val y=(source.y/spec.height*rows).coerceIn(0f,rows.toFloat())
        val ix=minOf(x.toInt(),columns-1);val iy=minOf(y.toInt(),rows-1)
        val u=x-ix;val v=y-iy;val a=iy*(columns+1)+ix;val b=a+1;val c=a+columns+1;val d=c+1
        fun p(i:Int)=GPoint(projected[i*2],projected[i*2+1])
        return if(u+v<=1f)p(a)*(1f-u-v)+p(b)*u+p(c)*v
            else p(d)*(u+v-1f)+p(c)*(1f-u)+p(b)*(1f-v)
    }
}

/** Source-space geometry is prepared on garment selection, never from live pixels. */
internal class PhotoSurface(private val spec: GarmentRenderSpec) {
    data class Cross(val negative:GPoint,val positive:GPoint,val center:GPoint,val unit:Float,val fraction:Float)
    data class Sample(val source:GPoint, val weights:FloatArray,
        val torsoLocal:GPoint,val sleeveLocal:List<GPoint>,
        val torsoRoll:GPoint,val sleeveRoll:List<GPoint>)
    private val span=(spec.rightShoulder-spec.leftShoulder).length.coerceAtLeast(1f)
    private val shoulderMid=(spec.leftShoulder+spec.rightShoulder)*.5f
    private val down=spec.hem-shoulderMid
    private val across=spec.rightShoulder-spec.leftShoulder

    private fun local(q:GPoint,origin:GPoint,x:GPoint,y:GPoint):GPoint {
        val d=q-origin;val determinant=x.cross(y)
        return if(abs(determinant)<1f)GPoint(0f,0f) else GPoint(d.cross(y)/determinant,x.cross(d)/determinant)
    }
    fun torsoLocal(q:GPoint)=local(q,shoulderMid,across,down)
    fun sleeveLocal(q:GPoint,part:SleeveSpec):GPoint {
        val axis=part.hem-part.shoulder
        return local(q,part.shoulder,GPoint(-axis.y,axis.x),axis)
    }
    fun torsoCross(fraction:Float)=cross(shoulderMid+down*fraction,spec.torsoPolygon.ifEmpty { spec.outer },shoulderMid,across,down)
    fun sleeveCross(part:SleeveSpec,fraction:Float):Cross? {
        val axis=part.hem-part.shoulder
        return cross(part.shoulder+axis*fraction,part.polygon,part.shoulder,GPoint(-axis.y,axis.x),axis)
    }
    // A fixed frame avoids transferring every small contour notch into the print.
    private val torsoHalfWidth=listOf(.3f,.5f,.7f).mapNotNull { t -> torsoCross(t)?.let {
        max(abs(torsoLocal(it.negative).x),abs(torsoLocal(it.positive).x))
    } }.sorted().let { if(it.isEmpty()).5f else it[it.size/2].coerceAtLeast(.15f) }
    private val sleeveHalfWidths=spec.sleeves.map { part ->
        listOf(.35f,.65f,.85f).mapNotNull { t -> sleeveCross(part,t)?.let {
            max(abs(sleeveLocal(it.negative,part).x),abs(sleeveLocal(it.positive,part).x))
        } }.sorted().let { values -> if(values.isEmpty()).4f else values[values.size/2].coerceAtLeast(.05f) }
    }

    val rollGuides:List<SurfaceGuide> by lazy {
        val guides=ArrayList<SurfaceGuide>()
        fun add(kind:String,points:List<GPoint>) {
            var run=ArrayList<GPoint>()
            fun flush() { if(run.size>=2)guides.add(SurfaceGuide(kind,run));run=ArrayList() }
            for(q in points) {
                if(contains(q,spec.outer)&&spec.holes.none { contains(q,it) })run.add(q) else flush()
            }
            flush()
        }
        for(sign in listOf(-1f,1f)) {
            add("torso_roll",(0..20).map { shoulderMid+across*(sign*torsoHalfWidth*.65f)+down*(.18f+it*.032f) })
            add("shoulder_roll",(0..12).map { shoulderMid+across*(sign*torsoHalfWidth*(.28f+it*.055f))+down*.18f })
        }
        for((i,part) in spec.sleeves.withIndex())for(sign in listOf(-1f,1f)) {
            val axis=part.hem-part.shoulder
            add("sleeve_roll",(0..20).map { part.shoulder+axis*(.2f+it*.038f)+GPoint(-axis.y,axis.x)*(sign*sleeveHalfWidths[i]*.65f) })
        }
        guides
    }

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
            val distance=distanceToPolygon(source,part.polygon)
            // Articulation itself blends across the seam. Applying that weight
            // here again used to square it, leaving sleeves stuck halfway up.
            if(contains(source,part.polygon))1f else 1f-smoothUnit(distance/(span*.025f))
        }
        val total=weights.sum()
        if(total>1f) for(i in weights.indices) weights[i]/=total
        val torso=torsoLocal(source)
        val sleeves=spec.sleeves.map { sleeveLocal(source,it) }
        var pin=1f
        for(hole in spec.holes)pin*=smoothUnit(distanceToPolygon(source,hole)/(span*.06f))
        for(anchor in listOf(spec.leftShoulder,spec.rightShoulder,spec.hem))pin*=smoothUnit((source-anchor).length/(span*.06f))
        for(part in spec.sleeves)pin*=smoothUnit(distanceToSegment(source,part.shoulder,part.armpit)/(span*.06f))
        val side=smoothUnit((abs(torso.x)/torsoHalfWidth-.65f)/.35f)*smoothUnit(torso.y/.18f)*(1f-smoothUnit((torso.y-.72f)/.18f))
        val top=(1f-smoothUnit((torso.y+.08f)/.26f))*smoothUnit((abs(torso.x)/torsoHalfWidth-.25f)/.4f)
        val torsoRoll=(across*(-torso.x*.2f*side)+down*(.02f*top))*pin
        val sleeveRoll=spec.sleeves.mapIndexed { i,part ->
            val axis=part.hem-part.shoulder;val q=sleeves[i]
            val roll=smoothUnit((abs(q.x)/sleeveHalfWidths[i]-.65f)/.35f)*smoothUnit(q.y/.25f)
            GPoint(-axis.y,axis.x)*(-q.x*.2f*roll*pin)
        }
        return Sample(source,weights,torso,sleeves,torsoRoll,sleeveRoll)
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
