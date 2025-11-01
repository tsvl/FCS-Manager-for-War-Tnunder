# Refactor Roadmap

Goal: make the pipeline modular, testable, and portable while preserving current behavior and file formats, so we can eventually move beyond WinForms.

## Principles

- Keep the three-stage contract. The file formats in docs/formats.md are the stable interfaces between stages.
- Extract pure logic first (parsers, physics, rendering) from UI code. Favor dependency-free helpers.
- Add tests around critical math (Ballistic, HePenetration, DeMarre) using examples/ as fixtures.
- Maintain compatibility with existing examples to avoid regressions.

## Incremental steps

1) Extract Stage APIs
   - Stage1: IDatamineToData.Convert(inputRoot, vehicleId) → DataModel
   - Stage2: IDataToBallistic.Build(dataModel) → Dictionary<shell, Table>
   - Stage3: IBallisticToSight.Render(vehicle, tables, options, localization) → IEnumerable<OutputFile>

2) Define data models
   - VehicleData, ProjectileEntry, DeMarreParams, ArmorPowerSeries, Zoom/Laser flags
   - BallisticRow(distance_m, time_s, penetration_mm)

3) Move helpers out of Form1.cs
   - Ballistic(...), HePenetration(...), CanUseDoubleShell(...)
   - Normalize/parse utilities for blkx scanning (string readers, Cx averaging)

4) Write a CLI wrapper
   - dotnet console app: fcsgen convert, fcsgen ballistic, fcsgen sight
   - Input/output folders match current structure; options via flags or a yaml config

5) Unit tests
   - Golden tests comparing generated tables/files against examples/
   - Math-focused tests for edge cases: low speed shells, HE-only, APDS-FS arrays, large zoom/sensitivity values

6) Optional: language-agnostic pilot
   - Replicate Stage 2 (ballistics) in Python or Go using the documented formats; validate against dotnet results

7) UI modernization (later)
   - Replace WinForms with a thin UI over the CLI, or a cross-platform GUI

## Risks and mitigations

- Datamine parser brittleness: capture more fixtures under examples/Datamine and improve defensive parsing
- Physics drift: codify constants and equations; lock in via tests
- Sight geometry coupling: introduce small adapters translating shared options into family-specific Create(...) parameters
