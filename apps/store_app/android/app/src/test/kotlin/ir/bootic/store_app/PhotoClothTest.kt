package ir.bootic.store_app
import org.junit.Assert.*
import org.junit.Test
class PhotoClothTest {
    private val sleeve=SleeveSpec("left",listOf(GPoint(100f,100f),GPoint(100f,300f),GPoint(0f,250f)),GPoint(100f,100f),GPoint(100f,300f),GPoint(0f,250f))
    private val spec=GarmentRenderSpec(1000f,1500f,sleeve.polygon,emptyList(),GPoint(100f,100f),GPoint(800f,150f),GPoint(450f,1200f),listOf(sleeve),true)
    private fun points()=MutableList(33){PosePoint(.5f,.5f,1f,1f)}.apply {
        this[12]=PosePoint(.3f,.2f,1f,1f);this[11]=PosePoint(.7f,.25f,1f,1f)
        this[14]=PosePoint(.1f,.15f,1f,1f);this[23]=PosePoint(.6f,.7f,1f,1f);this[24]=PosePoint(.4f,.7f,1f,1f)
    }
    @Test fun articulationIsContinuousAcrossArmhole() {
        val warp=GarmentWarp(spec,points(),480,640,false)
        val a=warp.surface(GPoint(99.99f,200f));val b=warp.surface(GPoint(100.01f,200f))
        assertTrue((a-b).length<.1f)
        assertTrue((warp.surface(sleeve.hem)-warp.torso(sleeve.hem)).length>5f)
    }
    @Test fun longSleeveFollowsWristPastElbow() {
        val long=sleeve.copy(hem=GPoint(0f,1300f),polygon=listOf(sleeve.shoulder,sleeve.armpit,GPoint(0f,1300f)))
        val p=points();p[14]=PosePoint(.3f,.4f,1f,1f);p[16]=PosePoint(.2f,.7f,1f,1f)
        val first=GarmentWarp(spec.copy(sleeves=listOf(long)),p.toList(),480,640,false).surface(long.hem)
        p[16]=PosePoint(.05f,.42f,1f,1f)
        val last=GarmentWarp(spec.copy(sleeves=listOf(long)),p,480,640,false).surface(long.hem)
        assertTrue((first-last).length>30f)
        assertTrue((last-GPoint(p[16].x*480,p[16].y*640)).length<2f)
    }
    @Test fun foregroundArmsRequireConfidentDepthAndIgnoreInvalidPoints() {
        val p=points();p[14]=p[14].copy(z=-.4f);p[16]=p[14].copy(x=.5f)
        assertEquals(1,PhotoOcclusion.forearms(p,480,640).size)
        p[14]=p[14].copy(visibility=.1f)
        assertTrue(PhotoOcclusion.forearms(p,480,640).isEmpty())
    }
}
