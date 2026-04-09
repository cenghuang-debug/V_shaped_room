# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an OpenFOAM v2406 simulation project studying **hydrogen (H2) dispersion** in a V-shaped room. The physical scenario is an accidental H2 leakage from a **500 bar pressure vessel** through a small hole (area **≥ 3.5 mm²**, i.e. diameter ≥ ~2.1 mm). The flow is choked (Mach 1 at the orifice) and produces a strongly underexpanded supersonic jet.

The simulation uses `reactingFoam` with k-epsilon turbulence. Combustion and chemistry are disabled — this is a passive scalar dispersion study.

### Source (leak) boundary condition strategy
Because `reactingFoam` cannot resolve the near-field shock structure (Mach disk, barrel shock) of a 500 bar release, the **notional nozzle (pseudo-source) approach** is used. The actual orifice is replaced by an equivalent inlet at **ambient pressure** with a larger effective diameter and adjusted velocity, preserving mass and momentum flux. The recommended model is **Birch 1987** (mass + momentum conservation):

| Parameter | Physical orifice | Notional nozzle (Birch 1987, 500 bar, 3.5 mm²) |
|-----------|-----------------|--------------------------------------------------|
| Pressure  | 500 bar (choked) | 101325 Pa (ambient) |
| Diameter  | ~2.1 mm (3.5 mm²) | ~2.85 cm |
| Velocity  | ~1173 m/s (choked H2) | ~2008 m/s |
| Temperature | ~238 K (throat) | ~286 K (ambient) |
| H2 mass fraction | 1.0 | 1.0 |

The nozzle size in the mesh corresponds to the **notional nozzle diameter** (~2.85 cm), not the physical orifice.

There are multiple case variants in this directory:
- `case_up_half_cube_01/` — baseline case (already meshed, has logs)
- `case_up_half_cube_01_800_wave/` — 800 m/s jet with wave-transmissive outlet BCs
- `case_up_half_cube_01_GitHub/` — GitHub version (contains `case_up_half_cube_01/` subfolder)
- `case_up_half_cube_04/` — 1630 m/s jet; ran on Dardel (128 cores) but stopped early at t≈2.2×10⁻⁴ s due to T_min reaching 200 K (JANAF lower limit). Root cause: source patch (~1 cm) is physical-orifice scale, not notional nozzle scale; p was zeroGradient instead of fixedValue 101325. Fix: enlarge source patch to ~2.85 cm diameter and apply correct Birch 1987 BCs (V_n=2008 m/s, p=101325 Pa).

## Common Commands

All commands must be run with OpenFOAM sourced. On the HPC cluster:
```bash
module load SoftwareTree/Milan GCC/12.3.0 OpenMPI/4.1.5 OpenFOAM/v2406
```

### Mesh preparation (run from case directory)
```bash
./Allrun           # Full mesh pipeline: surfaceFeatureExtract → blockMesh → snappyHexMesh → topoSet → createPatch → checkMesh → renumberMesh → potentialFoam
./Allclean         # Remove mesh, logs, postProcessing output
```

### Running the solver (serial)
```bash
reactingFoam > log.reactingFoam 2>&1
```

### Running in parallel (HPC)
```bash
sbatch run.slurm   # Submit to SLURM (2 nodes, 64 MPI tasks, 90h walltime)
```

Manual parallel workflow:
```bash
decomposePar -force
mpirun -np 64 reactingFoam -parallel > log.reactingFoam 2>&1
reconstructPar -latestTime
```

### Post-processing
```bash
foamListTimes                    # List available time directories
postProcess -func probes         # Re-run probe sampling
paraFoam                         # Open in ParaView (or use open.foam file)
```

### Check mesh quality
```bash
checkMesh > log.checkMesh 2>&1
```

## Case Architecture

### Key configuration files
| File | Purpose |
|------|---------|
| `system/controlDict` | Time step (1e-8 s), end time (0.01 s), CFL limit (0.4), write interval, probes |
| `system/fvSchemes` | Euler time integration, upwind divergence, cell-limited gradients |
| `system/fvSolution` | PIMPLE (1 outer, 2 inner correctors), PCG for pressure, PBiCGStab for others |
| `system/blockMeshDict` | Background mesh: 12×16×10 m domain with refinement grading |
| `system/snappyHexMeshDict` | Refinement to STL geometry (walls, nozzle) |
| `system/topoSetDict` | Defines `sourceRegion` cellSet around nozzle |
| `system/createPatchDict` | Creates `source` patch from nozzle face set |
| `constant/thermophysicalProperties` | 4-species mixture: H2, O2, N2, H2O (JANAF + Sutherland, perfect gas) |
| `constant/chemistryProperties` | Chemistry disabled (`active false`) |
| `constant/combustionProperties` | Combustion model: none |
| `constant/turbulenceProperties` | RAS k-epsilon, Sct = 0.6 |
| `constant/g` | Gravity: (0 0 -9.81) |

### Boundary conditions summary
| Boundary | U | p | T | H2 |
|----------|---|---|---|-----|
| `source` (nozzle) | (0,0,800) m/s fixed | zeroGradient | 286.15 K | 1.0 (pure H2) |
| `left` | symmetryPlane | symmetryPlane | symmetryPlane | symmetryPlane |
| `walls` / `nozzleWall` | noSlip | zeroGradient | zeroGradient | zeroGradient |
| `right/top/bottom/front/back` | pressureInletOutletVelocity | waveTransmissive | zeroGradient | inletOutlet (0) |

### Mesh topology
- STL geometry: `constant/triSurface/walls.stl`, `constant/triSurface/nozzle_wall.stl`
- ~304k cells after snappyHexMesh (mix of hex, prism, polyhedra)
- Nozzle located at approximately (0, 0, 1 m)

### Probe monitoring
`system/controlDict` defines 4 probe sets sampling H2 mass fraction at:
- Vertical line near nozzle: (0.2, 0, z) at z = 0.05, 1.05, 2.0, 3.0, 4.0, 4.9 m
- Floor diagonal: (x, x, 0.05) for x = 0–4 m
- Mid-height diagonal: (x, x, 4.0) for x = 0–4 m
- Ceiling diagonal: (x, x, 4.9–6.9) for x = 0–4 m

Output goes to `postProcessing/probes/<time>/`.

## Project Status (as of 2026-04-09)

### Current state
- **Active case**: `case_up_half_cube_05/` — Birch 1987 notional nozzle BCs, 25.3×25.3 mm source patch, meshed and test-run locally (T_max stable at 371 K)
- **Pending**: submit `sbatch sbatch_OF_dardel_monitor` on Dardel
- **Analysis notebook**: `analysis_notes_V_room.ipynb` — complete theory, Birch 1987 derivation, numerical examples, and OpenFOAM BC recommendations

### Ready to run checklist
- [x] `0.orig/U`: source velocity = `(0 0 2008.25)` m/s
- [x] `0.orig/p`: source pressure = `fixedValue 101325` Pa
- [x] `0.orig/T`: source temperature = `fixedValue 286.15` K
- [x] `0.orig/k`: source TKE = `fixedValue 15124.06` m²/s²
- [x] `0.orig/epsilon`: source dissipation = `fixedValue 1.530e8` m²/s³
- [x] Geometry: `nozzle_wall.stl` enlarged to 40×40 mm; topoSetDict box selects 25.3×25.3 mm source
- [x] Remesh: `./Allrun` completed locally
- [ ] Submit: `sbatch sbatch_OF_dardel_monitor` on Dardel

---

## Important Findings

### 1. Notional nozzle parameters (Birch 1987, 500 bar, 3.5 mm² orifice)
Derived from mass + momentum conservation across the near-field shock region:

| Quantity | Value | Formula |
|----------|-------|---------|
| Throat temperature | 238.5 K | T* = 2T₀/(γ+1) |
| Throat pressure | 264 bar | P* = P₀(2/(γ+1))^(γ/(γ-1)) |
| Throat density | 26.86 kg/m³ | ρ* = P*/(R_H2 T*) |
| Throat velocity | 1173 m/s | V* = √(γ R_H2 T*) |
| Mass flow rate | 110.3 g/s | ṁ = ρ* V* A₀ |
| Notional velocity V_n | **2008 m/s** | V_n = V* + (P*−P_amb)/(ρ* V*) |
| Notional diameter D_n | **2.85 cm** (circular) | D_n = D₀√(ρ* V* / ρ_n V_n) |
| Notional side (square) | **25.3 mm** | side = √(π/4 × D_n²) |

### 2. Why case04 crashed at t ≈ 2.2×10⁻⁴ s
- Source patch was ~20×20 mm (physical orifice scale), not the notional nozzle scale
- Velocity was set to 1630 m/s (incorrect; Birch 1987 gives 2008 m/s)
- The strongly underexpanded jet (Mach ~3.5 in room air) created expansion fans that cooled H2 below 200 K (JANAF lower bound) → temperature monitor triggered `stopAt writeNow`

### 3. Why reactingFoam cannot simulate the physical orifice directly
- `reactingFoam` uses a pressure-based PIMPLE solver with no Riemann/shock-capturing scheme
- At 500 bar, the orifice exit is choked at Mach 1 in H2, but Mach ~3.4 in room air
- The Mach disk and barrel shock structure spans only ~5–20 mm from a 2.1 mm orifice — far below the mesh resolution needed for room-scale dispersion
- Attempting to resolve it leads to non-physical temperatures and divergence

### 4. V_n is still supersonic relative to room air
Even with the notional nozzle, V_n = 2008 m/s corresponds to Mach ~5.9 in room air (speed of sound ~339 m/s) and Mach ~1.56 in pure H2 (speed of sound ≈ 1285 m/s at 286 K) — **supersonic in both media**. The reason reactingFoam can handle this is not the Mach number but the pressure: the notional nozzle sets p = p_amb at the inlet, removing the pressure mismatch that drives the Mach disk and barrel shocks in the physical 500 bar case. Without that pressure gradient, the PIMPLE solver can handle the flow even at Mach 1.56. H2's high speed of sound (≈3.8× air) is why the Mach number in the jet fluid is far less extreme than in ambient air.

---

## Open Issues

1. **Geometry update required**: `constant/triSurface/nozzle_wall.stl` source patch must be enlarged from ~20×20 mm to ~25.3×25.3 mm. Edit `geometry/half_up_source.blend` in Blender and re-export the STL.

2. **snappyHexMeshDict refinement**: After enlarging the source patch, verify that the finest refinement box in `system/snappyHexMeshDict` is large enough to contain the new source geometry (~25 mm half-width vs current ~20–40 mm boxes — likely OK but should be checked).

3. **CFL stability with V_n = 2008 m/s**: The current `maxDeltaT = 1e-4` s and `maxCo = 0.4` may still allow large time steps initially. Monitor the first few write intervals closely.

4. **Temperature lower bound**: The JANAF tables in `constant/thermophysicalProperties` have a lower limit of 200 K. If H2 expands supersonically after the notional inlet, cooling below 200 K may still occur. Consider whether a larger source patch or reduced V_n (using Schefer 2007 model with energy conservation) would help.

5. **Turbulence intensity assumption**: I = 5% and l = 0.07 D_n are standard engineering estimates. The high k and ε values at the source (15124 m²/s², 1.53×10⁸ m²/s³) may cause numerical stiffness — watch for divergence in k/ε in early time steps.

---

## Enabling Chemistry/Combustion

To activate reacting flow, edit these files:
- `constant/chemistryProperties`: set `active true`
- `constant/combustionProperties`: change model from `none` to e.g. `EDC` or `PaSR`
- Reduce time step or tighten CFL limit (chemistry is stiff)

## HPC Notes

The `run.slurm` script is configured for the **Dardel** cluster (KTH/NAISS) with account `naiss2026-3-176`, 1 node × 128 cores. Update the `CASE` path variable before submitting. The script purges all time directories (`foamListTimes -rm`) and processor directories before each run. A temperature monitor watches T_min ≤ 200 K and T_max ≥ 5000 K and triggers `stopAt writeNow` if limits are exceeded.
