# AGENTS.md

## Cursor Cloud specific instructions

The Ecere SDK is a self-bootstrapping C/eC SDK (compiler toolchain `ecp`/`ecc`/`ecs`,
runtime library `ecere`/`ecereCOM`, `ecere-ide`, `eda`, `ear`, `bgen`, `documentor`,
`epj2make`). It has no long-running services; "running it" means building the toolchain
and using it to compile/run eC programs. Everything is driven by the top-level `Makefile`.

### Build / run / test
- Build everything: `make -j$(nproc) DISABLE_SSL=y` from the repo root. See `README.md` / `INSTALL`.
- Outputs go to `obj/linux/bin/` (binaries) and `obj/linux/lib/` (shared libs). Both are gitignored.
- There is no `make test` and no unit-test framework. "Tests" are eC sample/project (`.epj`)
  builds under `samples/`, `tests/`, `butterbur/tests/`, `autoLayout/tests/`. Build them with the
  freshly built toolchain to validate the compiler/runtime.
- There is no separate linter; diagnostics come from the eC compiler during build.
  `make troubleshoot` and `make print-all-vars-stat` dump build/env diagnostics.

### Non-obvious gotchas
- SSL must be disabled on this environment: `DISABLE_SSL=y`. SSL is ON by default, and the eC
  compiler cannot parse the system OpenSSL 3.x headers (`core_dispatch.h`) on Ubuntu 24.04
  (the Makefile expects OpenSSL 1.1 at `/usr/include/openssl-1.1`, which is not present).
  Building without `DISABLE_SSL=y` fails at `ecere/src/net/SSLSocket.ec`. SSL sockets are the
  only feature lost; the rest of the SDK builds fully.
- To compile an eC project you need the built tools on PATH and the runtime libs discoverable:
  ```
  export PATH="/workspace/obj/linux/bin:$PATH"
  export LD_LIBRARY_PATH="/workspace/obj/linux/lib"   # runtime
  export LIBRARY_PATH="/workspace/obj/linux/lib"       # link time (fixes -lecereCOM not found)
  ```
  Then: `epj2make -o Foo.Makefile Foo.epj && make -f Foo.Makefile`, and run `obj/debug.linux/Foo`
  (set `LD_LIBRARY_PATH` when running). `LIBRARY_PATH` is required because generated project
  Makefiles do not add the SDK lib dir, so linking fails with `cannot find -lecereCOM` without it.
- `epj2make` argument order matters: options/`-o <output>` must come before the input `.epj`.
- eC value structs (e.g. `Point`, `VectorPoint`) are declared `Point p;` / `Point p = { x, y };`;
  the `Type name { }` instantiation syntax is only for (ref) classes. A `public` class whose public
  method signatures use classes from another module must `public import` that module.
- If a project's own `.ec`/`.c` files call libm directly (`sqrt`, `cos`, ...), add `"m"` to the
  project `Libraries` or linking fails with `undefined reference to 'sqrt'` even though ecere links libm.
- Vector/CAD module: `ecere/src/gfx/vector/` (semantic entities -> display lines -> CAD document).
  Runnable GUI example: `samples/guiAndGfx/VectorDemo/` (build via the `epj2make` + `make -f` flow above; needs an X display to run).
- GUI apps (`ecere-ide` and `guiAndGfx`/`3D` samples) need an X11 display (X11 + OpenGL/Mesa).
  They will not run in a headless shell; use a desktop/X display.
