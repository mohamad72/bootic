# Garment edge and volume implementation plan

> Execute inline with superpowers:executing-plans. The user approved the design in the preceding chat and requested implementation.

**Goal:** Correct sleeve deformation, fit trustworthy person boundaries, and add subtle photo surface curvature without cloth simulation.
**Architecture:** Preserve the photo mesh and existing JSON. Cache source polygon cross sections and sleeve membership. Extract bounded torso/arm cross sections from the existing person mask; filter corrections over time. Apply local fit followed by boundary-preserving transverse curvature.
**Tech stack:** Kotlin/Android Canvas, Flutter/Dart, existing MediaPipe mask.
**Spec:** The six-point design approved in this chat; captured below.

## Constraints and decisions
- Remove hem inertia and synthetic underarm pulling; preserve arm articulation and foreground occlusion.
- Sleeve deformation must not affect unrelated torso points or the opposite sleeve.
- Bound mask corrections, reject ambiguous/occluded boundaries, and fall back to base geometry when evidence is unavailable.
- No new inference model, dependency, generative texture, database migration, or mandatory JSON regeneration.
- Preserve collar, seams, silhouette and hem during volume mapping; zero strength equals fitted flat surface.
- Person segmentation cannot identify internal cuff/skin boundaries or reconstruct the hidden body. Fit visible external boundaries conservatively.
- Lighting: document consistent diffuse illumination, white balance and exposure; defer automatic relighting without calibration.
- Work in the clean existing checkout on codex/garment-edge-volume. No automatic commits/push or deployment.

## Tasks
- [ ] 1. Add regression tests for sleeve locality, pinned seams, no torso response to arm motion and topology; observe failures. Remove ClothMotion/underarm pull and bound sleeve influence with cached source regions.
- [ ] 2. Add tests for valid/ambiguous torso and arm cross sections, scale/reflection, temporal jump/reset/fallback; observe failures. Extend BodyEdges/BodyEdgeFit, integrate time filtering in PoseTracker, and apply bounded lateral mesh fit.
- [ ] 3. Add tests for zero strength, pinned boundaries/collar/hem, subtle transverse curvature, mirrored and raised arms; observe failures. Add cached, monotonic local curvature on the existing mesh.
- [ ] 4. Add source polygon preview in the editor and fitted boundary debug markers. Update prompt guidance and photo/device acceptance documentation. Run Kotlin geometry tests, Dart/Flutter checks and attempt Android build/compile using installed tools. Review the complete diff.

## Review focus
- Missing/invalid masks and rapid tracking changes must reset corrections without stale boundaries.
- Arms touching torso must not be mistaken for torso width.
- Mirroring and rotated/cropped viewport transforms must remain shared.
- No foldover at sleeve seams or elbow transitions for supported frontal/mild-turn poses.
- Existing JSON without optional information must remain usable; source contour preview must use untrimmed coordinates.

## Progress
- Planning: repository clean at 74c8603; implementation branch created. Existing SDK and compiler caches located.
- Tasks 1–4 implemented. 55/55 Kotlin geometry tests and 31/31 Flutter tests pass; AI import 49 checks, model/null 41 checks and render-metadata checks pass.
- Regression: diagonal sleeve seams initially moved torso/hem; local polygon influence fixes this. Independent review found thick touching arms/forearms could become torso boundaries; intersection/proximity regression failed before correction and now passes.
- Flutter analysis exits 0 with --no-fatal-infos: existing informational lints remain, no errors or warnings.
- Renderer, asset loader, tracker and geometry compile against Android API 35 and actual MediaPipe 1.0.0 API artifacts. Full Gradle compilation first hit a broken global init script; using the project Gradle home passed that stage but stopped because NDK 28.2.13676358 is not installed. No APK produced.
- Ruling: invertible-mesh safety reduces global deformation toward the affine pose for extreme gestures; expose deformationScale because arm tracking may become less complete.
- Ruling: prepared source mesh and per-observation projections are shared by bounds, phone and projector; actual device FPS remains unmeasured.
- Camera appearance, temporal quality and phone/projector profiling still require real-device acceptance documented in docs/photo-surface-v2.md.
