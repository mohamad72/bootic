package ir.bootic.store_app
import org.junit.Assert.*
import org.junit.Test
import kotlin.math.*
class GarmentModelTest {
 private fun spec(kind:String="top")=GarmentModelSpec(kind,1f,1f,.06f,.35f,.2f,.14f,"round","procedural",-1,0xff202638.toInt(),"stripes",.025f,"horizontal",.85f)
 private fun pose(scale:Float=1f,depth:Float=0f,mirrored:Boolean=false):PoseObservation {
  val points=MutableList(33){PosePoint(.5f,.1f,1f,1f)}
  fun point(i:Int,x:Float,y:Float,z:Float=0f) {
   val px=.5f+(x-.5f)*scale
   points[i]=PosePoint(if(mirrored)1-px else px,.4f+(y-.4f)*scale,1f,1f,z*scale)
  }
  point(11,.65f,.3f,depth);point(12,.35f,.3f,-depth);point(23,.60f,.6f,depth*.7f);point(24,.40f,.6f,-depth*.7f)
  point(13,.72f,.45f,depth);point(14,.28f,.45f,-depth);point(15,.76f,.60f,depth);point(16,.24f,.60f,-depth)
  point(25,.60f,.76f);point(26,.40f,.76f);point(27,.60f,.92f);point(28,.40f,.92f)
  return PoseGeometry.evaluate(points,800,1000)
 }
 @Test fun topologyPreparedOnce() {
  val m=GarmentModel(spec());val p=pose();val frame=m.frame(p,false)!!
  assertTrue(m.vertices.size>500);assertTrue(m.faces.size<2000);assertSame(frame,m.frame(p,false))
  assertTrue(frame.positions.maxOf{it.z}-frame.positions.minOf{it.z}>50)
  assertTrue(m.faces.all{it.a in m.vertices.indices && it.b in m.vertices.indices && it.c in m.vertices.indices})
 }
 @Test fun distanceChangesScaleNotShape() {
  val m=GarmentModel(spec());val near=m.frame(pose(),false)!!;val far=m.frame(pose(.4f),false)!!
  fun span(f:ModelFrame)=f.positions.maxOf{it.x}-f.positions.minOf{it.x}
  assertEquals(.4f,span(far)/span(near),.002f)
 }
 @Test fun mirroredCameraSymmetric() {
  val m=GarmentModel(spec());val a=m.frame(pose(),false)!!;val b=m.frame(pose(mirrored=true),true)!!
  assertEquals(800-a.positions.minOf{it.x},b.positions.maxOf{it.x},.01f);assertEquals(a.positions.maxOf{it.y},b.positions.maxOf{it.y},.01f)
 }
 @Test fun turnUsesDepthAndSortsFaces() {
  val m=GarmentModel(spec());val a=m.frame(pose(depth=.12f),false)!!
  val z=a.faces.map{(a.positions[it.a].z+a.positions[it.b].z+a.positions[it.c].z)/3}
  assertTrue(z.zipWithNext().all{it.first>=it.second});assertTrue(a.positions.all{it.x.isFinite()&&it.y.isFinite()&&it.z.isFinite()})
 }
 @Test fun sleevesFollowArm() {
  val m=GarmentModel(spec());val p=pose();val original=m.frame(p,false)!!
  val changed=p.points.toMutableList();changed[13]=changed[13].copy(y=.2f);changed[15]=changed[15].copy(y=.1f)
  val raised=m.frame(p.copy(points=changed),false)!!
  val tips=m.vertices.indices.filter{m.vertices[it].part==2 && m.vertices[it].position.y==1f}
  assertTrue(tips.isNotEmpty());assertTrue(tips.map{raised.positions[it].y}.average()<tips.map{original.positions[it].y}.average())
 }
 @Test fun allKindsAndScalesFinite() {
  for(k in listOf("top","coat","dress","skirt","trousers"))for(s in listOf(.35f,.7f,1f)) {
   val frame=GarmentModel(spec(k)).frame(pose(s,.08f),false)!!
   assertTrue(frame.positions.all{it.x.isFinite()&&it.y.isFinite()&&it.z.isFinite()})
  }
 }
 @Test fun noPoseNoGarment(){assertNull(GarmentModel(spec()).frame(pose().copy(box=null),false))}
 @Test fun missingAnkleNoInventedTrousers() {
  val p=pose();val points=p.points.toMutableList();points[27]=points[27].copy(visibility=0f)
  assertNull(GarmentModel(spec("trousers")).frame(p.copy(points=points),false))
 }
 @Test fun sleevelessAndOpenCollar() {
  val m=GarmentModel(spec().copy(sleeveLength=0f));assertTrue(m.vertices.all{it.part==0});assertTrue(m.faces.any{it.collar})
  assertTrue(m.vertices.take(33).all{abs(it.position.x)<=.201f})
 }
 @Test fun chestDoesNotBridgeAcrossNeckOpening() {
  val m=GarmentModel(spec())
  assertTrue(m.vertices[66].position.y>=m.vertices[0].position.y)
 }
 @Test fun nativeContractIncludesNarrowStripesAndWeave() {
  val map=mapOf("schema_version" to "bootic.garment-model/1","kind" to "top",
   "shape" to mapOf("length" to 1.0,"hem_width" to 1.0,"ease" to .06,"sleeve_length" to .35,"neck_width" to .2,"neck_depth" to .14,"neckline" to "round"),
   "material" to mapOf("mode" to "procedural","base_color" to "#EEE9DF","accent_color" to "#202638","pattern" to "stripes","pattern_scale" to .05,"pattern_duty" to .25,"orientation" to "horizontal","roughness" to .85,"weave" to "knit"))
  val parsed=GarmentModelSpec.fromMap(map)
  assertEquals(.25f,parsed.patternDuty,.0001f);assertEquals("knit",parsed.weave)
  val bad=map.toMutableMap();bad["material"]=(map["material"] as Map<*,*>).toMutableMap().apply {this["pattern_duty"]=0.0}
  assertThrows(IllegalArgumentException::class.java){GarmentModelSpec.fromMap(bad)}
 }
}
