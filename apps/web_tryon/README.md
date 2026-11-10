# Bootic web try-on lab

A local, dependency-free diagnostic lab on branch `codex/web-tryon-lab`.

Run from the repository root:

```sh
python3 -m http.server 8080 --bind 127.0.0.1 --directory apps/web_tryon
```

Open http://127.0.0.1:8080. Uploads are processed locally in the browser, with no camera or remote inference calls.

## Two test views

1. **Garment source**: upload PNG/JPEG/WebP, up to 20 MB, 64–6000 px per dimension. Transparent inputs use their alpha. Opaque inputs use an experimental border-background flood fill and the largest connected garment. It requires a plain, contrasting background. It does not reliably handle worn garments, complex backgrounds, or infer internal neckline openings. The three initial garment anchors are estimates; drag to correct them.
2. **Static fitting**: the included generated adult photo has manually placed shoulder, elbow, wrist and hem anchors. Drag the numbered points to inspect placement sensitivity. This is a fixed test fixture, not the output of a body detector or certified silhouette ground truth. Live body detection remains a device test.

Use **ورود JSON** with metadata schema `bootic.garment-metadata/0.1` for the same original, untrimmed image. A `bootic.garment-model/1` wrapper with `source_metadata` is accepted. Hole polygons and sleeve regions are preserved. JSON export can be supplied to the Android metadata parser; it does not certify fitting quality. Failed imports do not overwrite the current valid garment.

The striped green fixture is a deterministic drawn test garment, not a photographic garment. Its mask/neckline/sleeve anchors are known by construction. The adult photograph was generated for this project; its anchors in `app.mjs` were manually inspected and remain adjustable.

## Renderer scope

The web renderer maps a 48×64 triangle grid using shoulder/hem anchors, bounded collar extrapolation, sleeve articulation, and a triangle-flip attenuation guard. Guides are interpolated through the final mesh. It shares the Android coordinate/data conventions but **does not execute Kotlin GarmentWarp/PhotoSurface** and omits native body-mask corrections, roll fields, face guard, temporal smoothing, and occlusion. Browser results validate source data and this experimental mapping, not full Android rendering parity.

No database, Flutter packages, npm packages, API keys or external CDN is needed. For repeatable comparisons, use the same uploaded image and JSON.

## Tests

With Node.js installed:

```sh
node --input-type=module -e "import('./apps/web_tryon/tests/geometry.test.mjs').then(m => console.log(m.runTests()))"
```

Tests cover background removal, alpha holes, contour coordinates, input validation, pinned anchors, finite grid vertices and topology safety. Browser QA covers source/fitting tabs and visual alignment. App live camera/FPS/Android output remains unverified by this lab.

## Expanded anchors and round collar

The shared numbering now includes 16 fixed-person markers and 14 garment markers:

- 1/2 shoulder corners; 3 hem centre; 4/5 upper cuff corners.
- 6/7 wrist guides appear only on the person.
- 8/9 lower cuff corners; 10/11 underarm junctions.
- 12/13 lower hem corners; 14/15 collar corners; 16 front collar depth.

Select a point from the dropdown when markers are close; drag it or enter X/Y and press **اعمال مختصات** (or Enter). Body points are manually annotated. Missing legacy garment points are explicitly marked as suggestions; the upload does not magically run a garment-landmark model. Existing cuff edges remain authoritative for their midpoint. The two underarm controls refer to the visible garment armhole junction and a chosen body attachment target, not measured hidden anatomy.

The optional parabolic round-neck cut is a 64-segment quadratic through both ends and the depth marker; it is recomputed in the actual mask and exported as an ordinary polygon usable by Android's metadata parser. The depth marker is the local collar-frame depth: tilted/asymmetric collar endpoints can shift the lowest image-space sample. This is an approximation for a round neckline, not a claim that every neckline/neck is a parabola. V/square necklines should retain their imported polygon. Switching to polygon preserves the currently sampled opening. A prior named/overlapping collar hole is replaced; unrelated holes remain.

Extra anchors drive a bounded local fitting field. When target positions would invert mesh triangles, fitting is attenuated. Yellow filled circles are requested destinations; cyan hollow circles and dashed residuals show where the rendered mesh actually maps each source anchor. The two may differ when constrained.

The **کپی پرامپت هوش مصنوعی** control supplies the complete data contract and all 14 garment-point names. The same reusable prompt is available at `assets/garment-landmarks-prompt.txt`. It asks the external AI to identify uncertainty instead of hallucinating hidden points. Responses flagged `review_required` or containing unknown coordinates require correction before import. This tool does not send the photograph to an AI service.

The sample now preserves the exact cuff-corner positions moved by the user in the browser: 4/5 are the upper corners, 8/9 the lower corners. They no longer represent sleeve insertion. Each pair is exported as `regions.sleeve_image_left/right.cuff_edge_px`; the arithmetic midpoint remains `left/right_sleeve_hem_center` for Android. Source corner edits update both the pair and midpoint. No measured coordinate is snapped to a generic default.
