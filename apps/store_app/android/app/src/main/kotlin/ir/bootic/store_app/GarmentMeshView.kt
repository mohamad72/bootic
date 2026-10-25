package ir.bootic.store_app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.view.View
import android.os.SystemClock
import kotlin.math.max
import kotlin.math.hypot

/** One connected, photo-textured surface on phone and projector. No closed
 * sleeve tubes, generated collar or destructive neck rectangle. */
internal class GarmentMeshView(context: Context) : View(context) {
    var asset: GarmentRenderAsset? = null
        set(value) { if(field !== value) { motion.reset();cachedAsset=null };field=value;invalidate() }
    var pose: PoseObservation? = null
        set(value) { if(value?.box==null || field?.imageWidth!=value?.imageWidth || field?.imageHeight!=value?.imageHeight)motion.reset();field=value;invalidate() }
    var mirrorTexture = false
        set(value) { if(field!=value)motion.reset();field=value;invalidate() }
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val motion=ClothMotion()
    private var cachedAsset:GarmentRenderAsset?=null
    private val columns=48
    private val rows=64
    private val sources=ArrayList<GPoint>()
    private val vertices=FloatArray((columns+1)*(rows+1)*2)
    init { isClickable=false;isFocusable=false;importantForAccessibility=IMPORTANT_FOR_ACCESSIBILITY_NO }

    override fun onDraw(canvas:Canvas) {
        super.onDraw(canvas)
        val asset=asset ?: return
        val pose=pose ?: return
        val spec=asset.spec ?: return
        if(pose.box==null || width<=0 || height<=0)return
        if(cachedAsset !== asset) {
            cachedAsset=asset;sources.clear()
            for(y in 0..rows)for(x in 0..columns)
                sources.add(GPoint(spec.width*x/columns,spec.height*y/rows))
        }
        val warp=GarmentWarp(spec,pose.points,pose.imageWidth,pose.imageHeight,mirrorTexture,pose.bodyEdges)
        val scale=max(width.toFloat()/pose.imageWidth,height.toFloat()/pose.imageHeight)
        val ox=(width-pose.imageWidth*scale)/2;val oy=(height-pose.imageHeight*scale)/2
        val center=warp.torso(spec.hem)
        val lag=motion.update(center,pose.shoulderPx,SystemClock.uptimeMillis()/1000.0)
        for((i,source)in sources.withIndex()) {
            val p=warp.surface(source,lag)
            vertices[i*2]=ox+p.x*scale;vertices[i*2+1]=oy+p.y*scale
        }
        canvas.save();canvas.clipRect(0,0,width,height)
        val allowed=Path().apply { addRect(0f,0f,width.toFloat(),height.toFloat(),Path.Direction.CW) }
        for(arm in PhotoOcclusion.forearms(pose.points,pose.imageWidth,pose.imageHeight)) {
            // The whole sleeve stays visible. Only bare forearm/hand is a
            // foreground occluder; for full sleeves restrict to the wrist.
            val side=if(pose.points[arm.shoulderIndex].x<=pose.points[if(arm.shoulderIndex==11)12 else 11].x)"left" else "right"
            val swap=mirrorTexture && spec.mirrorTexture
            val part=spec.sleeves.find { it.side==if(swap) {if(side=="left")"right" else "left"} else side }
            val sleeveLength=part?.let {(it.hem-it.shoulder).length * pose.shoulderPx /
                (spec.rightShoulder-spec.leftShoulder).length.coerceAtLeast(1f)} ?: 0f
            val shoulder=pose.points[arm.shoulderIndex]
            val upperLength=(arm.a-GPoint(shoulder.x*pose.imageWidth,shoulder.y*pose.imageHeight)).length
            val fullSleeve=sleeveLength>upperLength+(arm.b-arm.a).length*.45f
            val a=if(fullSleeve)arm.b else arm.a
            val ax=ox+a.x*scale;val ay=oy+a.y*scale
            val bx=ox+arm.b.x*scale;val by=oy+arm.b.y*scale
            val r=arm.radius*scale
            val dx=bx-ax;val dy=by-ay;val length=hypot(dx,dy).coerceAtLeast(1f)
            val nx=-dy/length*r;val ny=dx/length*r
            val mask=Path().apply {
                moveTo(ax+nx,ay+ny);lineTo(bx+nx,by+ny);lineTo(bx-nx,by-ny);lineTo(ax-nx,ay-ny);close()
                addCircle(ax,ay,r,Path.Direction.CW);addCircle(bx,by,r,Path.Direction.CW)
            }
            allowed.op(mask,Path.Op.DIFFERENCE)
        }
        canvas.clipPath(allowed)
        canvas.drawBitmapMesh(asset.masked,columns,rows,vertices,0,null,0,paint)
        canvas.restore()
        if(lag.length>.005f)postInvalidateOnAnimation()
    }
}
