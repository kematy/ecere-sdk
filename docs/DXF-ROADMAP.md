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

### Phase 2 — DXF import (this branch)
- `DXFReader.ec` reads ASCII DXF into `CADDocument`
- Supported entities:
  - LINE, CIRCLE, ARC, ELLIPSE
  - LWPOLYLINE, POLYLINE/VERTEX/SEQEND
  - TEXT, MTEXT
  - INSERT
  - BLOCK / ENDBLK
- Demo: `samples/guiAndGfx/VectorDemo/` with `sample.dxf`

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

### Phase 3 — DXF export
- Write semantic entities back to ASCII DXF
- Preserve layers, colors, block definitions

### Phase 4 — Interaction
- Selection grips via `InteractionOverlay`
- Snap points and editing operations

### Phase 5 — Advanced entities
- HATCH fill parsing
- DIMENSION / LEADER annotation
- SPLINE from fit/control points
- Binary DXF and DWG conversion (external tool or library)

## Notes

- The reader targets **ASCII DXF** only.
- Block inserts are expanded at display time through `CADDocument`.
- For production CAD workflows, add regression tests with real-world DXF fixtures.
