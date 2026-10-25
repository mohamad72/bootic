package ir.bootic.store_app

import org.junit.Assert.*
import org.junit.Test

class BodyEdgeFitTest {
    private fun pose(width: Int = 400, height: Int = 600): PoseObservation {
        // Unspecified arms are unknown, not fictitious visible joints at chest centre.
        val p = MutableList(33) { PosePoint(.5f, .5f, 0f, 0f) }
        p[11] = PosePoint(.3f, .3f, 1f, 1f); p[12] = PosePoint(.7f, .3f, 1f, 1f)
        p[23] = PosePoint(.35f, .75f, 1f, 1f); p[24] = PosePoint(.65f, .75f, 1f, 1f)
        return PoseGeometry.evaluate(p, width, height)
    }
    private fun mask(value: (Float, Float) -> Float) = BodyMask(200, 300) { x, y -> value((x+.5f)/200, (y+.5f)/300) }
    private fun silhouette() = mask { x,y -> if (x in .2f.. .8f && y in .24f.. .9f) 1f else 0f }
    @Test fun torsoCrossSectionsFindBothSidesAndRejectFlatMasks() {
        val fit=BodyEdgeFit.refine(pose(),silhouette())
        val rows=fit.sections.filter { it.part==0 }
        assertEquals(3,rows.size)
        for(row in rows) {
            assertEquals(120f,row.negative!!,4f)
            assertEquals(120f,row.positive!!,4f)
        }
        for(value in listOf(0f,.5f,1f,Float.NaN)) assertTrue(BodyEdgeFit.refine(pose(),mask { _,_->value }).sections.isEmpty())
    }
    @Test fun armCrossSectionsStayLocalAndSkipHiddenArms() {
        val p=pose();val points=p.points.toMutableList()
        points[11]=points[11].copy(x=.25f);points[13]=PosePoint(.1f,.3f,1f,1f)
        val m=mask { x,y -> if(x in .05f.. .3f && y in .26f.. .34f || x in .3f.. .8f && y in .24f.. .9f)1f else 0f }
        val rows=BodyEdgeFit.refine(p.copy(points=points),m).sections.filter { it.part==11 }
        assertEquals(2,rows.size)
        for(row in rows)assertEquals(24f,row.positive!!,4f)
        points[13]=points[13].copy(visibility=.1f)
        assertTrue(BodyEdgeFit.refine(p.copy(points=points),m).sections.none { it.part==11 })
    }
    @Test fun filterSmoothsCorrectionsInBodyCoordinatesAndClearsOnLoss() {
        val p=pose(); val filter=BodyEdgeFilter()
        val first=BodySection(0,.5f,GPoint(200f,300f),GPoint(1f,0f),100f,100f)
        filter.update(p,BodyEdges(sections=listOf(first)),1000)
        val moved=first.copy(center=GPoint(230f,300f),positive=116f)
        val result=filter.update(p,BodyEdges(sections=listOf(moved)),1033).sections.single()
        assertEquals(230f,result.center.x,0f)
        assertTrue(result.positive!! in 100.1f..115.9f)
        assertTrue(filter.update(p,BodyEdges(),1066).sections.isEmpty())
        assertEquals(116f,filter.update(p,BodyEdges(sections=listOf(moved)),1099).sections.single().positive!!,0f)
    }
    @Test fun thickTouchingUpperArmAndForearmAreNotTorsoBoundaryEvidence() {
        for(forearm in listOf(false,true)) {
            val p=pose();val points=p.points.toMutableList()
            points[13]=PosePoint(.25f,.6f,1f,1f)
            points[15]=PosePoint(.23f,.8f,1f,1f)
            val a=if(forearm)GPoint(100f,360f) else GPoint(120f,180f)
            val b=if(forearm)GPoint(92f,480f) else GPoint(100f,360f)
            val m=mask { x,y -> if(x in .3f.. .7f && y in .24f.. .9f || PhotoSurface.distanceToSegment(GPoint(x*400,y*600),a,b)<30f)1f else 0f }
            val rows=BodyEdgeFit.refine(p.copy(points=points),m).sections.filter { it.part==0 }
            val row=rows.find { it.fraction==if(forearm).75f else .5f }!!
            assertNull("touching arm must not widen torso",row.negative)
            assertNotNull(row.positive)
        }
    }
    @Test fun shoulderSeamFindsSurfaceInsteadOfJointCentre() {
        val fit = BodyEdgeFit.refine(pose(), silhouette())
        assertEquals(.24f, fit.shoulder11!!.y/600, .008f)
        assertEquals(.24f, fit.shoulder12!!.y/600, .008f)
        assertTrue(fit.contour.isNotEmpty())
    }
    @Test fun correctionScalesWithBodyNotFixedPixels() {
        val a = BodyEdgeFit.refine(pose(), silhouette())
        val b = BodyEdgeFit.refine(pose(800,1200), silhouette())
        assertEquals(a.lift11*2, b.lift11, .01f)
    }
    @Test fun frontCameraReflectionKeepsCorrectAnatomicalSide() {
        val p = pose(); val reflected = p.copy(points=p.points.map { it.copy(x=1-it.x) })
        val a = BodyEdgeFit.refine(p, silhouette()); val b = BodyEdgeFit.refine(reflected, silhouette())
        assertEquals(400-a.shoulder11!!.x, b.shoulder11!!.x, .01f)
        assertEquals(a.shoulder11.y, b.shoulder11.y, .01f)
    }
    @Test fun noConfidentBoundaryLeavesPoseUntouched() {
        for (value in listOf(0f, .5f, 1f, Float.NaN)) {
            val fit = BodyEdgeFit.refine(pose(), mask { _,_->value })
            assertNull(fit.shoulder11); assertNull(fit.shoulder12)
            assertEquals(0f, fit.lift11, 0f)
        }
    }
    @Test fun distantBoundaryDoesNotPullClothingToHead() {
        val fit = BodyEdgeFit.refine(pose(), mask { _,y -> if(y>.05f) 1f else 0f })
        assertNull(fit.shoulder11); assertNull(fit.shoulder12)
    }
    @Test fun rejectedOrOccludedPoseIsNotCorrected() {
        val p=pose()
        assertNull(BodyEdgeFit.refine(p.copy(box=null), silhouette()).shoulder11)
        val points=p.points.toMutableList(); points[11]=points[11].copy(visibility=.4f)
        val fit=BodyEdgeFit.refine(p.copy(points=points), silhouette())
        assertNull(fit.shoulder11); assertNotNull(fit.shoulder12)
    }
    @Test fun tiltedBodySearchesAlongTorsoAxis() {
        val p=pose(); val angle=.25f
        val c=kotlin.math.cos(angle); val s=kotlin.math.sin(angle)
        fun rotate(x:Float,y:Float)=GPoint(200+(x-200)*c-(y-300)*s,300+(x-200)*s+(y-300)*c)
        val tilted=p.copy(points=p.points.map { val q=rotate(it.x*400,it.y*600);it.copy(x=q.x/400,y=q.y/600) })
        val m=mask { x,y ->
            val dx=x*400-200;val dy=y*600-300
            val ox=(200+dx*c+dy*s)/400;val oy=(300-dx*s+dy*c)/600
            if(ox in .2f.. .8f && oy in .24f.. .9f) 1f else 0f
        }
        val fit=BodyEdgeFit.refine(tilted,m);val expected=rotate(120f,144f)
        assertNotNull(fit.shoulder11)
        assertTrue((fit.shoulder11!!-expected).length<5f)
    }
    @Test fun nearAndFarBodiesUseObservedEdgeInTheirOwnScale() {
        val p=pose()
        for (scale in listOf(.35f,.6f,1f)) {
            val scaled=p.copy(points=p.points.map { it.copy(x=.5f+(it.x-.5f)*scale,y=.5f+(it.y-.5f)*scale) })
            val m=mask { x,y ->
                val ox=.5f+(x-.5f)/scale; val oy=.5f+(y-.5f)/scale
                if(ox in .2f.. .8f && oy in .24f.. .9f) 1f else 0f
            }
            val fit=BodyEdgeFit.refine(scaled,m)
            assertNotNull(fit.shoulder11)
            assertEquals(.5f+(.24f-.5f)*scale,fit.shoulder11!!.y/600,.009f)
        }
    }
    @Test fun differentShoulderWidthsAndTorsoLengthsDoNotUseOneBodyTemplate() {
        for (halfWidth in listOf(.12f,.2f,.28f)) for(hipY in listOf(.6f,.75f,.85f)) {
            val p=pose();val points=p.points.toMutableList()
            points[11]=points[11].copy(x=.5f-halfWidth)
            points[12]=points[12].copy(x=.5f+halfWidth)
            points[23]=points[23].copy(y=hipY);points[24]=points[24].copy(y=hipY)
            val top=.3f-(hipY-.3f)*.12f
            val m=mask { x,y -> if(x in (.5f-halfWidth-.06f)..(.5f+halfWidth+.06f) && y in top.. .95f) 1f else 0f }
            val fit=BodyEdgeFit.refine(p.copy(points=points),m)
            assertNotNull(fit.shoulder11)
            assertEquals(top,fit.shoulder11!!.y/600,.008f)
        }
    }

}
