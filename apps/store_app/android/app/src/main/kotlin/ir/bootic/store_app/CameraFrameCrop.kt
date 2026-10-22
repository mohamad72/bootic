package ir.bootic.store_app

import java.nio.ByteBuffer

internal data class PackedRgba(val width: Int, val height: Int, val bytes: ByteArray)

/** CameraX cropRect is in the unrotated buffer. Copy that ROI before rotating
 * or mirroring, so model, projector and PreviewView see the same sensor area. */
internal fun packRgbaCrop(
    buffer: ByteBuffer, width: Int, height: Int, rowStride: Int,
    left: Int, top: Int, right: Int, bottom: Int,
): PackedRgba {
    require(width > 0 && height > 0 && rowStride >= width * 4)
    require(left >= 0 && top >= 0 && right <= width && bottom <= height)
    require(right > left && bottom > top)
    val cropWidth = right - left
    val cropHeight = bottom - top
    val rowBytes = cropWidth * 4
    val packed = ByteArray(rowBytes * cropHeight)
    val source = buffer.duplicate()
    for (y in 0 until cropHeight) {
        source.position((top + y) * rowStride + left * 4)
        source.get(packed, y * rowBytes, rowBytes)
    }
    return PackedRgba(cropWidth, cropHeight, packed)
}
