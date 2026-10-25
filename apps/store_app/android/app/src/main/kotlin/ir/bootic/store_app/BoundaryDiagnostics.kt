package ir.bootic.store_app

internal data class DiagnosticLine(val kind:String,val points:List<GPoint>,val evidence:String)

/** Internal anatomical divisions are pose estimates: a binary person mask
 * cannot detect a neck/torso or arm/torso semantic seam. */
internal object BoundaryDiagnostics {
    fun body(pose:PoseObservation):List<DiagnosticLine> {
        if(pose.box==null || pose.points.size<25 || pose.imageWidth<=0 || pose.imageHeight<=0)return emptyList()
        fun p(i:Int)=GPoint(pose.points[i].x*pose.imageWidth,pose.points[i].y*pose.imageHeight)
        fun reliable(i:Int)=pose.points[i].finite&&pose.points[i].visibility>=.65f&&pose.points[i].presence>=.65f
        val mid=(p(11)+p(12))*.5f;val down=(p(23)+p(24))*.5f-mid
        val across=p(12)-p(11);val span=across.length
        if(span<1f || down.length<1f)return emptyList()
        val axis=across*(1f/span)
        val lines=ArrayList<DiagnosticLine>()
        val rows=pose.bodyEdges?.sections.orEmpty().filter { it.part==0 }.sortedBy { it.fraction }
        for(i in listOf(11,12))if(reliable(i)) {
            val sign=if(i==11)-1f else 1f
            var underarm=mid+down*.24f+axis*(sign*span*.44f)
            val row=rows.minByOrNull { kotlin.math.abs(it.fraction-.25f) }
            if(row!=null && kotlin.math.abs(row.fraction-.25f)<.1f) {
                val positive=(axis.x*row.normal.x+axis.y*row.normal.y)*sign>0f
                val distance=if(positive)row.positive else row.negative
                if(distance!=null)underarm=row.center+row.normal*(distance*(if(positive)1f else -1f))
            }
            lines.add(DiagnosticLine("arm_$i",listOf(pose.bodyEdges?.shoulder(i)?:p(i),underarm),"estimated"))
        }
        if(reliable(11)&&reliable(12)) {
            val center=mid-down*.08f
            var a=center-axis*(span*.14f);var b=center+axis*(span*.14f)
            val neck=pose.bodyEdges?.sections?.find { it.part==-1 }
            val negative=neck?.negative;val positive=neck?.positive
            if(neck!=null&&negative!=null&&positive!=null&&(negative+positive) in span*.1f..span*.48f) {
                a=neck.center-neck.normal*negative;b=neck.center+neck.normal*positive
            }
            lines.add(DiagnosticLine("neck",listOf(a,b),"estimated"))
        }
        if(reliable(23)&&reliable(24)) {
            val row=rows.find { it.fraction==1f }
            fun hip(i:Int):GPoint {
                if(row==null)return p(i)
                val d=p(i)-row.center
                val positive=d.x*row.normal.x+d.y*row.normal.y>0f
                val distance=(if(positive)row.positive else row.negative)?:return p(i)
                return row.center+row.normal*(distance*(if(positive)1f else -1f))
            }
            lines.add(DiagnosticLine("hips",listOf(hip(23),hip(24)),"estimated"))
        }
        for((part,sections) in pose.bodyEdges?.sections.orEmpty().groupBy { it.part })for(positive in listOf(false,true)) {
            var run=ArrayList<GPoint>()
            fun flush() {
                if(run.size>=2)lines.add(DiagnosticLine("observed_${part}_${if(positive)1 else -1}",run,"mask"))
                run=ArrayList()
            }
            for(row in sections.sortedBy { it.fraction }) {
                val distance=if(positive)row.positive else row.negative
                if(distance==null)flush() else run.add(row.center+row.normal*(distance*(if(positive)1f else -1f)))
            }
            flush()
        }
        return lines
    }
    fun garment(spec:GarmentRenderSpec,mesh:PhotoMesh,warp:GarmentWarp,frameKey:Any?=null,mirror:Boolean=false):List<DiagnosticLine> {
        val projected=mesh.project(warp,frameKey,mirror)
        val guides=mesh.surface.rollGuides.toMutableList()
        guides.add(SurfaceGuide("garment_outline",spec.outer+spec.outer.first()))
        for(hole in spec.holes)if(hole.any { mesh.surface.torsoLocal(it).y<.3f })
            guides.add(SurfaceGuide("neckline",hole+hole.first()))
        return guides.map { line -> DiagnosticLine(line.kind,line.points.map { mesh.projectedPoint(it,projected) },"rendered") }
    }
}
