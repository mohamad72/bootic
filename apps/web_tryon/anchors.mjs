// Numbering is shared between the garment and the fixed-person fixture.
// Left/right always means IMAGE side, never anatomical left/right.
export const ANCHORS = [
  {id:1, key:'left', source:'shoulder_image_left', label:'گوشهٔ شانه چپ'},
  {id:2, key:'right', source:'shoulder_image_right', label:'گوشهٔ شانه راست'},
  {id:3, key:'hem', source:'hem_center', label:'وسط پایین لباس'},
  {id:4, key:'cuffLeft', source:'left_sleeve_hem_center', label:'انتهای آستین چپ'},
  {id:5, key:'cuffRight', source:'right_sleeve_hem_center', label:'انتهای آستین راست'},
  {id:6, key:'wristLeft', label:'مچ چپ؛ راهنمای بدن'},
  {id:7, key:'wristRight', label:'مچ راست؛ راهنمای بدن'},
  {id:8, key:'sleeveStartLeft', source:'left_sleeve_start', label:'بالای ابتدای آستین چپ'},
  {id:9, key:'sleeveStartRight', source:'right_sleeve_start', label:'بالای ابتدای آستین راست'},
  {id:10, key:'armpitLeft', source:'left_armpit', label:'زیر بغل چپ'},
  {id:11, key:'armpitRight', source:'right_armpit', label:'زیر بغل راست'},
  {id:12, key:'hemLeft', source:'left_hem', label:'گوشهٔ پایین چپ'},
  {id:13, key:'hemRight', source:'right_hem', label:'گوشهٔ پایین راست'},
  {id:14, key:'neckLeft', source:'neck_image_left', label:'گوشهٔ یقه چپ'},
  {id:15, key:'neckRight', source:'neck_image_right', label:'گوشهٔ یقه راست'},
  {id:16, key:'neckBottom', source:'front_collar_bottom', label:'پایین‌ترین نقطهٔ یقه'},
];

// Quadratic curve through both collar ends and the depth point at t=.5.
// In the collar's own frame this is a parabolic round-neck approximation.
export function neckCurve(left, right, bottom, steps=64) {
  const control = bottom.map((v,i)=>2*v-(left[i]+right[i])/2);
  return Array.from({length:steps+1},(_,i)=>{
    const t=i/steps;
    return left.map((v,k)=>(1-t)**2*v+2*t*(1-t)*control[k]+t*t*right[k]);
  });
}

export function validNeck(left,right,bottom) {
  if(![left,right,bottom].every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)))return false;
  const ax=right[0]-left[0], ay=right[1]-left[1];
  const bx=bottom[0]-left[0], by=bottom[1]-left[1];
  const along=(ax*bx+ay*by)/(ax*ax+ay*ay);
  return ax>2 && along>.1 && along<.9 && ax*by-ay*bx>2;
}

// Older JSON remains usable. Added points are suggestions, NOT detections.
export function enrichMetadata(input) {
  const m=structuredClone(input), l=m.landmarks_px;
  if(!l||!Array.isArray(m.segmentation?.outer_contour_px))return m;
  const left=l.shoulder_image_left,right=l.shoulder_image_right,hem=l.hem_center;
  if(![left,right,hem].every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)))return m;
  const span=right[0]-left[0],top=(left[1]+right[1])/2,height=hem[1]-top;
  const defaults={
    left_sleeve_hem_center:[left[0]-span*.4,top+height*.32],
    right_sleeve_hem_center:[right[0]+span*.4,top+height*.32],
    left_armpit:[left[0],top+height*.34],right_armpit:[right[0],top+height*.34],
    left_hem:[left[0],hem[1]],right_hem:[right[0],hem[1]],
    neck_image_left:[left[0]+span*.24,top],neck_image_right:[right[0]-span*.24,top],
    front_collar_bottom:[(left[0]+right[0])/2,top+height*.13],
  };
  for(const side of ['left','right']){
    const edge=m.regions?.[`sleeve_image_${side}`]?.cuff_edge_px;
    if(Array.isArray(edge)&&edge.length===2&&edge.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite))){
      // Same authority rule as the Android metadata parser.
      l[`${side}_sleeve_hem_center`]=edge[0].map((v,i)=>(v+edge[1][i])/2);
      delete defaults[`${side}_sleeve_hem_center`];
    }
  }
  const inferred=new Set(m.web_lab?.inferred_points??[]);
  function add(key,p){if(l[key]!==undefined)return;l[key]=p.map((v,i)=>Math.max(0,Math.min(v,i?m.source.height_px:m.source.width_px)));inferred.add(key);}
  for(const [key,p] of Object.entries(defaults))add(key,p);
  for(const side of ['left','right']){
    const a=l[`shoulder_image_${side}`], b=l[`${side}_sleeve_hem_center`];
    if(Array.isArray(b))add(`${side}_sleeve_start`,a.map((v,i)=>v+.15*(b[i]-v)));
  }
  m.web_lab={...m.web_lab,inferred_points:[...inferred]};
  return m;
}

export function applyNeck(m) {
  if(m.web_lab?.neckline!=='parabola')return m;
  const l=m.landmarks_px;
  const left=l.neck_image_left,right=l.neck_image_right,bottom=l.front_collar_bottom;
  if(!validNeck(left,right,bottom))throw Error('یقه نامعتبر است؛ گوشهٔ چپ، گوشهٔ راست و عمق یقه را بررسی کن.');
  const curve=neckCurve(left,right,bottom);
  if(curve.some(p=>p[0]<0||p[0]>m.source.width_px||p[1]<0||p[1]>m.source.height_px))throw Error('منحنی یقه بیرون عکس افتاده است.');
  // Keep unrelated holes. The explicit neck opening is resampled for Android's polygon parser.
  const holes={...m.segmentation.subtract_polygons_px};
  let replace=m.web_lab.neck_hole_key;
  if(!replace||!Object.hasOwn(holes,replace)){
    replace=Object.keys(holes).find(k=>/neck|collar|یقه/i.test(k));
    if(!replace){
      // Legacy extraction uses anonymous hole_N names. Match only a hole in
      // the collar region, never delete unrelated lower/chest cutouts.
      const box=p=>[Math.min(...p.map(q=>q[0])),Math.min(...p.map(q=>q[1])),Math.max(...p.map(q=>q[0])),Math.max(...p.map(q=>q[1]))];
      const b=box(curve);let best=.15;
      for(const [key,poly] of Object.entries(holes)){
        if(!Array.isArray(poly)||poly.length<3||!poly.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)))continue;
        const a=box(poly),intersection=Math.max(0,Math.min(a[2],b[2])-Math.max(a[0],b[0]))*Math.max(0,Math.min(a[3],b[3])-Math.max(a[1],b[1]));
        const score=intersection/Math.max(1,(a[2]-a[0])*(a[3]-a[1]));
        if(score>best){best=score;replace=key;}
      }
    }
  }
  if(replace)delete holes[replace];
  m.segmentation.subtract_polygons_px={...holes,neck:curve};
  m.web_lab.neck_hole_key='neck';
  return m;
}

export function buildPrompt(width=null,height=null) {
  const schema={schema_version:'bootic.garment-metadata/0.1',
    source:{width_px:width??'ACTUAL_IMAGE_WIDTH',height_px:height??'ACTUAL_IMAGE_HEIGHT',points_convention:'image_left/image_right; not anatomical left/right'},
    segmentation:{outer_contour_px:'ordered [[x,y], ...], 3..1024 points',subtract_polygons_px:{neck:'ordered dense polygon following the actual neck opening'}},
    landmarks_px:Object.fromEntries(ANCHORS.filter(a=>a.source).map(a=>[a.source,'[x,y] or null if unobservable'])),
    regions:{sleeve_image_left:{polygon_px:'[[x,y], ...]'},sleeve_image_right:{polygon_px:'[[x,y], ...]'}},
    web_lab:{neckline:'parabola for a round neckline; polygon for other necklines',inferred_points:[]},
    review_required:false,uncertain_points:[],
  };
  return `Analyze the attached ORIGINAL garment photograph for a virtual try-on tool. Return ONLY one valid JSON object, no markdown. Do not edit or crop the photo.
Use original image pixels: origin top-left, x right, y down. Left/right ALWAYS means IMAGE-left/image-right. Read the actual image resolution; never invent it. Current canvas ${width??'?'} x ${height??'?'} is a hint only: verify it against the attached file.
Find the outer silhouette, ALL neck/cutout holes and these 14 garment landmarks:\n${ANCHORS.filter(a=>a.source).map(a=>`${a.id}. ${a.source}: ${a.label}`).join('\n')}
Definitions: shoulder corners are the outer torso/shoulder corners. Sleeve-start points are the TOP sleeve insertion/seam starts, separate from cuff centres. Armpits are the lower armhole/torso-sleeve junctions (left_armpit and right_armpit); do not confuse them with the shoulder or elbow. Cuffs are the centres of sleeve openings. Hem points are left corner, centre and right corner of the bottom edge. Collar corners are the two neck-opening endpoints at the shoulder/neck junction; front_collar_bottom is the deepest visible FRONT collar point. Do NOT include wrists: IDs 6 and 7 are body-only guides.
For a round neckline approximate the opening by a smooth quadratic/parabolic U through the two collar corners and its depth point, with at least 33 sampled boundary points; never replace it with a V or straight segments. Neckline shape is garment-dependent, not an anatomical law. If V/square/asymmetric, preserve the actual shape and set web_lab.neckline to polygon. Exclude visible back fabric/labels inside the opening. Do not remove printed white areas as holes.
All point arrays must contain finite numbers within image bounds. Shoulder/hem anchors must not be collinear. Outer and sleeve polygons must follow the image, with no crossings. Provide visible sleeve polygons only. Use cuff_edge_px with exactly two endpoints when reliably visible; otherwise left_sleeve_hem_center/right_sleeve_hem_center define cuff centres.
Do not hallucinate hidden points. If a requested point cannot be observed, set it to null, list its key in uncertain_points, and set review_required=true. Such an answer requires manual correction before import. Estimated but plausible points must be listed in web_lab.inferred_points. Do not claim measurements or exact confidence from a single photograph.
Output structure (replace ALL descriptive strings with actual arrays/numbers):\n${JSON.stringify(schema,null,2)}`;
}
