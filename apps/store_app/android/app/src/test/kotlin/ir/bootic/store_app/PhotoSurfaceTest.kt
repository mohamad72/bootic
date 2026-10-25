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
    @Test fun rollCompressesOnlyOuterBandsAndPreservesCenterAnchorsAndHem() {
        val p=pose()
        val flat=GarmentWarp(spec,p,400,600,false,volumeStrength=0f)
        val curved=GarmentWarp(spec,p,400,600,false,volumeStrength=.2f)
        for(q in listOf(spec.leftShoulder,spec.rightShoulder,spec.hem,GPoint(350f,1100f),GPoint(900f,1000f))) same(flat.surface(q),curved.surface(q))
        val q=GPoint(700f,600f)
        same(flat.torso(q),flat.surface(q))
        same(flat.surface(q),curved.surface(q))
        val edge=GPoint(960f,600f)
        val shift=(curved.surface(edge)-flat.surface(edge)).length
        assertTrue(shift>.1f && shift<6f)
        assertTrue(curved.surface(edge).x<flat.surface(edge).x)
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

    @Test fun jaggedSourceSilhouetteCannotPrintKinksThroughStraightInteriorStripes() {
        val source=spec.copy(sleeves=emptyList(),outer=listOf(
            GPoint(100f,100f),GPoint(900f,100f),GPoint(900f,500f),GPoint(700f,510f),
            GPoint(900f,520f),GPoint(900f,1100f),GPoint(100f,1100f)),torsoPolygon=emptyList())
        val p=pose()
        val fit=BodyEdges(sections=listOf(BodySection(0,.5f,GPoint(200f,285f),GPoint(1f,0f),120f,120f)))
        val warp=GarmentWarp(source,p,400,600,false,fit)
        val a=warp.surface(GPoint(650f,495f));val b=warp.surface(GPoint(650f,510f));val c=warp.surface(GPoint(650f,525f))
        assertTrue("a tiny contour notch must not crease the shirt interior",kotlin.math.abs(b.x-(a.x+c.x)*.5f)<.5f)
    }

    @Test fun sleeveArticulationIsBlendedOnceAcrossItsSourceSeam() {
        val surface=PhotoSurface(spec)
        val q=(left.shoulder+left.hem)*.5f
        val warp=GarmentWarp(spec,pose(),400,600,false,volumeStrength=0f)
        same(warp.sleeve(q,left),warp.surface(surface.sample(q)))
    }

    @Test fun shoulderSurfaceCorrectionDoesNotLiftTheWholeNeckOrChest() {
        val p=pose()
        val flat=GarmentWarp(spec,p,400,600,false)
        val lifted=GarmentWarp(spec,p,400,600,false,BodyEdges(shoulder11=GPoint(280f,90f),shoulder12=GPoint(120f,90f)))
        for(q in listOf(GPoint(500f,100f),GPoint(500f,600f),spec.hem))same(flat.torso(q),lifted.torso(q))
        same(GPoint(120f,90f),lifted.torso(spec.leftShoulder))
    }

    @Test fun sleeveTopologyFallbackDoesNotUndoTorsoEdgeFitting() {
        val p=pose();val edges=BodyEdges(sections=listOf(BodySection(0,.5f,GPoint(200f,285f),GPoint(1f,0f),110f,110f)))
        val mesh=PhotoMesh(spec,24,32)
        val index=mesh.samples.indices.minBy { (mesh.samples[it].source-GPoint(800f,700f)).length }
        val before=mesh.project(GarmentWarp(spec,p.toList(),400,600,false,edges)).copyOf()
        p[14]=p[14].copy(x=.02f,y=.08f)
        val after=mesh.project(GarmentWarp(spec,p,400,600,false,edges))
        assertEquals("arm fallback must preserve fitted torso",before[index*2],after[index*2],.01f)
        assertEquals(before[index*2+1],after[index*2+1],.01f)
    }

    @Test fun finalMeshCannotUndoNeckProtectionWhenHeadBendsBelowShoulders() {
        val source=GarmentRenderSpec(1000f,1200f,
            listOf(GPoint(100f,0f),GPoint(900f,0f),GPoint(900f,1100f),GPoint(100f,1100f)),
            listOf(listOf(GPoint(400f,0f),GPoint(600f,0f),GPoint(600f,200f),GPoint(400f,200f))),
            GPoint(100f,400f),GPoint(900f,400f),GPoint(500f,1100f),emptyList(),true)
        val p=pose().apply {
            this[11]=PosePoint(.3f,.3f,1f,1f);this[12]=PosePoint(.7f,.3f,1f,1f)
            this[9]=PosePoint(.47f,.4f,1f,1f);this[10]=PosePoint(.53f,.4f,1f,1f)
        }
        assertNotNull(PoseGeometry.evaluate(p,400,600).box)
        for(mirror in listOf(false,true)) {
            val warp=GarmentWarp(source,p,400,600,mirror,volumeStrength=0f)
            val mesh=PhotoMesh(source)
            val final=mesh.projectedPoint(GPoint(500f,0f),mesh.project(warp))
            assertTrue("final mesh must keep the neckline below mouth plus margin",final.y>=259f)
        }
    }
}
