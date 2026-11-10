import {ANCHORS, enrichMetadata, applyNeck, validNeck, buildPrompt} from './anchors.mjs';
import {segment,traceMask,validateMetadata,project,sampleMetadata,validBody} from './geometry.mjs';
const $=id=>document.getElementById(id),canvas=$('preview'),ctx=canvas.getContext('2d');
const fa=n=>Number(n).toLocaleString('fa-IR');
let tab='source',image=null,metadata=null,spec=null,masked=null,filename='لباس نمونه',busy=false,drag=null,lastMesh=null;
let selectedAnchor='left';
const initialBody={left:[358,320],right:[663,320],hem:[510,750],elbowLeft:[282,535],elbowRight:[735,535],wristLeft:[237,780],wristRight:[780,780],cuffLeft:[282,535],cuffRight:[735,535],sleeveStartLeft:[337,352],sleeveStartRight:[687,352],armpitLeft:[357,475],armpitRight:[663,475],hemLeft:[360,750],hemRight:[653,750],neckLeft:[445,270],neckRight:[583,270],neckBottom:[514,302]};
let body=structuredClone(initialBody),initialSpec=null;
const person=new Image();person.src='assets/person.png';person.onload=()=>draw();person.onerror=()=>status('عکس نمونه بارگذاری نشد؛ صفحه را از سرور محلی باز کنید.',true);
function status(message,error=false){$('status').textContent=message;$('status').classList.toggle('error',error);}
function path(context,poly,close=true){context.beginPath();poly.forEach((p,i)=>i?context.lineTo(...p):context.moveTo(...p));if(close)context.closePath();}
function line(poly,color,width=2){if(!poly.length)return;path(ctx,poly);ctx.strokeStyle=color;ctx.lineWidth=width;ctx.stroke();}
function setSpec(m){if(m?.review_required===true)throw Error('هوش مصنوعی پاسخ را نیازمند بازبینی اعلام کرده؛ نقاط نامعلوم را پیش از ورود اصلاح کن.');if(m?.schema_version==='bootic.garment-model/1')m=m.source_metadata;m=applyNeck(enrichMetadata(m));const s=validateMetadata(m);if(!image||Math.abs(image.width/s.width-1)>.005||Math.abs(image.height/s.height-1)>.005)throw Error('ابعاد JSON با عکس اصلی یکسان نیست؛ عکس متناظر را انتخاب کنید.');metadata=structuredClone(m);spec=s;initialSpec=structuredClone(m);$('parabolicNeck').checked=m.web_lab?.neckline==='parabola';makeMask();updateAnchorOptions();}
function makeMask(){masked=document.createElement('canvas');masked.width=image.width;masked.height=image.height;const c=masked.getContext('2d');c.save();c.scale(image.width/spec.width,image.height/spec.height);path(c,spec.outer);c.clip();c.scale(spec.width/image.width,spec.height/image.height);c.drawImage(image,0,0);c.restore();c.globalCompositeOperation='destination-out';c.scale(image.width/spec.width,image.height/spec.height);for(const h of spec.holes){path(c,h);c.fill();}}
function sample(){const c=document.createElement('canvas');c.width=600;c.height=700;const g=c.getContext('2d');g.fillStyle='#faf9f4';g.fillRect(0,0,600,700);const m=sampleMetadata();path(g,m.segmentation.outer_contour_px);g.fillStyle='#477665';g.fill();g.save();g.clip();for(let y=135;y<640;y+=34){g.fillStyle='#e9e6ce';g.fillRect(0,y,600,8);}g.restore();path(g,m.segmentation.subtract_polygons_px.neck);g.fillStyle='#faf9f4';g.fill();g.fillStyle='#e9e6ce';g.font='bold 20px sans-serif';g.fillText('BOOTIC',254,280);image=c;filename='لباس نمونهٔ ترسیمی';setSpec(m);$('method').textContent='لباس نمونه با مرز و یقهٔ از پیش تعریف‌شده';status('نمونه آماده است؛ بین دو نما جابه‌جا شو یا عکس لباس خودت را انتخاب کن.');draw();}
async function loadImage(file){if(!file)return;busy=true;status('در حال خواندن عکس…');try{if(file.size>20*1024*1024)throw Error('حجم عکس باید کمتر از ۲۰ مگابایت باشد.');const url=URL.createObjectURL(file);let im;try{im=await new Promise((resolve,reject)=>{const v=new Image();v.onload=()=>resolve(v);v.onerror=()=>reject(Error('عکس قابل خواندن نیست.'));v.src=url;});}finally{URL.revokeObjectURL(url);}if(im.width<64||im.height<64||im.width>6000||im.height>6000)throw Error('ابعاد عکس باید بین ۶۴ و ۶۰۰۰ پیکسل باشد.');image=im;filename=file.name;spec=null;metadata=null;masked=null;initialSpec=null;extract();}catch(e){status(e.message,true);}finally{busy=false;draw();}}
function extract(){if(!image)return;try{const scale=Math.min(1,512/Math.max(image.width,image.height)),w=Math.round(image.width*scale),h=Math.round(image.height*scale),c=document.createElement('canvas');c.width=w;c.height=h;const g=c.getContext('2d');g.drawImage(image,0,0,w,h);const result=segment(g.getImageData(0,0,w,h).data,w,h,+$('threshold').value);const loops=traceMask(result.mask,w,h);if(!loops.length)throw Error('مرز لباس پیدا نشد.');const polygons=loops.map(poly=>poly.filter((_,i)=>i%Math.max(1,Math.ceil(poly.length/1000))===0).map(([x,y])=>[x*image.width/w,y*image.height/h]));
const outer=polygons[0],xs=outer.map(p=>p[0]),ys=outer.map(p=>p[1]),l=Math.min(...xs),r=Math.max(...xs),t=Math.min(...ys),b=Math.max(...ys);
const m={schema_version:'bootic.garment-metadata/0.1',source:{width_px:image.width,height_px:image.height,points_convention:'image_left/image_right; not anatomical left/right'},segmentation:{outer_contour_px:outer,subtract_polygons_px:Object.fromEntries(polygons.slice(1,17).filter(p=>p.length>=3).map((p,i)=>[`hole_${i}`,p]))},landmarks_px:{shoulder_image_left:[l+(r-l)*.25,t+(b-t)*.12],shoulder_image_right:[l+(r-l)*.75,t+(b-t)*.12],hem_center:[(l+r)/2,b]},regions:{}};
setSpec(m);$('method').textContent=`روش: ${result.method==='alpha'?'شفافیت PNG':'حذف زمینهٔ یکدست'} · پوشش ${fa(result.coverage*100)}٪`;
status('مرز استخراج شد؛ اتصال‌های پیشنهادی را با کشیدن دایره‌ها اصلاح کن. یقه و آستینِ دقیق به JSON نیاز دارند.');draw();}catch(e){spec=null;metadata=null;masked=null;initialSpec=null;status(e.message,true);draw();}}
function triangle(texture,src,dst){const [a,b,c]=src,[u,v,w]=dst,den=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]);if(Math.abs(den)<1e-8)return;
const ax=((v[0]-u[0])*(c[1]-a[1])-(w[0]-u[0])*(b[1]-a[1]))/den,ay=((v[1]-u[1])*(c[1]-a[1])-(w[1]-u[1])*(b[1]-a[1]))/den,bx=((w[0]-u[0])*(b[0]-a[0])-(v[0]-u[0])*(c[0]-a[0]))/den,by=((w[1]-u[1])*(b[0]-a[0])-(v[1]-u[1])*(c[0]-a[0]))/den;
ctx.save();path(ctx,dst);ctx.clip();ctx.transform(ax,ay,bx,by,u[0]-ax*a[0]-bx*a[1],u[1]-ay*a[0]-by*a[1]);ctx.drawImage(texture,0,0);ctx.restore();}
function points(){
  return ANCHORS.filter(a=>tab==='fit'||(a.source&&spec?.landmarks[a.source]))
    .map(a=>[a.key,tab==='fit'?body[a.key]:spec.landmarks[a.source],fa(a.id),a.label]);
}
function updateAnchorOptions(){
  const available=points();
  if(!available.some(p=>p[0]===selectedAnchor))selectedAnchor=available[0]?.[0]??'left';
  $('anchorSelect').replaceChildren(...available.map(([key,,number,label])=>{
    const option=document.createElement('option');option.value=key;option.textContent=`${number}. ${label}`;return option;
  }));
  $('anchorSelect').value=selectedAnchor;
  updateCoordinates();
}
function updateCoordinates(){
  const p=points().find(p=>p[0]===selectedAnchor)?.[1];
  $('anchorX').value=p?Math.round(p[0]):'';$('anchorY').value=p?Math.round(p[1]):'';
  const a=ANCHORS.find(a=>a.key===selectedAnchor);
  $('anchorEvidence').textContent=tab==='fit'?'محل دستی روی عکس نمونه؛ خروجی تشخیص خودکار نیست':metadata?.web_lab?.inferred_points?.includes(a?.source)?'نقطهٔ پیشنهادی؛ هنوز تأیید نشده':'نقطهٔ نمونه / JSON یا اصلاح دستی';
}
function moveAnchor(key,q){
  if(tab==='source'){
    if(!metadata)return;
    const a=ANCHORS.find(a=>a.key===key),m=structuredClone(metadata);
    const previous=m.landmarks_px[a.source];
    m.landmarks_px[a.source]=q;
    if(key==='cuffLeft'||key==='cuffRight'){
      const region=m.regions?.[key==='cuffLeft'?'sleeve_image_left':'sleeve_image_right'];
      if(region?.cuff_edge_px)region.cuff_edge_px=region.cuff_edge_px.map(p=>p.map((v,i)=>v+q[i]-previous[i]));
    }
    m.web_lab.inferred_points=m.web_lab.inferred_points.filter(k=>k!==a.source);
    try{applyNeck(m);const next=validateMetadata(m);spec=next;metadata=m;makeMask();}
    catch(error){status(error.message,true);updateCoordinates();return;}
  }else{
    const next={...body,[key]:q};
    if(!validBody(next)||next.hem[1]<Math.max(next.left[1],next.right[1])+30||!validNeck(next.neckLeft,next.neckRight,next.neckBottom)){
      status('نقاط انتخابی باعث وارونگی تنه یا یقه می‌شوند؛ جابه‌جایی رد شد.',true);updateCoordinates();return;
    }
    body=next;
  }
  updateCoordinates();status('نقطه و هندسه به‌روز شدند.');draw();
}

function draw(){if(!image)return;const start=performance.now(),fit=tab==='fit';canvas.width=fit?1024:image.width;canvas.height=fit?1536:image.height;canvas.style.aspectRatio=`${canvas.width}/${canvas.height}`;ctx.clearRect(0,0,canvas.width,canvas.height);lastMesh=null;
if(fit){if(person.complete&&person.naturalWidth)ctx.drawImage(person,0,0,1024,1536);if(spec&&masked){lastMesh=project(spec,body);ctx.save();ctx.globalAlpha=+$('opacity').value/100;for(const ids of lastMesh.triangles)triangle(masked,ids.map(i=>lastMesh.sources[i]),ids.map(i=>lastMesh.vertices[i]));ctx.restore();if($('mesh').checked){ctx.save();ctx.globalAlpha=.35;for(const ids of lastMesh.triangles)line(ids.map(i=>lastMesh.vertices[i]),'#217678',.7);ctx.restore();}}}
else if($('original').checked||!masked)ctx.drawImage(image,0,0);else ctx.drawImage(masked,0,0);
if(spec&&$('edges').checked){const map=fit&&lastMesh?lastMesh.map:p=>p;line(spec.outer.map(map),'#31d17e',Math.max(2,canvas.width/350));for(const hole of spec.holes)line(hole.map(map),'#f257a4',Math.max(2,canvas.width/350));}
if($('edges').checked)for(const [key,p,label] of points()){const radius=canvas.width/(selectedAnchor===key?45:65);ctx.beginPath();ctx.arc(...p,radius,0,Math.PI*2);ctx.fillStyle='#ffc44b';ctx.fill();ctx.strokeStyle='#473b20';ctx.lineWidth=2;ctx.stroke();ctx.fillStyle='#2e332a';ctx.font=`bold ${canvas.width/55}px sans-serif`;ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(label,p[0],p[1]+1);}
if(fit&&lastMesh&&$('edges').checked){ctx.save();ctx.strokeStyle='#2ee3ed';ctx.lineWidth=2;ctx.setLineDash([5,4]);for(const a of ANCHORS){const source=a.source&&spec.landmarks[a.source],target=body[a.key];if(!source||!target)continue;const actual=lastMesh.map(source);ctx.beginPath();ctx.moveTo(...actual);ctx.lineTo(...target);ctx.stroke();ctx.beginPath();ctx.arc(...actual,canvas.width/110,0,Math.PI*2);ctx.stroke();}ctx.restore();}
$('dimensions').textContent=`${fa(canvas.width)} × ${fa(canvas.height)}`;$('metrics').textContent=lastMesh?`${lastMesh.triangles.length} triangles · ${Math.round(performance.now()-start)} ms · blend ${lastMesh.deformationScale}`:'';}
function chooseTab(value){tab=value;for(const [id,v] of [['tabSource','source'],['tabFit','fit']]){$(id).classList.toggle('active',v===tab);$(id).setAttribute('aria-selected',v===tab);}$('viewTitle').textContent=tab==='source'?'مرز لباس، پیش از تغییرشکل':'قرارگیری روی عکس ثابت';$('viewCaption').textContent=tab==='source'?'برش، یقه و اتصال‌ها را بررسی کن.':'عکس تولیدشده · نقاط دستی · نگاشت وب آزمایشی، متفاوت از رندر اندروید';updateAnchorOptions();draw();}
function canvasPoint(e){const rect=canvas.getBoundingClientRect();const scale=Math.min(rect.width/canvas.width,rect.height/canvas.height),ox=(rect.width-canvas.width*scale)/2,oy=(rect.height-canvas.height*scale)/2;return [(e.clientX-rect.left-ox)/scale,(e.clientY-rect.top-oy)/scale];}
canvas.addEventListener('pointerdown',e=>{
  if(!$('edges').checked)return;const q=canvasPoint(e),available=points();
  const distance=row=>Math.hypot(row[1][0]-q[0],row[1][1]-q[1]);
  const active=available.find(row=>row[0]===selectedAnchor);
  const hit=active&&distance(active)<canvas.width/45?active:available.sort((a,b)=>distance(a)-distance(b)).find(row=>distance(row)<canvas.width/35);
  if(hit){drag=hit[0];selectedAnchor=drag;$('anchorSelect').value=drag;updateCoordinates();canvas.setPointerCapture(e.pointerId);draw();}
});
canvas.addEventListener('pointermove',e=>{if(!drag)return;const q=canvasPoint(e).map((v,i)=>Math.max(0,Math.min(v,i?canvas.height:canvas.width)));moveAnchor(drag,q);});
for(const event of ['pointerup','pointercancel','lostpointercapture'])canvas.addEventListener(event,()=>drag=null);
$('garmentFile').onchange=e=>loadImage(e.target.files[0]);$('sample').onclick=sample;$('extract').onclick=extract;
$('jsonFile').onchange=async e=>{try{const f=e.target.files[0];if(!f)return;if(f.size>1024*1024)throw Error('حجم JSON بیش از یک مگابایت است.');setSpec(JSON.parse(await f.text()));$('method').textContent='روش: JSON واردشده، همان قرارداد مختصات برنامه';status('مرز و اتصال‌های JSON روی عکس فعلی اعمال شد.');draw();}catch(error){status(error.message,true);}};
$('tabSource').onclick=()=>chooseTab('source');$('tabFit').onclick=()=>chooseTab('fit');
for(const id of ['opacity','edges','mesh','original'])$(id).oninput=()=>{$('opacityValue').textContent=fa($('opacity').value)+'٪';draw();};$('threshold').oninput=()=>{$('thresholdValue').textContent=fa($('threshold').value);};
$('reset').onclick=()=>{body=structuredClone(initialBody);if(initialSpec){metadata=structuredClone(initialSpec);spec=validateMetadata(metadata);$('parabolicNeck').checked=metadata.web_lab?.neckline==='parabola';makeMask();}updateAnchorOptions();status('اتصال‌ها به حالت اولیه برگشتند.');draw();};
function download(blob,name){const a=document.createElement('a'),url=URL.createObjectURL(blob);a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
$('export').onclick=()=>{if(!metadata){status('ابتدا مرز معتبر لباس را آماده کن.',true);return;}download(new Blob([JSON.stringify(metadata,null,2)],{type:'application/json'}),'garment-web-metadata.json');};$('download').onclick=()=>canvas.toBlob(blob=>{if(blob)download(blob,`bootic-${tab}.png`);});
// No camera APIs or network uploads. Reset file controls so the same file can be selected again.
for(const id of ['garmentFile','jsonFile'])$(id).addEventListener('click',e=>e.target.value='');
sample();

$('anchorSelect').onchange=()=>{selectedAnchor=$('anchorSelect').value;updateCoordinates();draw();};
function applyCoordinates(){
  const q=[+$('anchorX').value,+$('anchorY').value];
  if(q.every(Number.isFinite)&&q[0]>=0&&q[1]>=0&&q[0]<=canvas.width&&q[1]<=canvas.height)moveAnchor(selectedAnchor,q);
  else {status('مختصات باید عددی و داخل عکس باشد.',true);updateCoordinates();}
}
$('applyCoordinates').onclick=applyCoordinates;
for(const id of ['anchorX','anchorY'])$(id).onkeydown=e=>{if(e.key==='Enter')applyCoordinates();};
$('parabolicNeck').onchange=()=>{
  if(!metadata)return;
  const m=structuredClone(metadata);m.web_lab.neckline=$('parabolicNeck').checked?'parabola':'polygon';
  try{setSpec(m);draw();status('نوع برش یقه به‌روز شد.');}catch(e){$('parabolicNeck').checked=metadata.web_lab.neckline==='parabola';status(e.message,true);}
};
$('promptText').value=buildPrompt();
$('copyPrompt').onclick=async()=>{
  const prompt=buildPrompt(image?.width,image?.height);$('promptText').value=prompt;
  try{await navigator.clipboard.writeText(prompt);status('پرامپت کپی شد؛ همراه عکس اصلی به هوش مصنوعی بده.');}
  catch(_){$('promptText').focus();$('promptText').select();status('متن انتخاب شد؛ با Ctrl/Cmd+C کپی کن.');}
};
