package ir.bootic.store_app

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
