package ir.bootic.store_app

import org.junit.Assert.*
import org.junit.Test

class PoseGeometryTest {
    private fun points(): MutableList<PosePoint> = MutableList(33) {
        PosePoint(0.5f, 0.5f, 0.9f, 0.9f)
    }.apply {
        this[11] = PosePoint(0.35f, 0.25f, 0.9f, 0.9f)
        this[12] = PosePoint(0.65f, 0.25f, 0.9f, 0.9f)
        this[23] = PosePoint(0.4f, 0.65f, 0.9f, 0.9f)
        this[24] = PosePoint(0.6f, 0.65f, 0.9f, 0.9f)
    }

    @Test fun garmentDoesNotInflateShoulderSpanBySixtyPercent() {
        val box = PoseGeometry.torso(points(), 480, 640)!!
        assertTrue("garment width should be within 20% of shoulder span: ${box.width}", box.width <= 0.36f)
        assertTrue(box.height <= 0.48f)
    }

    @Test fun emptyPoseAndNonFiniteTorsoAreRejected() {
        assertNull(PoseGeometry.torso(emptyList(), 480, 640))
        val points = points()
        points[11] = PosePoint(Float.NaN, 0.2f, 1f, 1f)
        assertNull(PoseGeometry.torso(points, 480, 640))
    }
    @Test fun partlyOccludedFarSideStillTracksDuringTurn() {
        val points = points()
        points[12] = PosePoint(0.39f, 0.25f, 0.4f, 0.9f)
        points[24] = PosePoint(0.43f, 0.65f, 0.4f, 0.9f)
        assertEquals("accepted", PoseGeometry.evaluate(points, 480, 640).reason)
    }

    @Test fun weakTorsoIsRejectedButRawPointsRemainForDebugging() {
        val points = points()
        points[11] = points[11].copy(visibility = 0.1f)
        val result = PoseGeometry.evaluate(points, 480, 640)
        assertNull(result.box)
        assertEquals("low_confidence", result.reason)
        assertEquals(33, result.points.size)
        assertTrue(result.shoulderPx > 0)
    }

    @Test fun tiltedShouldersRotateGarmentUsingPixelAspectRatio() {
        val points = points()
        points[11] = points[11].copy(y = 0.2f)
        points[12] = points[12].copy(y = 0.3f)
        val box = PoseGeometry.torso(points, 480, 640)!!
        assertEquals(23.96f, box.rotationDegrees, 0.1f)
        assertEquals(box.rotationDegrees, box.forViewport(1080, 1920).rotationDegrees, 0f)
    }

    @Test fun croppedViewportDoesNotClampOrStretchGarment() {
        val box = TorsoBox(0.05f, 0.5f, 0.3f, 0.4f, 640, 480)
        val p = box.forViewport(360, 640)
        assertTrue(p.centerX < 0f)
        assertEquals(0.711111f, p.width, 0.00001f)
        assertEquals(0.4f, p.height, 0.00001f)
    }

    @Test fun glowDoesNotBlockGarmentButSwitchLoadingDoes() {
        assertFalse(EffectMode.NONE.blocksGarment)
        assertFalse(EffectMode.DETECTION.blocksGarment)
        assertTrue(EffectMode.LOADING.blocksGarment)
        assertEquals(2000L, EffectMode.LOADING.durationMs)
    }

}
