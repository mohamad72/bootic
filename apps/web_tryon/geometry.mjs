import {ANCHORS, applyNeck, enrichMetadata} from './anchors.mjs';
// Browser-independent geometry. Source coordinates are never trimmed.
export const add=(a,b)=>[a[0]+b[0],a[1]+b[1]];
export const sub=(a,b)=>[a[0]-b[0],a[1]-b[1]];
export const mul=(p,k)=>[p[0]*k,p[1]*k];
const cross=(a,b)=>a[0]*b[1]-a[1]*b[0];
const len=p=>Math.hypot(...p);
const clamp=(x,a=0,b=1)=>Math.min(b,Math.max(a,x));
const smooth=x=>{const t=clamp(x);return t*t*(3-2*t);};
export function contains(p,poly){let hit=false,a=poly.at(-1);for(const b of poly){if((a[1]>p[1])!==(b[1]>p[1])&&p[0]<(b[0]-a[0])*(p[1]-a[1])/(b[1]-a[1])+a[0])hit=!hit;a=b;}return hit;}
export function segment(rgba,w,h,threshold=45){
  const size=w*h,mask=new Uint8Array(size);let transparent=0;
  for(let i=0;i<size;i++)if(rgba[i*4+3]<128)transparent++;
  if(transparent>size*.01){for(let i=0;i<size;i++)mask[i]=rgba[i*4+3]>=128?1:0;}
  else {
    const borders=[];for(let x=0;x<w;x++){borders.push(x,(h-1)*w+x);}for(let y=0;y<h;y++){borders.push(y*w,y*w+w-1);}
    const bg=[0,1,2].map(c=>{const v=borders.map(i=>rgba[i*4+c]).sort((a,b)=>a-b);return v[v.length>>1];});
    const seen=new Uint8Array(size),queue=new Int32Array(size);let head=0,tail=0;
    const visit=i=>{if(seen[i])return;seen[i]=1;const j=i*4;if(Math.hypot(rgba[j]-bg[0],rgba[j+1]-bg[1],rgba[j+2]-bg[2])<=threshold){queue[tail++]=i;}};
    borders.forEach(visit);
    while(head<tail){const i=queue[head++],x=i%w,y=(i/w)|0;if(x)visit(i-1);if(x<w-1)visit(i+1);if(y)visit(i-w);if(y<h-1)visit(i+w);}
    mask.fill(1);for(let i=0;i<tail;i++)mask[queue[i]]=0;
  }
  // Only retain the largest garment; discarded speckles cannot become anchors.
  const seen=new Uint8Array(size),q=new Int32Array(size);let largest=[];
  for(let start=0;start<size;start++){if(!mask[start]||seen[start])continue;let head=0,tail=1;q[0]=start;seen[start]=1;
    while(head<tail){const i=q[head++],x=i%w,y=(i/w)|0;for(const j of [x?i-1:-1,x<w-1?i+1:-1,y?i-w:-1,y<h-1?i+w:-1])if(j>=0&&mask[j]&&!seen[j]){seen[j]=1;q[tail++]=j;}}
    if(tail>largest.length)largest=Array.from(q.subarray(0,tail));
  }
  mask.fill(0);for(const i of largest)mask[i]=1;
  if(largest.length<size*.015||largest.length>size*.98)throw Error('مرز مطمئنی پیدا نشد؛ زمینهٔ ساده یا PNG شفاف انتخاب کنید، یا JSON مرز را وارد کنید.');
  return {mask,method:transparent>size*.01?'alpha':'background',coverage:largest.length/size};
}
export function traceMask(mask,w,h){
  const edges=new Map(),key=(x,y)=>y*(w+1)+x;
  const edge=(a,b)=>{const k=key(...a);if(!edges.has(k))edges.set(k,[]);edges.get(k).push(b);};
  const on=(x,y)=>x>=0&&y>=0&&x<w&&y<h&&mask[y*w+x];
  for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(on(x,y)){
    if(!on(x,y-1))edge([x,y],[x+1,y]);if(!on(x+1,y))edge([x+1,y],[x+1,y+1]);
    if(!on(x,y+1))edge([x+1,y+1],[x,y+1]);if(!on(x-1,y))edge([x,y+1],[x,y]);
  }
  const loops=[];while(edges.size){const start=edges.keys().next().value;let k=start,pts=[],guard=0;
    do{pts.push([k%(w+1),Math.floor(k/(w+1))]);const options=edges.get(k);if(!options)break;const b=options.pop();if(!options.length)edges.delete(k);k=key(...b);}while(k!==start&&++guard<4*w*h);
    if(pts.length>=4)loops.push(pts.filter((p,i)=>{const a=pts[(i+pts.length-1)%pts.length],b=pts[(i+1)%pts.length];return cross(sub(p,a),sub(b,p))!==0;}));
  }
  const area=poly=>Math.abs(poly.reduce((s,p,i)=>s+cross(p,poly[(i+1)%poly.length]),0));
  return loops.filter(p=>p.length>=3).sort((a,b)=>area(b)-area(a));
}
export function validateMetadata(m){
  if(m?.schema_version!=='bootic.garment-metadata/0.1')throw Error('نسخهٔ JSON باید bootic.garment-metadata/0.1 باشد.');
  m=applyNeck(structuredClone(m));
  const width=m.source?.width_px,height=m.source?.height_px;
  if(![width,height].every(n=>Number.isFinite(n)&&n>=64&&n<=6000))throw Error('ابعاد JSON باید بین ۶۴ و ۶۰۰۰ باشد.');
  if(m.source.points_convention!=='image_left/image_right; not anatomical left/right')throw Error('قرارداد مختصات JSON سازگار نیست.');
  const point=p=>{if(!Array.isArray(p)||p.length!==2||!p.every(Number.isFinite)||p[0]<0||p[0]>width||p[1]<0||p[1]>height)throw Error('مختصات JSON خارج از عکس یا نامعتبر است.');return [...p];};
  const polygon=p=>{if(!Array.isArray(p)||p.length<3||p.length>1024)throw Error('مرز باید بین ۳ تا ۱۰۲۴ نقطه داشته باشد.');return p.map(point);};
  const l=m.landmarks_px??{},left=point(l.shoulder_image_left),right=point(l.shoulder_image_right),hem=point(l.hem_center);
  if(Math.abs(cross(sub(right,left),sub(hem,left)))<1)throw Error('سه اتصال لباس نباید هم‌خط باشند.');
  const holes=Object.values(m.segmentation?.subtract_polygons_px??{});if(holes.length>16)throw Error('تعداد حفره‌ها زیاد است.');
  const sleeves=[];for(const side of ['left','right']){const r=m.regions?.[`sleeve_image_${side}`];if(!r)continue;const cuff=r.cuff_edge_px;if(cuff&&(!Array.isArray(cuff)||cuff.length!==2))throw Error('سرآستین نامعتبر است.');sleeves.push({side,polygon:polygon(r.polygon_px),shoulder:side==='left'?left:right,armpit:point(l[`${side}_armpit`]),hem:cuff?mul(add(point(cuff[0]),point(cuff[1])),.5):point(l[`${side}_sleeve_hem_center`])});}
  const landmarks={};for(const a of ANCHORS)if(a.source&&l[a.source]!==undefined)landmarks[a.source]=point(l[a.source]);
  return {width,height,outer:polygon(m.segmentation?.outer_contour_px),holes:holes.map(polygon),left,right,hem,sleeves,landmarks};
}
export function sampleMetadata(){return applyNeck(enrichMetadata({
  schema_version:'bootic.garment-metadata/0.1',
  source:{width_px:600,height_px:700,points_convention:'image_left/image_right; not anatomical left/right'},
  segmentation:{outer_contour_px:[[185,100],[240,85],[360,85],[415,100],[570,210],[490,320],[420,275],[420,620],[180,620],[180,275],[110,320],[30,210]],subtract_polygons_px:{neck:[[240,85],[300,120],[360,85],[340,150],[260,150]]}},
  landmarks_px:{shoulder_image_left:[185,100],shoulder_image_right:[415,100],hem_center:[300,620],left_armpit:[180,275],right_armpit:[420,275],left_sleeve_hem_center:[70,265],right_sleeve_hem_center:[530,265],left_sleeve_start:[168,125],right_sleeve_start:[432,125],left_hem:[180,620],right_hem:[420,620],neck_image_left:[240,85],neck_image_right:[360,85],front_collar_bottom:[300,155]},
  regions:{sleeve_image_left:{polygon_px:[[185,100],[180,275],[110,320],[30,210]]},sleeve_image_right:{polygon_px:[[415,100],[570,210],[490,320],[420,275]]}},
web_lab:{neckline:'parabola',inferred_points:[]},
}));}
// Anchored torso and blended articulated sleeves. This is a web diagnostic
// implementation, NOT the full Kotlin PhotoSurface roll/body-edge fitting path.
function polygonDistance(p,poly){let min=Infinity,a=poly.at(-1);for(const b of poly){const d=sub(b,a),q=sub(p,a),t=clamp((q[0]*d[0]+q[1]*d[1])/Math.max(.0001,d[0]**2+d[1]**2));min=Math.min(min,len(sub(p,add(a,mul(d,t)))));a=b;}return min;}
export function validBody(body){
  if(!body||!['left','right','hem'].every(k=>Array.isArray(body[k])&&body[k].length===2&&body[k].every(Number.isFinite)))return false;
  const across=sub(body.right,body.left),down=sub(body.hem,body.left);
  return body.right[0]-body.left[0]>20&&cross(across,down)>Math.max(100,len(across)**2*.02);
}
export function project(spec,body,columns=48,rows=64){
  if(!validBody(body))throw Error('اتصال‌های بدن هم‌خط یا وارونه هستند.');
  const mid=mul(add(spec.left,spec.right),.5),across=sub(spec.right,spec.left),down=sub(spec.hem,mid),det=cross(across,down);
  const targetMid=mul(add(body.left,body.right),.5),targetAcross=sub(body.right,body.left),targetDown=sub(body.hem,targetMid);
  const local=p=>{const q=sub(p,mid);return [cross(q,down)/det,cross(across,q)/det];};
  const torso=p=>{let [u,v]=local(p);if(v<0)v=.08*v/(.08-v);return add(add(targetMid,mul(targetAcross,u)),mul(targetDown,v));};
  const raw=p=>{const base=torso(p);let result=[...base],total=0;const deltas=[];
    for(const s of spec.sleeves){const regionWeight=contains(p,s.polygon)?1:1-smooth(polygonDistance(p,s.polygon)/Math.max(1,len(across)*.25));if(regionWeight===0)continue;
      const seam=sub(s.armpit,s.shoulder),arm=sub(s.hem,s.shoulder),d=cross(seam,arm);if(Math.abs(d)<1)continue;
      const weight=regionWeight*smooth(cross(seam,sub(p,s.shoulder))/d),start=body[s.side==='left'?'sleeveStartLeft':'sleeveStartRight']??body[s.side],elbow=body[s.side==='left'?'elbowLeft':'elbowRight'],wrist=body[s.side==='left'?'wristLeft':'wristRight'];
      const a=sub(elbow,start),f=sub(wrist,elbow),scale=len(targetAcross)/Math.max(1,len(across)),length=Math.min(len(arm)*scale,len(a)+len(f));
      const q=sub(p,s.shoulder),u=(arm[0]*q[0]+arm[1]*q[1])/(len(arm)**2),v=cross(arm,q)/(len(arm)**2),distance=Math.max(0,u*length),axis=mul(distance<=len(a)?a:f,1/Math.max(1,len(distance<=len(a)?a:f)));
      const center=distance<=len(a)?add(start,mul(axis,distance)):add(elbow,mul(axis,distance-len(a)));
      const cuff=body[s.side==='left'?'cuffLeft':'cuffRight'];
      const cuffCenter=cuff?add(start,mul(sub(cuff,start),u)):center;
      const cuffAxis=cuff?mul(sub(cuff,start),1/Math.max(1,len(sub(cuff,start)))):axis;
      const mapped=add(cuffCenter,mul([-cuffAxis[1],cuffAxis[0]],v*len(arm)*scale));deltas.push([sub(mapped,base),weight]);total+=weight;
    }
    for(const [d,w] of deltas)result=add(result,mul(d,w/Math.max(1,total)));return result;
  };
  // Compact inverse-distance residual field: extra collar/hem/underarm anchors
  // affect local fitting, rather than being decorative dots. The safety guard
  // below can attenuate an impossible placement; diagnostics show the residual.
  const controls=[];
  for(const a of ANCHORS){
    const source=a.source&&spec.landmarks?.[a.source],target=body[a.key];
    if(source&&target)controls.push({source,delta:sub(target,raw(source))});
  }
  const adjusted=p=>{
    const base=raw(p);if(!controls.length)return base;
    let total=1/Math.max(1,len(across)*.25)**4,delta=[0,0];
    for(const c of controls){const d2=len(sub(p,c.source))**2;
      const w=Math.exp(-d2/Math.max(1,len(across)*.65)**2)/(d2+1)**2;
      delta=add(delta,mul(c.delta,w));total+=w;
    }
    return add(base,mul(delta,1/total));
  };
  const sources=[],vertices=[],reference=[],triangles=[];
  for(let y=0;y<=rows;y++)for(let x=0;x<=columns;x++){const p=[spec.width*x/columns,spec.height*y/rows];sources.push(p);vertices.push(adjusted(p));reference.push(torso(p));}
  const visible=p=>contains(p,spec.outer)&&!spec.holes.some(h=>contains(p,h));
  function include(ids){const center=mul(ids.reduce((p,i)=>add(p,sources[i]),[0,0]),1/3);if(ids.some(i=>visible(sources[i]))||visible(center))triangles.push(ids);}
  for(let y=0;y<rows;y++)for(let x=0;x<columns;x++){const a=y*(columns+1)+x,b=a+1,c=a+columns+1,d=c+1;include([a,b,c]);include([b,d,c]);}
  const mix=(a,b,t)=>add(a,mul(sub(b,a),t));
  const safe=t=>triangles.every(([a,b,c])=>{const orig=cross(sub(reference[b],reference[a]),sub(reference[c],reference[a]));const pa=mix(reference[a],vertices[a],t),pb=mix(reference[b],vertices[b],t),pc=mix(reference[c],vertices[c],t);return cross(sub(pb,pa),sub(pc,pa))*orig>orig*orig*.025;});
  let amount=1;while(amount>.015625&&!safe(amount))amount*=.5;if(!safe(amount))amount=0;
  const final=vertices.map((p,i)=>mix(reference[i],p,amount));
  const map=p=>{const x=clamp(p[0]/spec.width,0,1)*columns,y=clamp(p[1]/spec.height,0,1)*rows,ix=Math.min(Math.floor(x),columns-1),iy=Math.min(Math.floor(y),rows-1),u=x-ix,v=y-iy,a=iy*(columns+1)+ix,b=a+1,c=a+columns+1,d=c+1;return u+v<=1?add(add(mul(final[a],1-u-v),mul(final[b],u)),mul(final[c],v)):add(add(mul(final[d],u+v-1),mul(final[c],1-u)),mul(final[b],1-v));};
  return {sources,vertices:final,triangles,map,deformationScale:amount};
}
