import assert from 'node:assert/strict';
import {segment, traceMask, validateMetadata, project, sampleMetadata, validBody} from '../geometry.mjs';
export function runTests() {
  let n=0;
  function test(name, fn) { fn(); n++; }
  test('opaque background removed without cropping source coordinates',()=>{
    const rgba=new Uint8ClampedArray(20*20*4).fill(255);
    for(let y=4;y<16;y++)for(let x=5;x<15;x++){let i=(y*20+x)*4;rgba[i]=20;rgba[i+1]=50;rgba[i+2]=90;}
    const {mask}=segment(rgba,20,20,40);
    assert.equal(mask[0],0);assert.equal(mask[10*20+10],1);
    const loops=traceMask(mask,20,20);assert(loops[0].length>=4);
    assert(loops.flat().every(([x,y])=>x>=0&&x<=20&&y>=0&&y<=20));
  });
  test('transparent input preserves internal holes',()=>{
    const rgba=new Uint8ClampedArray(20*20*4);
    for(let y=3;y<17;y++)for(let x=3;x<17;x++)rgba[(y*20+x)*4+3]=255;
    for(let y=7;y<11;y++)for(let x=7;x<11;x++)rgba[(y*20+x)*4+3]=0;
    const {mask,method}=segment(rgba,20,20,30);
    assert.equal(method,'alpha');assert.equal(mask[8*20+8],0);
    assert.equal(traceMask(mask,20,20).length,2);
  });
  test('reject invalid polygons and dimensions',()=>{
    const m=sampleMetadata();assert.equal(validateMetadata(m).width,600);
    assert.throws(()=>validateMetadata({...m,source:{...m.source,width_px:0}}));
    const bad=structuredClone(m);bad.segmentation.outer_contour_px[0]=[Infinity,0];
    assert.throws(()=>validateMetadata(bad));
  });
  test('collapsed and reversed target anchors cannot enter the renderer',()=>{
    const bad={left:[0,0],right:[100,500],hem:[160,800]};
    assert.equal(validBody(bad),false);
    assert.equal(validBody({left:[300,200],right:[100,200],hem:[200,400]}),false);
    assert.equal(validBody({left:[100,200],right:[300,200],hem:[200,400]}),true);
  });
  test('anchors align and every projected vertex remains finite',()=>{
    const spec=validateMetadata(sampleMetadata());
    const body={left:[260,230],right:[440,230],hem:[350,450],elbowLeft:[215,335],elbowRight:[485,335],wristLeft:[175,435],wristRight:[525,435]};
    const mesh=project(spec,body);
    assert(mesh.vertices.every(p=>p.every(Number.isFinite)));
    assert.equal(mesh.vertices.length,49*65);
    assert(mesh.deformationScale>=.5, `neutral sleeve articulation unexpectedly attenuated: ${mesh.deformationScale}`);
    assert(Math.abs(mesh.map(spec.left)[0]-260)<.01);
    assert(Math.abs(mesh.map(spec.right)[0]-440)<.01);
    assert(Math.abs(mesh.map(spec.hem)[1]-450)<.01);
  });
  return `${n} geometry tests passed`;
}
