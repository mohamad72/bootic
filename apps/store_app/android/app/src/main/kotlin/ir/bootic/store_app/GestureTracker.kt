package ir.bootic.store_app

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizer
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizerResult

/** Runs the bundled hand model locally. Only a label and confidence leave this class. */
internal class GestureTracker(
    context: Context,
    private val onResult: (String?, Long) -> Unit,
    private val onError: () -> Unit,
) {
    private val recognizer: GestureRecognizer

    init {
        val options = GestureRecognizer.GestureRecognizerOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath("gesture_recognizer.task")
                    .setDelegate(Delegate.CPU)
                    .build(),
            )
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumHands(1)
            .setMinHandDetectionConfidence(0.6f)
            .setMinHandPresenceConfidence(0.6f)
            .setMinTrackingConfidence(0.6f)
            .setResultListener { result: GestureRecognizerResult, _: MPImage ->
                val category = result.gestures().firstOrNull()?.firstOrNull()
                val name = category?.categoryName()
                val accepted = if (category != null && category.score() >= 0.75f &&
                    (name == "Thumb_Up" || name == "Thumb_Down")) name else null
                onResult(accepted, result.timestampMs())
            }
            .setErrorListener { _: RuntimeException -> onError() }
            .build()
        recognizer = GestureRecognizer.createFromOptions(context.applicationContext, options)
    }

    fun detect(bitmap: Bitmap, timestampMs: Long) {
        recognizer.recognizeAsync(BitmapImageBuilder(bitmap).build(), timestampMs)
    }

    fun close() = recognizer.close()
}
