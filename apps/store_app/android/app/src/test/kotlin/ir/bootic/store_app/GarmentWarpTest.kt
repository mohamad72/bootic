package ir.bootic.store_app

import org.junit.Assert.*
import org.junit.Test

class GarmentWarpTest {
    private val sleeve = SleeveSpec("left", listOf(GPoint(0f, 0f), GPoint(100f, 0f), GPoint(0f, 100f)), GPoint(100f, 100f), GPoint(100f, 300f), GPoint(0f, 250f))
    private val spec = GarmentRenderSpec(1000f, 1500f, sleeve.polygon, emptyList(), GPoint(100f, 100f), GPoint(800f, 150f), GPoint(450f, 1200f), listOf(sleeve), true)
    private fun points() = MutableList(33) { PosePoint(.5f, .5f, 1f, 1f) }.apply {
        this[11] = PosePoint(.7f, .25f, 1f, 1f)
        this[12] = PosePoint(.3f, .2f, 1f, 1f)
        this[14] = PosePoint(.2f, .4f, 1f, 1f)
        this[23] = PosePoint(.6f, .7f, 1f, 1f)
        this[24] = PosePoint(.4f, .7f, 1f, 1f)
    }
    private fun same(expected: GPoint, actual: GPoint) {
        assertEquals(expected.x, actual.x, .001f)
        assertEquals(expected.y, actual.y, .001f)
    }
    @Test fun sourceShoulderAndHemAnchorsMatchBodyInsteadOfImageBounds() {
        val warp = GarmentWarp(spec, points(), 480, 640, false)
        same(GPoint(144f, 128f), warp.torso(spec.leftShoulder))
        same(GPoint(336f, 160f), warp.torso(spec.rightShoulder))
        same(GPoint(240f, 448f), warp.torso(spec.hem))
    }
    @Test fun textureMirrorsOnceWithoutMirroringBodyCoordinatesAgain() {
        val warp = GarmentWarp(spec, points(), 480, 640, true)
        same(GPoint(336f, 160f), warp.torso(spec.leftShoulder))
        same(GPoint(144f, 128f), warp.torso(spec.rightShoulder))
    }
    @Test fun sleeveMovesWithElbowButSeamStaysOnTorso() {
        val p = points()
        val initial = GarmentWarp(spec, p.toList(), 480, 640, false)
        p[14] = PosePoint(.1f, .2f, 1f, 1f)
        val moved = GarmentWarp(spec, p, 480, 640, false)
        same(moved.torso(sleeve.armpit), moved.sleeve(sleeve.armpit, sleeve))
        assertTrue((moved.sleeve(sleeve.hem, sleeve) - initial.sleeve(sleeve.hem, sleeve)).length > 10f)
    }
    @Test fun hiddenElbowDoesNotInventSleeveMotion() {
        val p = points(); p[14] = p[14].copy(visibility = .1f)
        val warp = GarmentWarp(spec, p, 480, 640, false)
        same(warp.torso(sleeve.hem), warp.sleeve(sleeve.hem, sleeve))
    }
    @Test fun surfaceAnchorsDriveBothTorsoAndSleeveWithoutMovingHips() {
        val edges = BodyEdges(shoulder11=GPoint(336f,140f), shoulder12=GPoint(144f,108f))
        val warp=GarmentWarp(spec,points(),480,640,false,edges)
        same(edges.shoulder12!!,warp.torso(spec.leftShoulder))
        same(edges.shoulder11!!,warp.torso(spec.rightShoulder))
        same(GPoint(240f,448f),warp.torso(spec.hem))
        same(warp.torso(sleeve.shoulder),warp.sleeve(sleeve.shoulder,sleeve))
        same(warp.torso(sleeve.armpit),warp.sleeve(sleeve.armpit,sleeve))
        val mirrored=GarmentWarp(spec,points(),480,640,true,edges)
        same(edges.shoulder11,mirrored.torso(spec.leftShoulder))
    }

}
