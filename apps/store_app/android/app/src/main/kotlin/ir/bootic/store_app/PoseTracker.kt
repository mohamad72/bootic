package ir.bootic.store_app

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import java.nio.ByteOrder
import com.google.mediapipe.framework.image.ByteBufferExtractor
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
/** All inference is local; no image or landmark data is persisted. */
internal class PoseTracker(
    context: Context,
    private val onResult: (PoseObservation, Long) -> Unit,
    private val onError: () -> Unit,
) {
    private val landmarker: PoseLandmarker
    @Volatile var debugEdges = false
    private val edgeFilter=BodyEdgeFilter()

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
            .setOutputSegmentationMasks(true)
            .setMinPoseDetectionConfidence(PoseGeometry.MODEL_CONFIDENCE)
            .setMinPosePresenceConfidence(PoseGeometry.MODEL_CONFIDENCE)
            .setMinTrackingConfidence(PoseGeometry.MODEL_CONFIDENCE)
            .setResultListener { result: PoseLandmarkerResult, image: MPImage ->
                val points = result.landmarks().firstOrNull().orEmpty().map {
                    PosePoint(it.x(), it.y(), it.visibility().orElse(0f), it.presence().orElse(0f), it.z())
                }
                val raw = PoseGeometry.evaluate(points, image.width, image.height)
                val started = SystemClock.uptimeMillis()
                val edges = try {
                    val mask = result.segmentationMasks().orElse(emptyList()).firstOrNull()
                    if (mask == null) BodyEdges(status="no_mask") else {
                        val buffer = ByteBufferExtractor.extract(mask).order(ByteOrder.nativeOrder()).asFloatBuffer()
                        require(buffer.remaining() >= mask.width*mask.height)
                        val offset = buffer.position()
                        BodyEdgeFit.refine(raw, BodyMask(mask.width, mask.height) { x, y ->
                            buffer.get(offset+y*mask.width+x)
                        }, includeContour=debugEdges)
                    }
                } catch (_: Exception) { BodyEdges(status="mask_error") }
                val filtered=edgeFilter.update(raw,edges,result.timestampMs())
                onResult(raw.copy(bodyEdges=filtered, edgeMs=SystemClock.uptimeMillis()-started), result.timestampMs())
            }
            .setErrorListener { _: RuntimeException -> onError() }
            .build()
        landmarker = PoseLandmarker.createFromOptions(context.applicationContext, options)
    }

    fun detect(bitmap: Bitmap, timestampMs: Long) {
        landmarker.detectAsync(BitmapImageBuilder(bitmap).build(), timestampMs)
    }

    fun close() = landmarker.close()

}
