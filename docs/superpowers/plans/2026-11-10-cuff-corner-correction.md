# Preserve user-selected cuff corners

User explicitly requested retaining current browser placements of 4/5 and 8/9 for the garment. Captured current exported browser metadata before any reload.

- 4/5 now mean upper cuff corners, 8/9 lower cuff corners; no sleeve insertion role.
- Exact source pixel positions preserved in sampleMetadata and downloadable sample JSON. Native cuff_edge_px pairs and arithmetic centre coordinates synchronized; source corner edits update both. Body fixture uses matching corner roles and sleeve mapping starts at the shoulder.
- Updated prompt, numbering, source controls and README. No main changes.

Verification: all existing geometry and anchor checks passed, plus cuff-corner regression confirms four exact original values, numbering, legacy migration and native midpoint arithmetic. Browser reload preserves selected positions; source and fitting views render. Independent read-only review found no important issues. Sample shape/texture unchanged.
