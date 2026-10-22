package ir.bootic.store_app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.view.View
import kotlin.math.max

/** Same mesh renderer on the phone and external customer display. */
internal class GarmentMeshView(context: Context) : View(context) {
    var asset: GarmentRenderAsset? = null
        set(value) { field = value; invalidate() }
    var pose: PoseObservation? = null
        set(value) { field = value; invalidate() }
    var mirrorTexture = false
        set(value) { field = value; invalidate() }
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    init { isClickable = false; isFocusable = false; importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val asset = asset ?: return
        val pose = pose ?: return
        if (pose.box == null || width <= 0 || height <= 0) return
        val warp = GarmentWarp(asset.spec, pose.points, pose.imageWidth, pose.imageHeight, mirrorTexture)
        val scale = max(width.toFloat()/pose.imageWidth, height.toFloat()/pose.imageHeight)
        val offsetX = (width-pose.imageWidth*scale)/2
        val offsetY = (height-pose.imageHeight*scale)/2
        canvas.save(); canvas.clipRect(0,0,width,height)
        for (piece in asset.pieces) {
            val columns = if (piece.sleeve == null) 8 else 4
            val rows = if (piece.sleeve == null) 12 else 6
            val vertices = FloatArray((columns+1)*(rows+1)*2)
            var index = 0
            for (y in 0..rows) for (x in 0..columns) {
                val source = GPoint(
                    (piece.left + piece.bitmap.width*x.toFloat()/columns)*piece.sourceScaleX,
                    (piece.top + piece.bitmap.height*y.toFloat()/rows)*piece.sourceScaleY,
                )
                val target = if (piece.sleeve == null) warp.torso(source) else warp.sleeve(source, piece.sleeve)
                vertices[index++] = offsetX + target.x*scale
                vertices[index++] = offsetY + target.y*scale
            }
            canvas.drawBitmapMesh(piece.bitmap, columns, rows, vertices, 0, null, 0, paint)
        }
        canvas.restore()
    }
}
