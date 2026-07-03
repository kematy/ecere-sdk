# Vector / CAD / DXF Roadmap

The Ecere SDK vector module lives under `ecere/src/gfx/vector/` and follows a
three-layer design:

```text
DXF / API input
    -> SemanticEntity model (lines, arcs, polylines, inserts, ...)
    -> DisplayLine tessellation (CADDocument)
    -> Surface rendering (VectorRenderer)
```

## Current status

### Phase 0 — Semantic model
- `SemanticEntity`, `CADDocument`, `DisplayLine`, geometry helpers
- Entity types aligned with common DXF objects

### Phase 1 — Display pipeline
- `CADDocument.RebuildSemanticDisplayLines()`
- Bulge polylines, spline preview, block inserts, hatch boundaries
- `VectorRenderer` fits and draws on an Ecere `Surface`

### Phase 2 — DXF import
- `DXFReader.ec` reads ASCII DXF into `CADDocument`
- Supported entities:
  - LINE, CIRCLE, ARC, ELLIPSE
  - LWPOLYLINE, POLYLINE/VERTEX/SEQEND
  - TEXT, MTEXT
  - INSERT
  - BLOCK / ENDBLK
  - HATCH (solid fill, polyline boundary)
- Demo: `samples/guiAndGfx/VectorDemo/` with `sample.dxf`

### Phase 3 — DXF export
- `DXFWriter.ec` writes ASCII DXF from `CADDocument`
- Preserves layers, colors, block definitions, and the same entity subset as the reader
- SPLINE and LEADER entities are exported as LWPOLYLINE approximations
- HATCH entities export seed point, pattern name, solid flag, and boundary vertices
- Round-trip example:

```sh
tools/dxf-roundtrip/obj/debug.linux/DXFRoundTrip sample.dxf roundtrip.dxf
python3 scripts/validate-dxf-roundtrip.py sample.dxf roundtrip.dxf --fail-above 1e-9
```

Or via VectorDemo GUI export:

```sh
./obj/debug.linux/VectorDemo sample.dxf --export roundtrip.dxf
python3 scripts/validate-dxf-roundtrip.py sample.dxf roundtrip.dxf
```

### Phase 4 — Interaction
- `SelectionManager.ec` picks entities by display-line distance and builds grip overlays
- `VectorDemo` supports click-to-select with highlight and grip drawing
- Grip drag editing: pick a grip, drag to modify entity geometry (LINE, CIRCLE, ARC, ELLIPSE, POLYLINE, SPLINE, TEXT, INSERT, LEADER, HATCH)
- Snap points on hover: endpoint, midpoint, and center (green diamond); grip drag snaps when near a snap point
- `VectorRenderer` provides `ScreenToWorld`, `DrawSelectedEntity`, `DrawInteractionOverlay`, and `DrawSnapPoint`
- Constraint editing remains planned

### Phase 5 — Advanced entities (partial)
- HATCH fill import/export (solid and named patterns such as ANSI31 with angle/scale)
- HATCH pattern lines clipped to boundary polygon (segment–edge intersection)
- DIMENSION linear, aligned, angular, radial, diameter, and ordinate import/export
- LEADER DXF annotation (exported as polyline)
- SPLINE from fit/control points
- Binary DXF and DWG conversion (external tool or library)

### CI
- `validate-dxf` job: fixture entity coverage + round-trip numeric self-check
- `build-vectordemo` job: full SDK build (`DISABLE_SSL=y`, `ECERE_AUDIO=n`) + VectorDemo compile
- `build-vectordemo` job: headless `DXFRoundTrip` load/export + numeric round-trip tolerance check

### Precision handling
- Coordinates are stored as `double` throughout the semantic model
- DXF import uses `strtod` via `ParseDXFDouble()` (not `atof`)
- DXF export uses `FormatDXFDouble()` with 15 significant digits (not `printf %f`)
- Shared tolerances live in `Geometry.ec`:
  - `VECTOR_COORD_EPSILON` for coordinate zero-snapping
  - `VECTOR_BULGE_EPSILON` for bulge segment detection
  - `VECTOR_GEOM_EPSILON` for chord/width comparisons
- Arc bounds and rendering use adaptive tessellation via `VectorArcSampleCount()`
- DXF header writes `$LUPREC` / `$AUPREC` = 15 for CAD tool compatibility

Run the demo (after building the SDK):

```sh
cd samples/guiAndGfx/VectorDemo
epj2make -o VectorDemo.Makefile VectorDemo.epj
make -f VectorDemo.Makefile
./obj/debug.linux/VectorDemo sample.dxf
```

On Windows, open `VectorDemo.epj` in the Ecere IDE or use the equivalent
`epj2make` + `mingw32-make` flow from an SDK command prompt.

## Next phases

### Phase 4 — Interaction (remaining)
- Constraint editing

### Phase 5 — Advanced entities (remaining)
- DIMENSION leaders and full annotation styles
- SPLINE fit points from DXF
- Binary DXF and DWG conversion (external tool or library)

## Notes

- The reader targets **ASCII DXF** only.
- Block inserts are expanded at display time through `CADDocument`.
- For production CAD workflows, add regression tests with real-world DXF fixtures.
