package ir.bootic.store_app

import org.junit.Assert.*
import org.junit.Test

class TryonEffectGeometryTest {
    @Test fun frameIncludesVisibleHeadHandsAndFeet() {
        val frame = PersonFrame.enclose(listOf(
            BodyPoint(0.5f, 0.1f), BodyPoint(0.2f, 0.45f),
            BodyPoint(0.8f, 0.45f), BodyPoint(0.4f, 0.95f),
            BodyPoint(0.6f, 0.95f),
        ), headPadding = 0.05f)!!
        assertTrue(frame.top <= 0.05f)
        assertTrue(frame.bottom >= 0.95f)
        assertTrue(frame.left < 0.2f)
        assertTrue(frame.right > 0.8f)
    }

    @Test fun invalidOrHiddenLandmarksCannotStretchTheFrame() {
        val frame = PersonFrame.enclose(listOf(
            BodyPoint(0.4f, 0.2f), BodyPoint(0.6f, 0.8f),
            BodyPoint(Float.NaN, 0.5f), BodyPoint(0.9f, 0.9f, visible = false),
            BodyPoint(2f, -2f),
        ), headPadding = 0f)!!
        assertTrue(frame.right < 0.7f)
        assertTrue(frame.top >= 0.15f)
        assertNull(PersonFrame.enclose(emptyList(), 0f))
    }

    @Test fun trailWrapsAcrossPathStartWithoutChangingItsLength() {
        val ranges = movingTrail(0.06f, 0.22f)
        assertEquals(2, ranges.size)
        assertEquals(0.22f, ranges.sumOf { (it.end - it.start).toDouble() }.toFloat(), 0.0001f)
        assertTrue(ranges.all { it.start >= 0f && it.end <= 1f && it.end > it.start })
    }

    @Test fun trailCompletesOneLapInTwoSeconds() {
        assertEquals(0.5f, EffectMode.LOADING.phaseAt(1000), 0.0001f)
        assertEquals(0f, EffectMode.LOADING.phaseAt(2000), 0.0001f)
        assertEquals(0.25f, EffectMode.LOADING.phaseAt(2500), 0.0001f)
    }
}
