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
