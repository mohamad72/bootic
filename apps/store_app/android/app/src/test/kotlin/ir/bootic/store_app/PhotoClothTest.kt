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
    @Test fun raisedArmLiftsUnderarmClothWithoutMovingShoulder() {
        val down=points();down[14]=PosePoint(.2f,.55f,1f,1f)
        val up=points();up[14]=PosePoint(.1f,.15f,1f,1f)
        val a=GarmentWarp(spec,down,480,640,false)
        val b=GarmentWarp(spec,up,480,640,false)
        assertTrue(b.surface(sleeve.armpit).y<a.surface(sleeve.armpit).y)
        assertEquals(b.torso(spec.leftShoulder),b.surface(spec.leftShoulder))
    }
    @Test fun collarAndShouldersStayAttachedWithMovingHem() {
        val warp=GarmentWarp(spec,points(),480,640,false)
        assertEquals(warp.torso(spec.leftShoulder),warp.surface(spec.leftShoulder,GPoint(10f,5f)))
        assertEquals(warp.torso(spec.rightShoulder),warp.surface(spec.rightShoulder,GPoint(10f,5f)))
        val hem=warp.surface(spec.hem,GPoint(10f,5f))-warp.surface(spec.hem)
        assertEquals(10f,hem.x,.001f)
    }
    @Test fun motionResetsOnTrackingGapAndSettlesAtRest() {
        val motion=ClothMotion()
        motion.update(GPoint(0f,0f),200f,1.0)
        val lag=motion.update(GPoint(20f,0f),200f,1.033)
        assertTrue(lag.x<0f);assertTrue(lag.length<=6.01f)
        var end=lag
        repeat(200){end=motion.update(GPoint(20f,0f),200f,1.066+it*.016)}
        assertTrue(end.length<.01f)
        assertEquals(GPoint(0f,0f),motion.update(GPoint(500f,0f),200f,10.0))
    }
    @Test fun longSleeveFollowsWristPastElbow() {
        val long=sleeve.copy(hem=GPoint(0f,1300f))
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
