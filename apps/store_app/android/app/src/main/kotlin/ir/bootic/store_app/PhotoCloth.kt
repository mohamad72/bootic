package ir.bootic.store_app

import kotlin.math.exp
import kotlin.math.max

/** Damped, motion-driven hem lag in pose pixels. No autonomous waving. */
internal class ClothMotion {
    private var previous: GPoint? = null
    private var time = 0.0
    private var lag = GPoint(0f,0f)
    fun reset() { previous=null;lag=GPoint(0f,0f);time=0.0 }
    fun update(center: GPoint, shoulderWidth: Float, now: Double): GPoint {
        val before=previous;val dt=now-time
        previous=center;time=now
        if(before==null || dt<=0 || dt>.35 || (center-before).length>shoulderWidth*.75f) {
            lag=GPoint(0f,0f);return lag
        }
        lag=(lag-(center-before)*.3f)*exp(-dt*12).toFloat()
        val limit=max(0f,shoulderWidth*.025f)
        if(lag.length>limit && lag.length>0)lag=lag*(limit/lag.length)
        if(lag.length<.005f)lag=GPoint(0f,0f)
        return lag
    }
}
internal data class ArmOccluder(val a:GPoint,val b:GPoint,val radius:Float,val shoulderIndex:Int)
internal object PhotoOcclusion {
    /** Relative landmark depth is a conservative proxy, not a pixel depth map.
     * Require BOTH endpoints in front to avoid erasing cloth on an uncertain arm. */
    fun forearms(points:List<PosePoint>,width:Int,height:Int):List<ArmOccluder> {
        if(points.size<25 || width<=0 || height<=0)return emptyList()
        fun reliable(i:Int)=points[i].finite && points[i].visibility>=.6f && points[i].presence>=.6f
        if(!reliable(11)||!reliable(12))return emptyList()
        fun pixel(i:Int)=GPoint(points[i].x*width,points[i].y*height)
        val shoulder=(pixel(11)-pixel(12)).length
        val chest=minOf(points[11].z,points[12].z)-shoulder/width*.12f
        return listOf(13,14).filter { i -> reliable(i)&&reliable(i+2)&&points[i].z<chest&&points[i+2].z<chest }
            .map { ArmOccluder(pixel(it),pixel(it+2),shoulder*.045f,it-2) }
    }
}
