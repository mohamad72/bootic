# Expanded web garment/body anchors

User authorized direct implementation without approval. Remain on codex/web-tryon-lab.

- [x] Add stable numbered anchor definitions: keep 1/2 shoulders, 3 hem centre, 4/5 cuffs, 6/7 wrist guides; add 8/9 sleeve starts, 10/11 underarms, 12/13 hem corners, 14/15 collar corners, 16 collar depth.
- [x] Add quadratic/parabolic round-neck mask through three collar points, resample to polygons for metadata compatibility. Do not claim all real necklines are mathematical parabolas.
- [x] Add draggable source/body controls, clear inferred/manual evidence, active-anchor selector to disambiguate close points. Make extra anchors affect local garment fitting, with topology fallback and separate target/projected indicators.
- [x] Supply copyable AI prompt with exact original-pixel coordinate and schema contract, all garment points and explicit unknown handling; body wrist guides are not garment landmarks.
- [x] Test collar geometry, legacy imports, underarms/anchor presence, render response, prompt/import round-trip; browser checks; review, commit and push web branch only.

Android answer: PoseLandmarker provides skeletal joints and foreground mask, not semantic collar/armpit garment landmarks. Distinguish desired virtual garment anchors from observable body features; occluded axilla cannot be measured exactly from a single RGB frame.

## Verification

- Existing 5 geometry tests pass. Expanded checks cover 16/14 marker contract, both underarms, curve ends/midpoint, dense hole, invalid depth, legacy imports, exact cuff edges, anonymous neckline replacement with unrelated holes retained, prompt key coverage, and local hem-fit response.
- Browser: source/body selector options, manual evidence labels, copy-prompt status, explicit XY apply, invalid collar rejection restoring coordinates, curve-depth edit and JSON export verified. Exported depth [300,175] exactly equals polygon midpoint index32, with 65 samples and both underarm landmarks present.
- Sample PNG/JSON and text-prompt downloads synchronized. Exported annotated preview retained locally for review. Local server still running.
- Independent review identified cuff-edge authority and duplicate-neck-hole defects; both fixed with regressions and follow-up review found no remaining important issues.
- Live Android anatomical/clothing inference not implemented in this change. Manual body target annotations and inferred source points are explicitly labeled. main remains unchanged.
