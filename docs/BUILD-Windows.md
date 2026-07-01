# Building the Ecere SDK on Windows

This guide describes how to build the Ecere SDK from source on Windows using
MinGW-w64. For the authoritative and most up-to-date instructions, also see
http://ecere.org/install.

## Prerequisites

- **MinGW-w64** (64-bit GCC toolchain). You can obtain it via
  [MSYS2](https://www.msys2.org/) or a standalone MinGW-w64 distribution.
- **GNU Make** (`mingw32-make` is provided by MinGW-w64).
- **Git** (optional, for cloning the repository).

Make sure the MinGW-w64 `bin` directory is on your `PATH` so that `gcc` and
`mingw32-make` are available from the command prompt.

### Optional dependencies

- **OpenSSL** - only needed if you build with SSL support (`ENABLE_SSL=y`).
- Graphics/audio system libraries are provided by Windows (Direct3D,
  DirectSound, OpenGL).

## Getting the source

```bat
cd C:\projects
git clone https://github.com/kematy/ecere-sdk.git ecere-sdk
cd ecere-sdk
```

If cloning fails with `Connection was reset`, try again on a more stable
network, use a shallow clone (`git clone --depth 1 ...`), or download the
repository as a ZIP from GitHub and extract it.

## Building

From the repository root, build the full SDK with:

```bat
mingw32-make
```

To build with SSL support enabled:

```bat
mingw32-make ENABLE_SSL=y
```

Useful diagnostics before a build:

```bat
mingw32-make troubleshoot
mingw32-make print-all-vars-stat
```

The build is largely sequential (a self-hosting, two-stage bootstrap of the eC
compiler), so a full first build can take a while. Build outputs are placed
under `obj/<platform>/bin` and `obj/<platform>/lib`.

## Installing

```bat
mingw32-make install
```

## Building a single sample

Once the SDK is built/installed and the tools (`ecp`, `ecc`, `ecs`) are on your
`PATH`, you can build an individual sample project:

```bat
cd samples\eC\Sandbox
ecp Sandbox.epj
Sandbox.exe
```

Alternatively, open the `.epj` file in the Ecere IDE and use the build/run
actions.

## Troubleshooting

- **`fatal: not a git repository`** - you are in a directory that was not
  cloned with Git. Clone the repository fresh, or download the ZIP.
- **`mingw32-make` not found** - ensure the MinGW-w64 `bin` directory is on your
  `PATH`.
- **Missing system DLLs (opengl32, glu32, ddraw, dsound)** - these are normally
  present on Windows; if a sample fails to start due to a missing DLL, confirm
  your graphics/audio drivers are installed.
- **Build errors after a partial build** - try a clean build. If the bootstrap
  compiler gets out of sync, consult the `regenbootstrap` target and the
  `compiler/bootstrap/` directory.
