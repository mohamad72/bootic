package ir.bootic.store_app

import kotlin.math.*

internal data class V3(val x: Float, val y: Float, val z: Float) {
    operator fun plus(b: V3)=V3(x+b.x,y+b.y,z+b.z)
    operator fun minus(b: V3)=V3(x-b.x,y-b.y,z-b.z)
    operator fun times(s: Float)=V3(x*s,y*s,z*s)
    fun dot(b: V3)=x*b.x+y*b.y+z*b.z
    fun cross(b: V3)=V3(y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x)
    val length get()=sqrt(dot(this))
    fun unit()=this*(1f/max(length,0.00001f))
}
internal data class ModelVertex(val position: V3, val u: Float, val v: Float, val part: Int=0)
internal data class ModelFace(val a: Int,val b: Int,val c: Int,val collar: Boolean=false)
internal data class ModelFrame(val positions: List<V3>, val faces: List<ModelFace>, val width: Float, val torsoLength: Float, val legLength: Float, val armLengths: List<Float>)

/** Strict native validation also protects method-channel callers. */
internal data class GarmentModelSpec(
    val kind: String, val length: Float, val hemWidth: Float, val ease: Float,
    val sleeveLength: Float, val neckWidth: Float, val neckDepth: Float, val neckline: String,
    val mode: String, val baseColor: Int, val accentColor: Int, val pattern: String,
    val patternScale: Float, val orientation: String, val roughness: Float,
    val patternDuty: Float = .5f, val weave: String = "plain",
) {
    companion object {
        fun fromMap(map: Map<*,*>): GarmentModelSpec {
            require(map["schema_version"]=="bootic.garment-model/1")
            val shape=map["shape"] as Map<*,*>; val mat=map["material"] as Map<*,*>
            fun value(m: Map<*,*>, k: String, low: Float, high: Float): Float =
                (m[k] as Number).toFloat().also { require(it.isFinite() && it in low..high) }
            fun choice(m: Map<*,*>, k: String, vararg options: String)=
                (m[k] as String).also { require(it in options) }
            fun color(k: String): Int {
                val text=mat[k] as String
                require(Regex("#[0-9a-fA-F]{6}").matches(text))
                return (0xff000000L or text.drop(1).toLong(16)).toInt()
            }
            return GarmentModelSpec(choice(map,"kind","top","coat","dress","skirt","trousers"),
                value(shape,"length",.6f,2.2f),value(shape,"hem_width",.65f,1.8f),value(shape,"ease",0f,.25f),
                value(shape,"sleeve_length",0f,1f),value(shape,"neck_width",.12f,.32f),value(shape,"neck_depth",.02f,.3f),
                choice(shape,"neckline","round","v"),choice(mat,"mode","procedural","source"),color("base_color"),color("accent_color"),
                choice(mat,"pattern","solid","stripes","checks"),value(mat,"pattern_scale",.005f,.15f),
                choice(mat,"orientation","horizontal","vertical"),value(mat,"roughness",.3f,1f),
                value(mat,"pattern_duty",.05f,.95f),choice(mat,"weave","plain","knit","denim"))
        }
    }
}

/** Cached, closed-sided 3D surface. Only body bindings change per observation.
 * Uses weak perspective in pose-pixel space, so phone and projector share geometry.
 * This is a parametric visual preview, not a physical cloth simulation. */
internal class GarmentModel(val spec: GarmentModelSpec) {
    val vertices=mutableListOf<ModelVertex>()
    val faces=mutableListOf<ModelFace>()
    private val lower=spec.kind=="skirt" || spec.kind=="trousers"
    init {
        if (spec.kind=="trousers") {
            tube(3,16,10) { t,a ->
                val r=.27f*(1f-.35f*t)
                ModelVertex(V3(cos(a)*r,t,sin(a)*r),a/(2*PI.toFloat()),t,3)
            }
            tube(4,16,10) { t,a ->
                val r=.27f*(1f-.35f*t)
                ModelVertex(V3(cos(a)*r,t,sin(a)*r),a/(2*PI.toFloat()),t,4)
            }
        } else {
            tube(0,32,14) { t,a ->
                val c=cos(a); val si=sin(a)
                val radius: Float; val depth: Float; val y: Float
                if (lower) {
                    radius=.5f*(1f+(spec.hemWidth-1f)*t)*(1f+spec.ease)
                    depth=radius*.65f; y=t
                } else if (t<=1f/14) {
                    val blend=t*14
                    radius=spec.neckWidth+blend*.012f
                    depth=.13f+blend*.008f
                    val dip=if(spec.neckline=="v") max(c,0f).pow(4) else max(c,0f)
                    y=spec.neckDepth*dip-blend*.005f
                } else if(t<=2f/14) {
                    val blend=(t*14-1)
                    radius=spec.neckWidth+.012f+(.5f*(1+spec.ease)-spec.neckWidth-.012f)*blend
                    depth=.138f+(.23f-.138f)*blend
                    val dip=if(spec.neckline=="v") max(c,0f).pow(4) else max(c,0f)
                    y=(spec.neckDepth-.005f)*(1-blend)*dip+(spec.neckDepth+.03f)*blend*dip
                } else {
                    val v=(t*14-2)/12
                    radius=.5f*(1f+(spec.hemWidth-1f)*v)*(1f+spec.ease)
                    depth=radius*.46f
                    y=v*spec.length+(1-v)*(spec.neckDepth+.03f)*max(c,0f)
                }
                ModelVertex(V3(si*radius,y,-c*depth),si*.5f+.5f,y/max(spec.length,.1f),0)
            }
            if(!lower && spec.sleeveLength>.015f) for(part in 1..2) {
                tube(part,16,8) { t,a ->
                    val radius=.17f*(1f-.35f*t)*(1+spec.ease)
                    ModelVertex(V3(cos(a)*radius,t,sin(a)*radius),a/(2*PI.toFloat()),t*spec.sleeveLength,part)
                }
            }
        }
    }
    private fun tube(part:Int, columns:Int, rows:Int, vertex:(Float,Float)->ModelVertex) {
        val start=vertices.size
        for(r in 0..rows) for(c in 0..columns) vertices+=vertex(r.toFloat()/rows,c*2*PI.toFloat()/columns)
        for(r in 0 until rows) for(c in 0 until columns) {
            val a=start+r*(columns+1)+c; val b=a+columns+1
            val collar=part==0 && !lower && r==0
            faces+=ModelFace(a,b,a+1,collar);faces+=ModelFace(a+1,b,b+1,collar)
        }
    }
    private var cachedPose: PoseObservation? = null
    private var cachedMirror = false
    private var cachedFrame: ModelFrame? = null
    fun frame(pose: PoseObservation, mirror: Boolean): ModelFrame? {
        if(cachedPose === pose && cachedMirror==mirror)return cachedFrame
        val result=deform(pose,mirror)
        cachedPose=pose;cachedMirror=mirror;cachedFrame=result
        return result
    }
    private fun deform(pose: PoseObservation, mirror: Boolean): ModelFrame? {
        if(pose.box==null || pose.points.size<29) return null
        fun p(i:Int):V3 { val v=pose.points[i];return V3(v.x*pose.imageWidth,v.y*pose.imageHeight,v.z*pose.imageWidth) }
        fun reliable(i:Int)=pose.points[i].finite && pose.points[i].presence>=.5f && pose.points[i].visibility>=.3f
        // The detector may relabel a mirrored input. Screen ordering stabilizes
        // the front template on both cameras; depth supplies side-view volume.
        // Verified 360-degree reconstruction needs an observed back asset.
        val left=if(pose.points[11].x<=pose.points[12].x)11 else 12
        val right=if(left==11)12 else 11
        fun shoulder(i:Int):V3 { val raw=p(i);val edge=pose.bodyEdges?.shoulder(i);return if(edge==null)raw else V3(edge.x,edge.y,raw.z) }
        val l=shoulder(left);val r=shoulder(right)
        val shoulders=(l+r)*.5f;val hips=(p(23)+p(24))*.5f
        val ex=(r-l).unit();val torso=(hips-shoulders)
        val ey=(torso-ex*torso.dot(ex)).unit();val ez=ex.cross(ey).unit()
        // Reject nearly degenerate depth rather than producing a giant garment.
        val w=(r-l).length; val length=torso.length
        if(w<2 || length<2 || ex.cross(ey).length<.5f) return null
        val hipWidth=(p(23)-p(24)).length.coerceIn(w*.45f,w*1.2f)
        val lowerLength=((p(27)+p(28))*.5f-hips).length
        if(lower && (!reliable(27)||!reliable(28))) return null
        val projected=vertices.map { v ->
            val q=v.position
            when(v.part) {
                0 -> {
                    val origin=if(lower)hips else shoulders
                    val width=if(lower)hipWidth else w
                    val len=if(lower)lowerLength*spec.length else length
                    origin+ex*(q.x*width)+ey*(q.y*len)+ez*(q.z*width)
                }
                1,2 -> {
                    val i=if(v.part==1)left else right
                    val a=shoulder(i); val e=if(reliable(i+2))p(i+2) else a+ey*(length*.55f)
                    val wrist=if(reliable(i+4))p(i+4) else e+(e-a)
                    val upper=(e-a).length;val fore=(wrist-e).length
                    val distance=q.y*spec.sleeveLength*(upper+fore)+w*.08f
                    val center:V3;val axis:V3
                    if(distance<=upper) {axis=(e-a).unit();center=a+axis*distance}
                    else {axis=(wrist-e).unit();center=e+axis*(distance-upper)}
                    var tangent=axis.cross(ez).unit()
                    if(tangent.length<.5f)tangent=ex
                    val depth=tangent.cross(axis).unit()
                    center+tangent*(q.x*w)+depth*(q.z*w)
                }
                else -> {
                    val i=if(v.part==3)23 else 24
                    val knee=p(i+2);val ankle=p(i+4);val origin=p(i)
                    val t=(q.y*spec.length).coerceAtMost(1.1f)
                    val center=if(t<.5f)origin+(knee-origin)*(t*2) else knee+(ankle-knee)*((t-.5f)*2)
                    center+ex*(q.x*hipWidth)+ez*(q.z*hipWidth)
                }
            }
        }
        return ModelFrame(projected,faces.sortedByDescending { (projected[it.a].z+projected[it.b].z+projected[it.c].z)/3 },w,length,lowerLength,listOf((p(left+2)-p(left)).length+(p(left+4)-p(left+2)).length,(p(right+2)-p(right)).length+(p(right+4)-p(right+2)).length))
    }
}
