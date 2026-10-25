package ir.bootic.store_app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.view.View
import kotlin.math.max
import kotlin.math.hypot

/** One connected, photo-textured surface on phone and projector. No closed
 * sleeve tubes, generated collar or destructive neck rectangle. */
internal class GarmentMeshView(context: Context) : View(context) {
    var asset: GarmentRenderAsset? = null
        set(value) { field=value;invalidate() }
    var pose: PoseObservation? = null
        set(value) { field=value;invalidate() }
    var mirrorTexture = false
        set(value) { field=value;invalidate() }
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    val deformationScale:Float get()=asset?.photoMesh?.deformationScale ?: 1f
    private var vertices=FloatArray(0)
    init { isClickable=false;isFocusable=false;importantForAccessibility=IMPORTANT_FOR_ACCESSIBILITY_NO }

    override fun onDraw(canvas:Canvas) {
        super.onDraw(canvas)
        val asset=asset ?: return
        val pose=pose ?: return
        val spec=asset.spec ?: return
        if(pose.box==null || width<=0 || height<=0)return
        val mesh=asset.photoMesh ?: return
        val warp=GarmentWarp(spec,pose.points,pose.imageWidth,pose.imageHeight,mirrorTexture,pose.bodyEdges,mesh.surface)
        val scale=max(width.toFloat()/pose.imageWidth,height.toFloat()/pose.imageHeight)
        val ox=(width-pose.imageWidth*scale)/2;val oy=(height-pose.imageHeight*scale)/2
        val projected=mesh.project(warp,pose,mirrorTexture)
        if(vertices.size!=projected.size)vertices=FloatArray(projected.size)
        for(i in mesh.samples.indices) {
            vertices[i*2]=ox+projected[i*2]*scale;vertices[i*2+1]=oy+projected[i*2+1]*scale
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
        canvas.drawBitmapMesh(asset.masked,mesh.columns,mesh.rows,vertices,0,null,0,paint)
        canvas.restore()
    }
}
