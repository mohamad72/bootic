package ir.bootic.store_app

import org.junit.Assert.*
import org.junit.Test

class PhotoSurfaceTest {
    private val left = SleeveSpec("left", listOf(GPoint(200f,100f),GPoint(330f,350f),GPoint(40f,350f),GPoint(40f,150f)), GPoint(200f,100f),GPoint(330f,350f),GPoint(40f,250f))
    private val right = SleeveSpec("right", left.polygon.map { GPoint(1000-it.x,it.y) },GPoint(800f,100f),GPoint(670f,350f),GPoint(960f,250f))
    private val spec = GarmentRenderSpec(1000f,1200f,listOf(GPoint(40f,100f),GPoint(960f,100f),GPoint(960f,1100f),GPoint(40f,1100f)),emptyList(),left.shoulder,right.shoulder,GPoint(500f,1100f),listOf(left,right),true)
    private fun pose() = MutableList(33) { PosePoint(.5f,.5f,1f,1f) }.apply {
        this[12]=PosePoint(.3f,.2f,1f,1f);this[11]=PosePoint(.7f,.2f,1f,1f)
        this[14]=PosePoint(.2f,.45f,1f,1f);this[13]=PosePoint(.8f,.45f,1f,1f)
        this[16]=PosePoint(.1f,.7f,1f,1f);this[15]=PosePoint(.9f,.7f,1f,1f)
        this[23]=PosePoint(.65f,.75f,1f,1f);this[24]=PosePoint(.35f,.75f,1f,1f)
    }
    private fun same(a:GPoint,b:GPoint) { assertEquals(a.x,b.x,.001f);assertEquals(a.y,b.y,.001f) }
    @Test fun armMotionNeverMovesTorsoOrOppositeSleeve() {
        val p=pose(); val before=GarmentWarp(spec,p.toList(),400,600,false)
        p[14]=p[14].copy(x=.02f,y=.12f)
        val after=GarmentWarp(spec,p,400,600,false)
        for(q in listOf(GPoint(500f,500f),GPoint(700f,950f),right.hem,spec.hem)) same(before.surface(q),after.surface(q))
        assertTrue((before.surface(left.hem)-after.surface(left.hem)).length>5f)
    }
    @Test fun anchorsAndSeamsRemainPinned() {
        val warp=GarmentWarp(spec,pose(),400,600,false)
        for(q in listOf(left.shoulder,left.armpit,right.shoulder,right.armpit,spec.hem)) same(warp.torso(q),warp.surface(q))
    }
    @Test fun zeroVolumeIsExactAndCurvaturePreservesContourAndHem() {
        val p=pose()
        val flat=GarmentWarp(spec,p,400,600,false,volumeStrength=0f)
        val curved=GarmentWarp(spec,p,400,600,false,volumeStrength=.2f)
        for(q in listOf(spec.leftShoulder,spec.rightShoulder,spec.hem,GPoint(40f,600f),GPoint(960f,600f),GPoint(350f,1100f))) same(flat.surface(q),curved.surface(q))
        val q=GPoint(700f,600f)
        same(flat.torso(q),flat.surface(q))
        val shift=(curved.surface(q)-flat.surface(q)).length
        assertTrue(shift>.1f && shift<6f)
    }
    @Test fun observedTorsoBoundaryAdjustsSideButLeavesCenterAndShouldersPinned() {
        val p=pose()
        val edges=BodyEdges(sections=listOf(BodySection(0,.5f,GPoint(200f,285f),GPoint(1f,0f),120f,120f)))
        val flat=GarmentWarp(spec,p,400,600,false,volumeStrength=0f)
        val fit=GarmentWarp(spec,p,400,600,false,edges,volumeStrength=0f)
        val edge=GPoint(960f,600f)
        assertTrue(fit.surface(edge).x<flat.surface(edge).x)
        same(flat.surface(GPoint(500f,600f)),fit.surface(GPoint(500f,600f)))
        same(flat.surface(spec.leftShoulder),fit.surface(spec.leftShoulder))
    }
    @Test fun meshDoesNotInvertAtRaisedSleevesAndReflection() {
        for(mirror in listOf(false,true))for(y in listOf(.08f,.2f,.45f)) {
            val p=pose();p[14]=p[14].copy(x=.02f,y=y)
            val mesh=PhotoMesh(spec,24,32)
            val warp=GarmentWarp(spec,p,400,600,mirror)
            val projected=mesh.project(warp)
            assertTrue(projected.all { it.isFinite() })
            for(triangle in mesh.triangles.asList().chunked(3)) {
                fun dest(i:Int)=GPoint(projected[2*i],projected[2*i+1])
                val a=triangle[0];val b=triangle[1];val c=triangle[2]
                val original=(warp.torso(mesh.samples[b].source)-warp.torso(mesh.samples[a].source)).cross(warp.torso(mesh.samples[c].source)-warp.torso(mesh.samples[a].source))
                val actual=(dest(b)-dest(a)).cross(dest(c)-dest(a))
                assertTrue("mesh triangle inverted",original*actual>0f)
            }
        }
    }
    @Test fun sharedProjectionInvalidatesOnNewFrameAndMirror() {
        val p=pose();val mesh=PhotoMesh(spec,12,16)
        val first=mesh.project(GarmentWarp(spec,p,400,600,false),p,false).copyOf()
        val moved=p.map { it.copy(x=it.x+.05f) }
        val next=mesh.project(GarmentWarp(spec,moved,400,600,false),moved,false).copyOf()
        assertEquals(20f,next[0]-first[0],.001f)
        val mirror=mesh.project(GarmentWarp(spec,moved,400,600,true),moved,true)
        assertTrue((next[0]-mirror[0]).let { kotlin.math.abs(it)>20f })
    }
}
