# Vector / CAD / DXF Demo

GUI sample for the Ecere vector module, ASCII DXF import/export, and entity selection.

## Files

- `VectorDemo.ec` - main window; loads `sample.dxf` by default or a path from the command line
- `VectorRenderer.ec` - draws `CADDocument` display lines on a `Surface`; selection highlight and grips
- `sample.dxf` - minimal ASCII DXF fixture (line, circle, arc, ellipse, polyline, text)
- `../../../ecere/src/gfx/vector/` - vector/CAD module sources (compiled into this project)

## Build

After building/installing the Ecere SDK:

```sh
cd samples/guiAndGfx/VectorDemo
epj2make -o VectorDemo.Makefile VectorDemo.epj
make -f VectorDemo.Makefile
```

## Run

```sh
./obj/debug.linux/VectorDemo
./obj/debug.linux/VectorDemo sample.dxf
./obj/debug.linux/VectorDemo sample.dxf --export roundtrip.dxf
./obj/debug.linux/VectorDemo --export exported.dxf
```

Click an entity in the window to select it. Selected geometry is highlighted in orange and grip points are drawn in red.

Validate a round-trip export against the original DXF numeric values:

```sh
python3 ../../../scripts/validate-dxf-roundtrip.py sample.dxf roundtrip.dxf
```

On Windows, open `VectorDemo.epj` in the Ecere IDE or run `VectorDemo.exe` from the build output directory.

See also `docs/DXF-ROADMAP.md` for supported DXF entities and planned phases.
