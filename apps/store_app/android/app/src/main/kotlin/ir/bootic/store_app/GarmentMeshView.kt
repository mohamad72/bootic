package ir.bootic.store_app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.BitmapShader
import android.graphics.Shader
import android.graphics.Path
import kotlin.math.abs
import kotlin.math.pow
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

    private var textureAsset: GarmentRenderAsset? = null
    private var textureShader: BitmapShader? = null
    private val modelPaint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private fun drawModel(canvas: Canvas, asset: GarmentRenderAsset, pose: PoseObservation) {
        val model=requireNotNull(asset.model)
        val frame=model.frame(pose,mirrorTexture) ?: return
        if(textureAsset !== asset) {
            textureAsset=asset
            textureShader=BitmapShader(asset.masked,Shader.TileMode.CLAMP,Shader.TileMode.CLAMP)
        }
        modelPaint.shader=textureShader
        val scale=max(width.toFloat()/pose.imageWidth,height.toFloat()/pose.imageHeight)
        val ox=(width-pose.imageWidth*scale)/2;val oy=(height-pose.imageHeight*scale)/2
        val xy=FloatArray(frame.faces.size*6);val uv=FloatArray(xy.size);val colors=IntArray(frame.faces.size*3)
        val light=V3(-.25f,-.4f,-1f).unit()
        var index=0
        for(face in frame.faces) {
            val a=frame.positions[face.a];val b=frame.positions[face.b];val c=frame.positions[face.c]
            val normal=(b-a).cross(c-a).unit()
            val diffuse=abs(normal.dot(light))
            val intensity=(.62f+.34f*diffuse+.04f*(1-model.spec.roughness)*diffuse.pow(12)).coerceIn(0f,1f)
            val base=if(face.collar)model.spec.accentColor else -1
            fun channel(shift:Int)=(((base ushr shift) and 255)*intensity).toInt().coerceIn(0,255)
            val color=(255 shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
            for(i in intArrayOf(face.a,face.b,face.c)) {
                val p=frame.positions[i];val v=model.vertices[i]
                xy[index*2]=ox+p.x*scale;xy[index*2+1]=oy+p.y*scale
                val u=if(mirrorTexture && model.spec.mode=="source")1-v.u else v.u
                uv[index*2]=if(face.collar)2f else u.coerceIn(0f,1f)*511
                val ratio=frame.torsoLength/frame.width.coerceAtLeast(1f)
                val proceduralV=when(v.part) {
                    0 -> v.position.y*(if(model.spec.kind=="skirt")frame.legLength*model.spec.length/frame.width else ratio)
                    1,2 -> v.position.y*model.spec.sleeveLength*frame.armLengths[v.part-1]/frame.width
                    else -> v.position.y*model.spec.length*frame.legLength/frame.width
                }
                val textureCell=if(v.part in 1..2) { if(mirrorTexture)3-v.part else v.part } else 0
                uv[index*2+1]=if(face.collar)2f else if(model.spec.mode=="source")16+textureCell*512+(if(v.part in 1..2)v.position.y else v.v).coerceIn(0f,1f)*511 else 16+(proceduralV*512).coerceIn(0f,2047f)
                colors[index++]=color
            }
        }
        canvas.save()
        canvas.clipRect(0,0,width,height)
        // A conservative foreground cutout: only confident arms measurably closer
        // than the chest. Does not erase hands merely because they overlap in 2D.
        val allowed=Path().apply { addRect(0f,0f,width.toFloat(),height.toFloat(),Path.Direction.CW) }
        // Protect the observed head and a conservative neck core. In particular,
        // the model's rear collar must pass behind the real neck, not across it.
        val head=pose.points.take(11).filter { it.finite && it.visibility>=.5f && it.presence>=.5f }
        if(head.size>=5 && model.spec.kind !in listOf("skirt","trousers")) {
            val padding=pose.shoulderPx*scale*.06f
            val l=ox+head.minOf { it.x }*pose.imageWidth*scale-padding
            val r=ox+head.maxOf { it.x }*pose.imageWidth*scale+padding
            val top=oy+head.minOf { it.y }*pose.imageHeight*scale-pose.torsoPx*scale*.2f
            val bottom=oy+head.maxOf { it.y }*pose.imageHeight*scale+pose.torsoPx*scale*.08f
            val mask=Path().apply { addOval(android.graphics.RectF(l,top,r,bottom),Path.Direction.CW) }
            val sx=(pose.points[11].x+pose.points[12].x)/2*pose.imageWidth*scale+ox
            val sy=(pose.points[11].y+pose.points[12].y)/2*pose.imageHeight*scale+oy
            val half=pose.shoulderPx*scale*.12f
            if(bottom<sy+pose.torsoPx*scale*.07f)mask.addRect(sx-half,bottom-half,sx+half,sy+pose.torsoPx*scale*.07f,Path.Direction.CW)
            allowed.op(mask,Path.Op.DIFFERENCE)
        }
        val frontDepth=minOf(pose.points[11].z,pose.points[12].z)*pose.imageWidth-pose.shoulderPx*.12f
        for(i in intArrayOf(13,14)) {
            val a=pose.points[i];val b=pose.points[i+2]
            if(a.visibility<.5f || b.visibility<.5f || a.presence<.5f || b.presence<.5f ||
                a.z*pose.imageWidth>=frontDepth || b.z*pose.imageWidth>=frontDepth)continue
            val ax=ox+a.x*pose.imageWidth*scale;val ay=oy+a.y*pose.imageHeight*scale
            val bx=ox+b.x*pose.imageWidth*scale;val by=oy+b.y*pose.imageHeight*scale
            val radius=pose.shoulderPx*scale*.065f
            val dx=bx-ax;val dy=by-ay;val len=kotlin.math.hypot(dx,dy).coerceAtLeast(1f)
            val nx=-dy/len*radius;val ny=dx/len*radius
            val arm=Path().apply {
                moveTo(ax+nx,ay+ny);lineTo(bx+nx,by+ny);lineTo(bx-nx,by-ny);lineTo(ax-nx,ay-ny);close()
                addCircle(bx,by,radius*1.3f,Path.Direction.CW)
            }
            // For long sleeves, only the bare hand may occlude the shirt.
            if(model.spec.sleeveLength>.55f) {
                arm.reset();arm.addCircle(bx,by,radius*1.3f,Path.Direction.CW)
            }
            allowed.op(arm,Path.Op.DIFFERENCE)
        }
        canvas.clipPath(allowed)
        canvas.drawVertices(Canvas.VertexMode.TRIANGLES,xy.size,xy,0,uv,0,colors,0,null,0,0,modelPaint)
        canvas.restore()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val asset = asset ?: return
        val pose = pose ?: return
        if (pose.box == null || width <= 0 || height <= 0) return
        if (asset.model != null) { drawModel(canvas,asset,pose);return }
        val warp = GarmentWarp(requireNotNull(asset.spec), pose.points, pose.imageWidth, pose.imageHeight, mirrorTexture, pose.bodyEdges)
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
