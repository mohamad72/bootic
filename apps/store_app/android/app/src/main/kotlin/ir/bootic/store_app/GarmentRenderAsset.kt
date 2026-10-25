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
internal class GarmentRenderAsset(val spec: GarmentRenderSpec?, val masked: Bitmap, val pieces: List<GarmentPiece>, val model: GarmentModel? = null) {
    // Constructed by the existing background asset loader, shared by bounds and
    // both displays. Live frames never walk all source polygon edges again.
    val photoMesh:PhotoMesh?=spec?.let { PhotoMesh(it) }
    fun bounds(pose: PoseObservation, mirror: Boolean): TorsoBox? {
        if (pose.box == null) return null
        model?.let { m ->
            val frame=m.frame(pose,mirror) ?: return null
            val l=frame.positions.minOf { it.x }; val r=frame.positions.maxOf { it.x }
            val t=frame.positions.minOf { it.y }; val b=frame.positions.maxOf { it.y }
            return TorsoBox((l+r)/2/pose.imageWidth,(t+b)/2/pose.imageHeight,(r-l)/pose.imageWidth,(b-t)/pose.imageHeight,pose.imageWidth,pose.imageHeight,pose.personFrame)
        }
        val mesh=photoMesh ?: return null
        val warp = GarmentWarp(requireNotNull(spec), pose.points, pose.imageWidth, pose.imageHeight, mirror, pose.bodyEdges,mesh.surface)
        val mapped=mesh.project(warp,pose,mirror)
        if(mesh.boundIndices.isEmpty())return null
        val l=mesh.boundIndices.minOf { mapped[it*2] };val r=mesh.boundIndices.maxOf { mapped[it*2] }
        val t=mesh.boundIndices.minOf { mapped[it*2+1] };val b=mesh.boundIndices.maxOf { mapped[it*2+1] }
        return TorsoBox((l+r)/2/pose.imageWidth, (t+b)/2/pose.imageHeight,
            (r-l)/pose.imageWidth, (b-t)/pose.imageHeight, pose.imageWidth, pose.imageHeight, pose.personFrame)
    }

    companion object {
        fun model(map: Map<*,*>, file: File?): GarmentRenderAsset {
            val spec=GarmentModelSpec.fromMap(map)
            val texture=if(spec.mode=="source") {
                val sourceSpec=GarmentRenderSpec.fromMap(map["source_metadata"] as Map<*,*>)
                val original=load(requireNotNull(file),sourceSpec)
                // Independent torso and sleeve cells prevent a chest logo from
                // being repeated onto both arms. Unobserved areas use base color.
                val atlas=Bitmap.createBitmap(512,1552,Bitmap.Config.ARGB_8888)
                atlas.eraseColor(spec.baseColor)
                val target=Canvas(atlas)
                target.drawRect(0f,0f,512f,16f,Paint().apply { color=android.graphics.Color.WHITE })
                val sx=original.masked.width/sourceSpec.width
                val sy=original.masked.height/sourceSpec.height
                fun cell(a:GPoint,b:GPoint,c:GPoint,destination:FloatArray,top:Float,polygon:List<GPoint>?=null) {
                    val matrix=android.graphics.Matrix()
                    require(matrix.setPolyToPoly(floatArrayOf(a.x*sx,a.y*sy,b.x*sx,b.y*sy,c.x*sx,c.y*sy),0,destination,0,3))
                    target.save();target.clipRect(0f,top,512f,top+512)
                    if(polygon!=null) {
                        val path=Path().apply {
                            moveTo(polygon.first().x*sx,polygon.first().y*sy)
                            for(p in polygon.drop(1))lineTo(p.x*sx,p.y*sy)
                            close();transform(matrix)
                        }
                        target.clipPath(path)
                    }
                    target.drawBitmap(original.masked,matrix,Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
                    target.restore()
                }
                cell(sourceSpec.leftShoulder,sourceSpec.rightShoulder,sourceSpec.hem,floatArrayOf(0f,16f,512f,16f,256f,528f),16f)
                for(sleeve in sourceSpec.sleeves) {
                    val top=if(sleeve.side=="left")528f else 1040f
                    cell(sleeve.shoulder,sleeve.armpit,sleeve.hem,floatArrayOf(0f,top,512f,top,256f,top+512),top,sleeve.polygon)
                }
                original.masked.recycle();original.pieces.forEach { it.bitmap.recycle() }
                atlas
            } else {
                val bitmap=Bitmap.createBitmap(512,2064,Bitmap.Config.ARGB_8888)
                val pixels=IntArray(512*2064) { -1 }
                val band=(spec.patternScale*512).coerceAtLeast(2f)
                for(y in 0 until 2048) for(x in 0 until 512) {
                    val a=if(spec.orientation=="horizontal") y else x
                    val on=when(spec.pattern) {
                        "stripes" -> a/band-kotlin.math.floor(a/band)<spec.patternDuty
                        "checks" -> ((x/band).toInt()+(y/band).toInt())%2==1
                        else -> false
                    }
                    val color=if(on)spec.accentColor else spec.baseColor
                    val yarn=when(spec.weave) {
                        "knit" -> if((x/3+(y/6)%2)%2==(y/3)%2) .97f else 1f
                        "denim" -> if((x+y)%6<2) .96f else 1f
                        else -> if((x/2+y/2)%2==0) .985f else 1f
                    }
                    fun channel(shift:Int)=(((color ushr shift) and 255)*yarn).toInt()
                    pixels[(y+16)*512+x]=(255 shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
                }
                bitmap.setPixels(pixels,0,512,0,0,512,2064);bitmap
            }
            return GarmentRenderAsset(null,texture,emptyList(),GarmentModel(spec))
        }

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
                val pieces = listOf(GarmentPiece(masked, 0f, 0f, 1/sx, 1/sy, spec.outer, null))
                return GarmentRenderAsset(spec, masked, pieces)
            } finally { source.recycle() }
        }
    }
}
