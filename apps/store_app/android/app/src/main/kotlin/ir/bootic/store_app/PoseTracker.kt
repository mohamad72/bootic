package ir.bootic.store_app

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Approximate torso box in the upright, optionally mirrored input image. */
internal data class TorsoBox(
    val centerX: Float,
    val centerY: Float,
    val width: Float,
    val height: Float,
    val imageWidth: Int,
    val imageHeight: Int,
)

/** All inference is local; no image or landmark data is persisted. */
internal class PoseTracker(
    context: Context,
    private val onResult: (TorsoBox?, Long) -> Unit,
    private val onError: () -> Unit,
) {
    private val landmarker: PoseLandmarker

    init {
        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath("pose_landmarker_lite.task")
                    .setDelegate(Delegate.CPU)
                    .build(),
            )
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumPoses(1)
            .setMinPoseDetectionConfidence(0.65f)
            .setMinPosePresenceConfidence(0.65f)
            .setMinTrackingConfidence(0.65f)
            .setResultListener { result: PoseLandmarkerResult, image: MPImage ->
                onResult(torso(result, image.width, image.height), result.timestampMs())
            }
            .setErrorListener { _: RuntimeException -> onError() }
            .build()
        landmarker = PoseLandmarker.createFromOptions(context.applicationContext, options)
    }

    fun detect(bitmap: Bitmap, timestampMs: Long) {
        landmarker.detectAsync(BitmapImageBuilder(bitmap).build(), timestampMs)
    }

    fun close() = landmarker.close()

    private fun torso(result: PoseLandmarkerResult, width: Int, height: Int): TorsoBox? {
        val points = result.landmarks().firstOrNull() ?: return null
        if (points.size <= 24) return null
        val leftShoulder = points[11]
        val rightShoulder = points[12]
        val leftHip = points[23]
        val rightHip = points[24]
        val torsoPoints = listOf(leftShoulder, rightShoulder, leftHip, rightHip)
        if (torsoPoints.any {
            it.visibility().orElse(0f) < 0.6f ||
                it.presence().orElse(0f) < 0.6f ||
                !it.x().isFinite() || !it.y().isFinite() ||
                it.x() !in -0.05f..1.05f || it.y() !in -0.05f..1.05f
        }) return null
        val shoulderY = (leftShoulder.y() + rightShoulder.y()) / 2f
        val hipY = (leftHip.y() + rightHip.y()) / 2f
        val shoulderSpan = abs(leftShoulder.x() - rightShoulder.x())
        val torsoHeight = hipY - shoulderY
        if (shoulderSpan < 0.06f || shoulderSpan > 0.8f || torsoHeight < 0.08f || torsoHeight > 0.8f) return null
        val shoulderCenter = (leftShoulder.x() + rightShoulder.x()) / 2f
        val hipCenter = (leftHip.x() + rightHip.x()) / 2f
        if (abs(shoulderCenter - hipCenter) > shoulderSpan) return null
        val centerX = (shoulderCenter + hipCenter) / 2f
        val centerY = (shoulderY + hipY) / 2f
        val boxWidth = min(0.95f, max(0.12f, shoulderSpan * 1.6f))
        val boxHeight = min(0.95f, max(0.12f, torsoHeight * 1.35f))
        return TorsoBox(centerX, centerY, boxWidth, boxHeight, width, height)
    }
}
