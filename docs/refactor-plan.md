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

---

## New trajectory: external tools first (Rust), WinForms as a thin shell

We’ll replace the app stage-by-stage with external command-line tools. Initially, WinForms becomes a “puppet” that shells out to these tools. This lets us iterate safely, keep current UX, and delete spaghetti incrementally.

### Milestone A — Stage 1 rewrite (Datamine → Data)

- Deliverable: a standalone CLI that reads datamine and produces both the robust JSON intermediate and the legacy Data/*.txt files.
- Language: Rust (fast, great ecosystem for WT tooling; easy to parallelize).
- WinForms change: Button1_Click calls the CLI with configured paths; nothing else.

#### CLI spec (first cut)

- Command: fcs convert-datamine (details: see docs/cli-stage1.md)
- Inputs:
   - --datamine-root <dir> (required): path containing aces.vromfs.bin_u/gamedata/...
   - --vehicle <id> | --vehicles <glob>: vehicle id(s) or glob(s) under units/tankmodels/*.blkx
   - --lang-csv <file>: units.csv for resolving <LangName2> (optional; if absent, use basename)
   - --out-data <dir>: output directory for legacy Data/*.txt (default: Data/)
   - --out-json <dir>: output directory for JSON intermediates (optional)
   - --emit `legacy|json|both` (default: both)
   - --threads <n> (default: num_cpus)
   - --log-level `info|debug|trace` (default: info)
- Exit codes: 0 success; non-zero per failure category (parse, IO, schema).
- Logging: structured (json lines) with a human pretty mode.

#### Behavior

- Robust extraction rules: as documented in docs/datamine-to-data.md (JSONPaths, selection heuristics, APDS/APFSDS series).
- Emit JSON intermediate with full fidelity; emit legacy .txt for current pipeline compatibility.
- Deterministic output ordering for diffability.

#### Rust project layout

- Workspace tools/fcs/
   - crates/core/ (library):
      - vehicle.rs (load vehicle JSON, zooms/laser, weapon refs)
      - module.rs (load module JSON, projectile parsing)
      - select.rs (weapon/rocket selection heuristics)
      - emit_legacy.rs (Data/*.txt writer)
      - emit_json.rs (intermediate JSON writer)
      - types.rs (Vehicle, Projectile, DeMarre, ArmorSeries, Zooms, Flags)
      - errors.rs
   - crates/cli/ (binary): argument parsing (clap), logging, parallel orchestration (rayon)

#### Test & validation

- Golden diffs vs examples/Data/*.txt for a representative vehicle set per nation and weapon family.
- Strict mode: require exact match; lenient mode: allow cosmetic whitespace differences.
- Edge suites: bulletName arrays; APFSDS series; dummy gunner0; multi-rocket vehicles; alternate cockpits.

### Milestone B — Integrate datamine extraction

- Goal: remove the need to manually push data files; the tool fetches and extracts datamine as needed.
- Options:
   - Shell out to existing WT datamine extractor (preferred for speed of integration), or
   - Link a Rust crate if licensing permits.
- Versioning & caching:
   - Cache key: hash of important inputs (vehicle .blkx content; module .blkx content; units.csv key rows).
   - Local manifest per output dir (e.g., .fcs-cache.json) with datamine version, file mtimes/sizes and content hashes.
   - Only reprocess changed dependencies; optional --force.
   - Nice-to-have: detect upstream datamine version (from a known manifest or tag) and include it in the output header.

### Milestone C — Stage 2 rewrite (Ballistic)

- Deliverable: CLI fcs make-ballistic that consumes the JSON/legacy Data and emits Ballistic/<vehicle>/*.txt.
- Goals: correctness parity, speed (parallel by projectile), and deterministic output.
- Hook into HePenetration, DeMarre, APHE penalties, APDS/APFSDS rules; make constants configurable via a TOML.
- WinForms change: Button2 calls the CLI.

### Milestone D — Stage 3 later (Sights)

- We’ll postpone rewriting sight generation. Once Stage 1/2 are done, we can thin the current WinForms layer to read our outputs and keep sight families working.
- Eventually: port to a structured renderer with templates per family; keep localization loading explicit.

### Validation corpus (TBD)

- We’ll curate a representative set (1–2 per nation) covering:
   - Primary gun + APHE
   - APDS/APFSDS with ArmorPower series
   - ATGM carrier with two rockets
   - Vehicle with secondary optics
   - SPAA / autocannon with Cx arrays
- This corpus will drive the golden diff CI for Stage 1 and Stage 2.

## Acceptance criteria per milestone

- A: convert-datamine
   - Produces JSON and legacy .txt identical to current examples for the sample set.
   - Handles documented edge cases without special-case code paths.
   - Completes the sample set in under 5 seconds on a typical desktop.

- B: integrated datamine extraction
   - Rebuilds only vehicles whose dependencies changed.
   - Provides a --status to show which vehicles are stale and why.

- C: make-ballistic
   - Matches existing ballistic files for the sample set within 1% numeric tolerance (or exactly where integers are expected).
   - End-to-end Stage 1+2 runtime for the sample set under 10 seconds.

## WinForms integration details (near-term)

- Add a config panel or appsettings JSON for:
   - Tool path (fcs.exe), datamine root, output roots, thread count.
   - Logging verbosity.
- Button1:
   - Validate inputs; run fcs convert-datamine with args.
   - Stream logs to the UI; show a summary and clickable diff link on mismatches (optional).
   - Exit-code based success/failure handling.

## Future: full replacement of WinForms

- Once Stage 1 and 2 are external and robust, we can:
   - Add a minimal modern GUI (Rust + Tauri, or .NET MAUI) that orchestrates the CLIs.
   - Keep a headless CI path (CLI only) for reproducible builds.

## Releases & packaging (lightweight)

- Release when a milestone or self-contained feature lands; no fixed cadence needed.
- Artifacts (Windows primary):
   - `fcs-stage1-vX.Y.Z-win-x64.zip` — contains `fcs.exe`, LICENSE, README, CLI help
   - `FCS-WinForms-vX.Y.Z-win-x64.zip` — WinForms app (may shell to `fcs.exe`)
   - Checksums: `.sha256` per artifact
- Optional Linux builds for `fcs` may be published when convenient.
