package ir.bootic.store_app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executor

/** Operates only on normalized app-private PNG copies, never a gallery original. */
internal class GarmentCutout(private val context: Context, private val executor: Executor) {
    fun process(path: String?, result: MethodChannel.Result) {
        executor.execute {
            var bitmap: Bitmap? = null
            try {
                val file = File(requireNotNull(path)).canonicalFile
                require(file.path.startsWith(File(context.filesDir, "garments").canonicalPath + File.separator))
                require(file.extension.equals("png", true) && file.isFile && file.length() <= 15L * 1024 * 1024)
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(file.path, bounds)
                require(bounds.outWidth in 64..6000 && bounds.outHeight in 64..6000)
                var sample = 1
                while (bounds.outWidth / sample > 1600 || bounds.outHeight / sample > 1600) sample *= 2
                val source = BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply {
                    inSampleSize = sample
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                }) ?: error("Invalid image")
                bitmap = source
                // Do not re-segment an already transparent asset.
                if (hasTransparency(source)) {
                    saveCropped(source, file)
                    source.recycle()
                    result.success(null)
                    return@execute
                }
                val segmenter = SubjectSegmentation.getClient(
                    SubjectSegmenterOptions.Builder().enableForegroundBitmap().build(),
                )
                segmenter.process(InputImage.fromBitmap(source, 0))
                    .addOnSuccessListener(executor) { segmentation ->
                        val foreground = segmentation.foregroundBitmap
                        try {
                            requireNotNull(foreground)
                            require(hasTransparency(foreground))
                            saveCropped(foreground, file)
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("CUTOUT_EMPTY", "لباس از پس‌زمینه جدا نشد؛ لباس را به‌تنهایی با فاصله از پس‌زمینه عکس بگیرید", null)
                        } finally {
                            if (foreground !== source) foreground?.recycle()
                            source.recycle()
                            segmenter.close()
                        }
                    }
                    .addOnFailureListener(executor) {
                        source.recycle()
                        segmenter.close()
                        result.error("CUTOUT_UNAVAILABLE", "مدل حذف پس‌زمینه آماده نیست؛ اینترنت و سرویس‌های گوگل را بررسی و کمی بعد دوباره تلاش کنید", null)
                    }
            } catch (_: Exception) {
                bitmap?.takeUnless { it.isRecycled }?.recycle()
                result.error("CUTOUT_FAILED", "پردازش عکس لباس ممکن نشد؛ عکس دیگری انتخاب کنید", null)
            }
        }
    }

    private fun hasTransparency(bitmap: Bitmap): Boolean {
        if (!bitmap.hasAlpha()) return false
        val row = IntArray(bitmap.width)
        var transparent = 0
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            transparent += row.count { Color.alpha(it) < 16 }
        }
        return transparent > bitmap.width * bitmap.height / 100
    }

    private fun saveCropped(bitmap: Bitmap, file: File) {
        var left = bitmap.width
        var top = bitmap.height
        var right = -1
        var bottom = -1
        val row = IntArray(bitmap.width)
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in row.indices) if (Color.alpha(row[x]) > 16) {
                left = minOf(left, x); right = maxOf(right, x)
                top = minOf(top, y); bottom = maxOf(bottom, y)
            }
        }
        require(right >= left && bottom >= top)
        // Keep the renderer's minimum image dimensions while removing empty margins.
        left = maxOf(0, minOf(left, right - 63))
        top = maxOf(0, minOf(top, bottom - 63))
        right = minOf(bitmap.width - 1, maxOf(right, left + 63))
        bottom = minOf(bitmap.height - 1, maxOf(bottom, top + 63))
        val cropped = Bitmap.createBitmap(bitmap, left, top, right - left + 1, bottom - top + 1)
        val temporary = File(file.path + ".cutout.tmp")
        try {
            temporary.outputStream().use { check(cropped.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            check(temporary.renameTo(file))
        } finally {
            temporary.delete()
            if (cropped !== bitmap) cropped.recycle()
        }
    }
}
