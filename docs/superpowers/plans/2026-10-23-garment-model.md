# Parametric live garment implementation

User selected the proposed photo-to-description-to-prepared-3D-model workflow. Implement locally and deliver an incremental patch against fff759a; no remote writes.

1. Make catalog price/stock nullable in domain, editor, SQL schema and all displays. Migrate table transactionally without deleting rows; preserve explicit zero. Unknown stock is eligible; zero is unavailable. Unknown price has no live price badge.
2. Introduce a validated, versioned parametric model description, retaining the existing catalog envelope and legacy geometry imports. New prompt requests shape ratios, neckline, sleeves, colors/pattern/material and optional original-photo texture geometry. No inferred physical size, price or stock.
3. Prepare a reusable 3D triangle mesh and material once per garment. Deform torso and sleeves using normalized pose and depth; project and depth-sort shaded triangles into the existing Android overlay, used on phone and projector. Preserve camera alignment, body edge anchors, voting and effects. Hide invalid tracking. Basic foreground arm clipping only when pose depth says arm is in front.
4. Verify null roundtrip/clearing/zero semantics, both import formats, malformed model rejection, migration row preservation and mesh geometry at different poses/body scales. Compile changed native rendering against Android APIs if toolchain can be obtained without Flutter bootstrap. Report unavailable full Flutter/device verification honestly.

Limitations: approximate parametric drape, no exact physical sizing or cloth solver, hidden surfaces inferred, no guarantee of photorealism or exact print reconstruction from one photograph. Source texture remains necessary for complex prints; simple patterns need no photo pixels at runtime.
