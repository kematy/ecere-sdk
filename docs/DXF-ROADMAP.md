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
- Demo: `samples/guiAndGfx/VectorDemo/` with `sample.dxf`

### Phase 3 — DXF export
- `DXFWriter.ec` writes ASCII DXF from `CADDocument`
- Preserves layers, colors, block definitions, and the same entity subset as the reader
- SPLINE and LEADER entities are exported as LWPOLYLINE approximations
- Round-trip example:

```sh
./obj/debug.linux/VectorDemo sample.dxf --export roundtrip.dxf
python3 scripts/validate-dxf-roundtrip.py sample.dxf roundtrip.dxf
```

### Phase 4 — Interaction (partial)
- `SelectionManager.ec` picks entities by display-line distance and builds grip overlays
- `VectorDemo` supports click-to-select with highlight and grip drawing
- `VectorRenderer` provides `ScreenToWorld`, `DrawSelectedEntity`, and `DrawInteractionOverlay`
- Snap points and editing operations remain planned

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
- Snap points and constraint editing
- Grip drag to modify entity geometry

### Phase 5 — Advanced entities
- HATCH fill parsing
- DIMENSION / LEADER annotation
- SPLINE from fit/control points
- Binary DXF and DWG conversion (external tool or library)

## Notes

- The reader targets **ASCII DXF** only.
- Block inserts are expanded at display time through `CADDocument`.
- For production CAD workflows, add regression tests with real-world DXF fixtures.
