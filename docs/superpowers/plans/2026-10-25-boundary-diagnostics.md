# Body boundaries and garment roll diagnostics

**Goal:** Repair neck placement and artificial texture kinks; show body attachment boundaries and the actual garment roll bands in a separate camera diagnostic mode.

**Architecture:** Keep the existing photo renderer and shared phone/projector mesh. Compute bounded, continuous fitting fields from fixed source coordinates. Compute diagnostic body lines independently of garment selection, and project garment guides through the final mesh, including its topology fallback.

**Scope:** The person mask has no semantic neck/arm/waist labels. Anatomical attachment lines are pose estimates and must be dashed and explicitly labelled. Only silhouette samples are mask observations. No new cloth wrinkles, shadows, services or dependencies.

**Implementation plan (native execution):**

- [x] Reproduce collar extrapolation and texture-kink regressions in Kotlin tests; verify failures.
- [x] Bound upper-photo extrapolation, keep the neck below the face, replace per-vertex boundary corrections with smooth row fields, and apply sleeve articulation weight only once.
- [x] Replace interior bulging with very small side/shoulder roll bands; pin anchors, neckline and lower hem. Verify no foldovers, arm locality and front-camera reflection.
- [x] Add body attachment diagnostics (both armholes, neck base, hip plane), observed torso side samples and source roll guides. Verify loss/occlusion and mirror behaviour. Project guides through the rendered mesh.
- [x] Add a separate boundary mode next to the existing debug button; display a colour legend, explicit estimate status and fresh-frame gating. Retain garment transparency control.
- [x] Run all Kotlin and Flutter tests, static analysis and native API compilation. Record device-only limits; do not claim camera appearance is verified by synthetic tests.

**Verification:** 66 Kotlin tests and 33 Flutter tests passed. Flutter analysis exits 0 with no errors/warnings and 39 existing info-level issues. Geometry, render asset, mesh view and pose tracker compiled against Android 35 / MediaPipe 1.0.0 API jars. Full APK build and real-camera visual/FPS acceptance are not verified; the configured NDK 28.2.13676358 is absent (local installation is 26.3.11579264). Independent read-only review found one mouth-guard/fallback interaction; an accepted-pose final-mesh regression reproduced it, and the guard was moved into a monotonic safe reference. The final regression passes for both texture reflection settings.

**Review focus:** Ambiguous merged arms must not resize torso; no collar can extrapolate into the face; lower hem must not roll; stale/rejected pose must not draw diagnostic lines; guides must use the final mesh and the same FILL_CENTER coordinates as the camera.
