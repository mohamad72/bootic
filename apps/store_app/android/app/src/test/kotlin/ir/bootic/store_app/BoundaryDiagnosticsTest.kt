package ir.bootic.store_app

import org.junit.Assert.*
import org.junit.Test

class BoundaryDiagnosticsTest {
    private fun pose():PoseObservation {
        val p=MutableList(33) { PosePoint(.5f,.5f,0f,0f) }
        p[11]=PosePoint(.3f,.3f,1f,1f);p[12]=PosePoint(.7f,.3f,1f,1f)
        p[23]=PosePoint(.35f,.75f,1f,1f);p[24]=PosePoint(.65f,.75f,1f,1f)
        return PoseGeometry.evaluate(p,400,600)
    }
    @Test fun anatomicalDivisionsExistWithoutAGarmentButAreNeverClaimedAsDetectedMaskSeams() {
        val lines=BoundaryDiagnostics.body(pose())
        assertEquals(setOf("arm_11","arm_12","neck","hips"),lines.map { it.kind }.toSet())
        assertTrue(lines.all { it.evidence=="estimated"&&it.points.size>=2 })
        val neck=lines.single { it.kind=="neck" }.points
        assertEquals(158.4f,neck[0].y,.01f)
        val hips=lines.single { it.kind=="hips" }.points
        assertEquals(GPoint(140f,450f),hips[0]);assertEquals(GPoint(260f,450f),hips[1])
    }
    @Test fun observedSideTracesDisappearWhenMaskOrPoseIsLost() {
        val rows=listOf(.25f,.5f,.75f).map { BodySection(0,it,GPoint(200f,180f+270f*it),GPoint(1f,0f),100f,100f) }
        val p=pose().copy(bodyEdges=BodyEdges(sections=rows))
        val sides=BoundaryDiagnostics.body(p).filter { it.evidence=="mask" }
        assertEquals(2,sides.size)
        assertEquals(100f,sides.first().points.first().x,.01f)
        assertTrue(BoundaryDiagnostics.body(p.copy(bodyEdges=null)).none { it.evidence=="mask" })
        assertTrue(BoundaryDiagnostics.body(p.copy(box=null)).isEmpty())
    }
    @Test fun reflectionAndOcclusionDoNotSwapOrInventAnArmBoundary() {
        val p=pose();val original=BoundaryDiagnostics.body(p).single { it.kind=="arm_11" }.points
        val reflected=p.copy(points=p.points.map { it.copy(x=1f-it.x) })
        val next=BoundaryDiagnostics.body(reflected).single { it.kind=="arm_11" }.points
        for(i in original.indices) { assertEquals(400-original[i].x,next[i].x,.01f);assertEquals(original[i].y,next[i].y,.01f) }
        val hidden=p.copy(points=p.points.mapIndexed { i,q -> if(i==11)q.copy(visibility=.2f) else q })
        assertTrue(BoundaryDiagnostics.body(hidden).none { it.kind=="arm_11" })
    }
    @Test fun rollGuidesFollowFinalMeshIncludingFallbackAndNeverAddALowerHemRoll() {
        val source=GarmentRenderSpec(1000f,1200f,
            listOf(GPoint(100f,100f),GPoint(900f,100f),GPoint(900f,1100f),GPoint(100f,1100f)),emptyList(),
            GPoint(200f,100f),GPoint(800f,100f),GPoint(500f,1100f),emptyList(),true)
        val p=pose();val mesh=PhotoMesh(source,12,16);val warp=GarmentWarp(source,p.points,400,600,false)
        val projected=mesh.project(warp)
        val lines=BoundaryDiagnostics.garment(source,mesh,warp)
        assertTrue(lines.any { it.kind=="torso_roll" });assertTrue(lines.any { it.kind=="shoulder_roll" })
        assertTrue(lines.none { it.kind=="hem_roll" })
        val guide=mesh.surface.rollGuides.first()
        val line=lines.first { it.kind==guide.kind }
        val expected=mesh.projectedPoint(guide.points.first(),projected)
        assertEquals(expected.x,line.points.first().x,.001f);assertEquals(expected.y,line.points.first().y,.001f)
        // Literal affine grid checks both triangles used by the renderer.
        val flat=floatArrayOf(10f,20f,30f,20f,10f,60f,30f,60f)
        val simple=PhotoMesh(source,1,1)
        assertEquals(GPoint(15f,30f),simple.projectedPoint(GPoint(250f,300f),flat))
        assertEquals(GPoint(25f,50f),simple.projectedPoint(GPoint(750f,900f),flat))
    }
}
