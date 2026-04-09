# CLAUDE.md

## Project Overview

OpenFOAM v2406 — H2 dispersion in a V-shaped room. Source: 500 bar vessel, choked orifice (≥3.5 mm²). Solver: `reactingFoam`, k-epsilon RANS, chemistry/combustion disabled.

**Notional nozzle (Birch 1987):** replaces 500 bar orifice with ambient-pressure inlet preserving mass + momentum. Key values: V_n = 2008.25 m/s, p = 101325 Pa, T = 286.15 K, D_n = 25.3 mm square, k = 15124.06 m²/s², ε = 1.53×10⁸ m²/s³. Full derivation in `analysis_notes_V_room.ipynb`.

**Active case:** `case_up_half_cube_05/` — Birch 1987 BCs in `0.orig/`, 25.3×25.3 mm source patch, meshed locally. Earlier cases (01, 04) archived. **Next: submit to Dardel.**

## Common Commands

```bash
# Mesh (run from case dir)
./Allrun        # surfaceFeatureExtract → blockMesh → snappyHexMesh → topoSet → createPatch → checkMesh → renumberMesh → potentialFoam
./Allclean      # remove mesh/logs/postProcessing

# Solver
reactingFoam > log.reactingFoam 2>&1          # serial
sbatch sbatch_OF_dardel_monitor                # Dardel (1 node × 128 cores, naiss2026-3-176)

# Post-processing
checkMesh > log.checkMesh 2>&1
foamListTimes
paraFoam
```

## Case Architecture

| File | Purpose |
|------|---------|
| `system/controlDict` | dt=1e-8 s, endTime=0.01 s, maxCo=0.4, probes |
| `system/blockMeshDict` | 12×16×10 m domain |
| `system/snappyHexMeshDict` | Refinement to walls.stl / nozzle_wall.stl |
| `system/topoSetDict` | sourceRegion cellSet (box ±12.7 mm in y, ±15 mm in x) |
| `constant/thermophysicalProperties` | H2, O2, N2, H2O — JANAF (200–5000 K), Sutherland |
| `constant/turbulenceProperties` | RAS k-epsilon, Sct=0.6 |

**Mesh:** ~304k cells, nozzle at (0, 0, 1 m), ~3.9 mm cells near source (level 8).

## Key Notes

- **Why case04 crashed:** source patch was 20×20 mm (physical orifice scale), V=1630 m/s — jet expanded to T<200 K (JANAF limit). Fix in case05: 25.3 mm patch + correct Birch 1987 BCs.
- **JANAF lower limit:** 200 K. Temperature monitor in sbatch script triggers `stopAt writeNow` if T_min ≤ 200 K or T_max ≥ 5000 K.
- **Dardel sbatch:** script is `sbatch_OF_dardel_monitor` inside each case dir. Update `CASE` path before submitting.
- **Mesh sensitivity (future case06):** increase snappyHexMesh level 8→9 near nozzle, tighten topoSetDict box to ±12.7 mm, verify source area ≈ 640 mm².
