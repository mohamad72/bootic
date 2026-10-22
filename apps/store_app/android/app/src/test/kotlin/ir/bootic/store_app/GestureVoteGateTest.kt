package ir.bootic.store_app

import org.junit.Assert.*
import org.junit.Test

class GestureVoteGateTest {
    @Test fun toleratesOneMissButDoesNotAcceptASingleFrame() {
        val gate = GestureVoteGate()
        assertNull(gate.update("Thumb_Up", 1000, true))
        assertNull(gate.update(null, 1120, true))
        assertEquals("Thumb_Up", gate.update("Thumb_Up", 1240, true))
    }

    @Test fun heldThumbDoesNotVoteOnNextGarment() {
        val gate = GestureVoteGate()
        gate.update("Thumb_Up", 1000, true)
        assertEquals("Thumb_Up", gate.update("Thumb_Up", 1120, true))
        for (time in 1240L..4000L step 120) {
            assertNull(gate.update("Thumb_Up", time, true))
        }
        gate.update(null, 4100, false)
        gate.update(null, 4460, false)
        assertNull(gate.update("Thumb_Down", 4580, true))
        assertEquals("Thumb_Down", gate.update("Thumb_Down", 4700, true))
    }

    @Test fun disabledVotingCannotConsumeTheNextVote() {
        val gate = GestureVoteGate()
        gate.update("Thumb_Up", 1000, false)
        gate.update("Thumb_Up", 1120, false)
        assertNull(gate.update("Thumb_Up", 1240, true))
        assertEquals("Thumb_Up", gate.update("Thumb_Up", 1360, true))
    }

    @Test fun staleOrConflictingFramesDoNotBuildAgreement() {
        val gate = GestureVoteGate()
        gate.update("Thumb_Up", 1000, true)
        assertNull(gate.update("Thumb_Up", 2000, true))
        assertNull(gate.update("Thumb_Down", 2120, true))
        assertNull(gate.update("Thumb_Up", 2240, true))
        assertEquals("Thumb_Up", gate.update("Thumb_Up", 2360, true))
    }
}
