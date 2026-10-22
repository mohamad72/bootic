package ir.bootic.store_app

import java.nio.ByteBuffer
import org.junit.Assert.*
import org.junit.Test

class CameraFrameCropTest {
    private fun frame(): ByteBuffer = ByteBuffer.allocate(56).apply {
        // 4 x 3 RGBA, 4 bytes padding per row, no padding after the last row.
        for (y in 0..2) for (x in 0..3) for (channel in 0..3) {
            put(y * 20 + x * 4 + channel, (y * 10 + x).toByte())
        }
        position(7)
    }

    @Test fun modelReceivesOnlyTheSharedPreviewCrop() {
        val source = frame()
        val result = packRgbaCrop(source, 4, 3, 20, 1, 1, 3, 3)
        assertEquals(2, result.width)
        assertEquals(2, result.height)
        assertArrayEquals(listOf(11, 12, 21, 22).flatMap { value -> List(4) { value.toByte() } }.toByteArray(), result.bytes)
        assertEquals(7, source.position())
    }

    @Test fun fullFrameDropsRowPaddingWithoutDroppingEdgePixels() {
        val result = packRgbaCrop(frame(), 4, 3, 20, 0, 0, 4, 3)
        assertEquals(48, result.bytes.size)
        assertEquals(0, result.bytes[0].toInt())
        assertEquals(23, result.bytes.last().toInt())
    }
}
