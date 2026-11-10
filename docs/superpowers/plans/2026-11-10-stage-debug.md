# Stage Debug Implementation Plan

**Goal:** Switch among source garment, live body and final placement diagnostics with buttons.
**Architecture:** Reuse source geometry and final-mesh diagnostic painters; isolate diagnostic controls in a new widget. Keep native garment assets loaded while hiding their visual output in body mode.
**Spec:** docs/superpowers/specs/2026-11-10-stage-debug-design.md

- [x] Add widget tests for three-stage controls, missing source and stale output.
- [x] Add stage overlay and reuse source/final geometry painters; show garment identity, freshness, FPS and latency.
- [x] Integrate stage transitions with native visibility and voting suspension; restore normal appearance on exit and lifecycle restart.
- [x] Run Flutter suite, analysis and available native checks; review diff and push feature branch. Do not launch app (user instruction).

Ruling: Work in current checkout on codex/stage-debug; preserve unrelated files. Execute inline without further design approval per user's explicit instruction.

## Verification

- 10 related Flutter tests passed in /private/tmp/bootic-stage-check using copies of the production overlay, geometry and diagnostic files with cached Flutter dependencies. Static analysis of that subset: no issues.
- Full project suite attempted but dependency resolution failed: pub.dev returns HTTP 403; build_runner is not cached. Full app analysis and Android compilation remain unverified (no local Android SDK).
- git diff --check passed. Independent read-only review found no critical or important issues.
- App was not launched, per updated user instruction. Push feature branch only; no merge or release publication.
