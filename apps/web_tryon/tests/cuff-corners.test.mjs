import assert from 'node:assert/strict';
import {ANCHORS,enrichMetadata,buildPrompt} from '../anchors.mjs';
import {sampleMetadata,validateMetadata} from '../geometry.mjs';
export function runTests(){
 const m=sampleMetadata(),l=m.landmarks_px;
 assert.equal(ANCHORS.find(a=>a.id===4).source,'left_cuff_upper');
 assert.equal(ANCHORS.find(a=>a.id===8).source,'left_cuff_lower');
 assert.equal(l.left_cuff_upper[0],34.339099541802256);
 assert.equal(l.left_cuff_lower[1],316.5316422073179);
 assert.equal(l.right_cuff_upper[0],570.4603559333289);
 assert.equal(l.right_cuff_lower[1],319.69254266551565);
 const spec=validateMetadata(m);
 for(const side of ['left','right']){
   const edge=m.regions[`sleeve_image_${side}`].cuff_edge_px;
   assert.equal(edge[0][0],l[`${side}_cuff_upper`][0]);
   assert.equal(edge[1][1],l[`${side}_cuff_lower`][1]);
   const sleeve=spec.sleeves.find(s=>s.side===side);
   assert.equal(sleeve.hem[0],(edge[0][0]+edge[1][0])/2);
 }
 const old=structuredClone(m);delete old.landmarks_px.left_cuff_upper;delete old.landmarks_px.left_cuff_lower;
 const migrated=enrichMetadata(old);assert.equal(migrated.landmarks_px.left_cuff_upper[0],l.left_cuff_upper[0]);
 assert(!buildPrompt().includes('Sleeve-start points are'));
 return 'Cuff corner numbering, exact user positions and native midpoint checks passed';
}
