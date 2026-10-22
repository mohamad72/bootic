package ir.bootic.store_app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import java.io.File
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor

internal data class GarmentPiece(
    val bitmap: Bitmap, val left: Float, val top: Float,
    val sourceScaleX: Float, val sourceScaleY: Float,
    val polygon: List<GPoint>, val sleeve: SleeveSpec?,
)

/** Prepared once when a garment changes, never segmented/decoded per frame. */
internal class GarmentRenderAsset(val spec: GarmentRenderSpec, val masked: Bitmap, val pieces: List<GarmentPiece>) {
    fun bounds(pose: PoseObservation, mirror: Boolean): TorsoBox? {
        if (pose.box == null) return null
        val warp = GarmentWarp(spec, pose.points, pose.imageWidth, pose.imageHeight, mirror, pose.bodyEdges)
        val mapped = pieces.flatMap { piece -> piece.polygon.map {
            if (piece.sleeve == null) warp.torso(it) else warp.sleeve(it, piece.sleeve)
        } }
        if (mapped.isEmpty()) return null
        val l = mapped.minOf { it.x }; val r = mapped.maxOf { it.x }
        val t = mapped.minOf { it.y }; val b = mapped.maxOf { it.y }
        return TorsoBox((l+r)/2/pose.imageWidth, (t+b)/2/pose.imageHeight,
            (r-l)/pose.imageWidth, (b-t)/pose.imageHeight, pose.imageWidth, pose.imageHeight, pose.personFrame)
    }

    companion object {
        fun load(file: File, spec: GarmentRenderSpec): GarmentRenderAsset {
            val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(file.path, options)
            require(options.outWidth in 64..6000 && options.outHeight in 64..6000)
            // Scaling the untrimmed canvas is safe; a cropped reference is not.
            require(abs(options.outWidth.toFloat()/options.outHeight - spec.width/spec.height) < 0.005f) {
                "ابعاد عکس با JSON هماهنگ نیست؛ عکس اصلیِ همان JSON را انتخاب کنید"
            }
            var sample = 1
            while (options.outWidth/sample > 1600 || options.outHeight/sample > 1600) sample *= 2
            options.inJustDecodeBounds = false
            options.inSampleSize = sample
            options.inPreferredConfig = Bitmap.Config.ARGB_8888
            val source = requireNotNull(BitmapFactory.decodeFile(file.path, options))
            try {
                val sx = source.width/spec.width; val sy = source.height/spec.height
                fun path(points: List<GPoint>): Path = Path().apply {
                    moveTo(points.first().x*sx, points.first().y*sy)
                    for (p in points.drop(1)) lineTo(p.x*sx, p.y*sy)
                    close()
                }
                val outer = path(spec.outer)
                for (hole in spec.holes) check(outer.op(path(hole), Path.Op.DIFFERENCE))
                val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
                    shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
                }
                val masked = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
                Canvas(masked).drawPath(outer, paint)
                val torso = Path(outer)
                for (sleeve in spec.sleeves) check(torso.op(path(sleeve.polygon), Path.Op.DIFFERENCE))
                fun piece(region: Path, polygon: List<GPoint>, sleeve: SleeveSpec?): GarmentPiece? {
                    val bounds = RectF(); region.computeBounds(bounds, true)
                    if (bounds.isEmpty) return null
                    val left = floor(bounds.left).coerceAtLeast(0f)
                    val top = floor(bounds.top).coerceAtLeast(0f)
                    val right = ceil(bounds.right).coerceAtMost(source.width.toFloat())
                    val bottom = ceil(bounds.bottom).coerceAtMost(source.height.toFloat())
                    if (right<=left || bottom<=top) return null
                    val bitmap = Bitmap.createBitmap((right-left).toInt(), (bottom-top).toInt(), Bitmap.Config.ARGB_8888)
                    Canvas(bitmap).apply { translate(-left, -top); drawPath(region, paint) }
                    return GarmentPiece(bitmap, left, top, 1/sx, 1/sy, polygon, sleeve)
                }
                val pieces = mutableListOf<GarmentPiece>()
                piece(torso, spec.outer, null)?.let(pieces::add)
                for (sleeve in spec.sleeves) {
                    val region = path(sleeve.polygon)
                    check(region.op(outer, Path.Op.INTERSECT))
                    piece(region, sleeve.polygon, sleeve)?.let(pieces::add)
                }
                return GarmentRenderAsset(spec, masked, pieces)
            } finally { source.recycle() }
        }
    }
}
